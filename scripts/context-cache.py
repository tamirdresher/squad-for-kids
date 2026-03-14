#!/usr/bin/env python3
"""Context cache with hash-based change detection and git diff integration.

Phase 1 of lazy incremental context updates for long-running agents.
Tracks file contents via SHA-256 hashes and mtime, integrates with git diff
to detect changes efficiently, and persists cache state as JSON.

Usage:
    python scripts/context-cache.py --scan .          # Scan files, build cache
    python scripts/context-cache.py --changes         # Show changed files since last scan
    python scripts/context-cache.py --diff            # Show diffs of changed files
    python scripts/context-cache.py --stats           # Cache statistics
    python scripts/context-cache.py --scan . --changes  # Scan then show changes
"""

from __future__ import annotations

import argparse
import hashlib
import json
import logging
import os
import subprocess
import sys
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

DEFAULT_CACHE_PATH = os.path.join(".squad", ".context-cache.json")
TOKEN_MULTIPLIER = 1.3  # words → approximate token count
MAX_FILE_SIZE = 2 * 1024 * 1024  # 2 MB – skip files larger than this
BINARY_EXTENSIONS = frozenset({
    ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".ico", ".svg",
    ".mp3", ".wav", ".mp4", ".avi", ".mov",
    ".zip", ".tar", ".gz", ".bz2", ".7z", ".rar",
    ".exe", ".dll", ".so", ".dylib", ".bin",
    ".pdf", ".doc", ".docx", ".xls", ".xlsx",
    ".pyc", ".pyo", ".class", ".o", ".obj",
    ".woff", ".woff2", ".ttf", ".eot",
})
IGNORE_DIRS = frozenset({
    ".git", "node_modules", "__pycache__", ".venv", "venv",
    "bin", "obj", ".next", "dist", "build", ".squad",
    "fish-speech-repo",
})


# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

@dataclass
class FileEntry:
    """Cached metadata for a single file."""
    path: str
    content_hash: str
    mtime: float
    size: int
    token_count: int

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> FileEntry:
        return cls(**data)


@dataclass
class CacheStats:
    """Aggregate statistics for reporting."""
    total_files: int = 0
    total_tokens: int = 0
    total_size: int = 0
    hits: int = 0
    misses: int = 0
    errors: int = 0


# ---------------------------------------------------------------------------
# Core implementation
# ---------------------------------------------------------------------------

class ContextCache:
    """Hash-based file cache with git integration.

    Tracks files by SHA-256 content hash and mtime.  Uses git diff to
    efficiently detect changes between scans.
    """

    def __init__(self, cache_path: str = DEFAULT_CACHE_PATH, repo_root: Optional[str] = None):
        self.cache_path = cache_path
        self.repo_root = repo_root or self._find_repo_root()
        self._entries: dict[str, FileEntry] = {}
        self._stats = CacheStats()
        self._load_cache()

    # -- public API ---------------------------------------------------------

    def load_or_update(self, path: str) -> Optional[FileEntry]:
        """Check hash/mtime for *path*; return cached entry or re-read.

        Returns ``None`` if the file should be skipped (binary, too large,
        unreadable).
        """
        abs_path = os.path.abspath(path)
        rel_path = os.path.relpath(abs_path, self.repo_root)
        # Normalise to forward slashes for cross-platform consistency
        rel_path = rel_path.replace("\\", "/")

        try:
            stat = os.stat(abs_path)
        except OSError as exc:
            logger.debug("Cannot stat %s: %s", path, exc)
            self._stats.errors += 1
            return None

        if stat.st_size > MAX_FILE_SIZE:
            logger.debug("Skipping large file %s (%d bytes)", rel_path, stat.st_size)
            return None

        existing = self._entries.get(rel_path)
        if existing and existing.mtime == stat.st_mtime and existing.size == stat.st_size:
            self._stats.hits += 1
            return existing

        # mtime or size changed (or new file) – rehash
        content_hash = self._hash_file(abs_path)
        if content_hash is None:
            self._stats.errors += 1
            return None

        token_count = self._estimate_tokens(abs_path)
        entry = FileEntry(
            path=rel_path,
            content_hash=content_hash,
            mtime=stat.st_mtime,
            size=stat.st_size,
            token_count=token_count,
        )
        if existing and existing.content_hash == content_hash:
            # Content unchanged, mtime drifted – still a cache hit conceptually
            self._stats.hits += 1
        else:
            self._stats.misses += 1
        self._entries[rel_path] = entry
        return entry

    def scan(self, root: str = ".") -> list[FileEntry]:
        """Walk *root* and update every eligible file in the cache."""
        abs_root = os.path.abspath(root)
        entries: list[FileEntry] = []
        for dirpath, dirnames, filenames in os.walk(abs_root):
            # Prune ignored directories in-place
            dirnames[:] = [
                d for d in dirnames
                if d not in IGNORE_DIRS and not d.startswith(".")
            ]
            for fname in filenames:
                ext = os.path.splitext(fname)[1].lower()
                if ext in BINARY_EXTENSIONS:
                    continue
                full = os.path.join(dirpath, fname)
                entry = self.load_or_update(full)
                if entry is not None:
                    entries.append(entry)
        return entries

    def get_changed_files(self, since_commit: Optional[str] = None) -> list[str]:
        """Return list of changed file paths using ``git diff``.

        If *since_commit* is given, diffs against that commit.
        Otherwise diffs the working tree against HEAD.
        """
        cmd = ["git", "diff", "--name-only"]
        if since_commit:
            cmd.append(since_commit)
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd=self.repo_root,
                timeout=30,
            )
            if result.returncode != 0:
                logger.warning("git diff failed: %s", result.stderr.strip())
                return []
            paths = [p.strip() for p in result.stdout.splitlines() if p.strip()]
            return paths
        except (subprocess.TimeoutExpired, FileNotFoundError) as exc:
            logger.warning("git diff error: %s", exc)
            return []

    def get_diff_summary(self, path: str, since_commit: Optional[str] = None) -> Optional[str]:
        """Return unified diff for *path* (relative to repo root)."""
        cmd = ["git", "diff", "--unified=3"]
        if since_commit:
            cmd.append(since_commit)
        cmd.append("--")
        cmd.append(path)
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd=self.repo_root,
                timeout=30,
            )
            if result.returncode != 0:
                logger.warning("git diff failed for %s: %s", path, result.stderr.strip())
                return None
            return result.stdout if result.stdout.strip() else None
        except (subprocess.TimeoutExpired, FileNotFoundError) as exc:
            logger.warning("git diff error for %s: %s", path, exc)
            return None

    def get_stats(self) -> CacheStats:
        """Return aggregated cache statistics."""
        stats = CacheStats(
            total_files=len(self._entries),
            total_tokens=sum(e.token_count for e in self._entries.values()),
            total_size=sum(e.size for e in self._entries.values()),
            hits=self._stats.hits,
            misses=self._stats.misses,
            errors=self._stats.errors,
        )
        return stats

    def save(self) -> None:
        """Persist cache to JSON."""
        cache_dir = os.path.dirname(self.cache_path)
        if cache_dir:
            os.makedirs(cache_dir, exist_ok=True)
        data = {
            "version": 1,
            "repo_root": self.repo_root,
            "updated_at": time.time(),
            "entries": {k: v.to_dict() for k, v in self._entries.items()},
        }
        tmp_path = self.cache_path + ".tmp"
        try:
            with open(tmp_path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
            # Atomic-ish replace
            if os.path.exists(self.cache_path):
                os.replace(tmp_path, self.cache_path)
            else:
                os.rename(tmp_path, self.cache_path)
            logger.info("Cache saved to %s (%d entries)", self.cache_path, len(self._entries))
        except OSError as exc:
            logger.error("Failed to save cache: %s", exc)
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)

    def invalidate(self, path: str) -> bool:
        """Remove a single entry from the cache. Returns True if it existed."""
        rel_path = path.replace("\\", "/")
        return self._entries.pop(rel_path, None) is not None

    def clear(self) -> None:
        """Drop all cached entries."""
        self._entries.clear()

    # -- internal -----------------------------------------------------------

    def _load_cache(self) -> None:
        """Load persisted cache from disk."""
        if not os.path.exists(self.cache_path):
            logger.debug("No existing cache at %s", self.cache_path)
            return
        try:
            with open(self.cache_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            if data.get("version") != 1:
                logger.warning("Unknown cache version %s – ignoring", data.get("version"))
                return
            for key, val in data.get("entries", {}).items():
                self._entries[key] = FileEntry.from_dict(val)
            logger.info("Loaded %d entries from cache", len(self._entries))
        except (json.JSONDecodeError, OSError, TypeError, KeyError) as exc:
            logger.warning("Failed to load cache: %s", exc)

    def _find_repo_root(self) -> str:
        """Detect git repo root via ``git rev-parse``."""
        try:
            result = subprocess.run(
                ["git", "rev-parse", "--show-toplevel"],
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode == 0:
                return result.stdout.strip()
        except (subprocess.TimeoutExpired, FileNotFoundError):
            pass
        return os.getcwd()

    @staticmethod
    def _hash_file(path: str) -> Optional[str]:
        """Return SHA-256 hex digest, or None on read failure."""
        sha = hashlib.sha256()
        try:
            with open(path, "rb") as f:
                while True:
                    chunk = f.read(65536)
                    if not chunk:
                        break
                    sha.update(chunk)
            return sha.hexdigest()
        except OSError as exc:
            logger.debug("Cannot hash %s: %s", path, exc)
            return None

    @staticmethod
    def _estimate_tokens(path: str) -> int:
        """Estimate token count from word count (words × 1.3)."""
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                text = f.read()
            word_count = len(text.split())
            return int(word_count * TOKEN_MULTIPLIER)
        except OSError:
            return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def cli_scan(cache: ContextCache, root: str) -> None:
    """Scan files and build/update cache."""
    print(f"Scanning {os.path.abspath(root)} ...")
    entries = cache.scan(root)
    cache.save()
    print(f"  Cached {len(entries)} files")
    stats = cache.get_stats()
    print(f"  Hits: {stats.hits}  Misses: {stats.misses}  Errors: {stats.errors}")


def cli_changes(cache: ContextCache, since: Optional[str] = None) -> None:
    """Show files changed since last scan."""
    changed = cache.get_changed_files(since_commit=since)
    if not changed:
        print("No changes detected.")
        return
    print(f"{len(changed)} changed file(s):")
    for p in changed:
        print(f"  M  {p}")


def cli_diff(cache: ContextCache, since: Optional[str] = None) -> None:
    """Show diffs for changed files."""
    changed = cache.get_changed_files(since_commit=since)
    if not changed:
        print("No changes detected.")
        return
    for p in changed:
        diff = cache.get_diff_summary(p, since_commit=since)
        if diff:
            print(diff)


def cli_stats(cache: ContextCache) -> None:
    """Print cache statistics."""
    stats = cache.get_stats()
    print("Context Cache Statistics")
    print("=" * 40)
    print(f"  Total files:  {stats.total_files:>8}")
    print(f"  Total tokens: {stats.total_tokens:>8}")
    print(f"  Total size:   {stats.total_size:>8} bytes")
    print(f"  Cache hits:   {stats.hits:>8}")
    print(f"  Cache misses: {stats.misses:>8}")
    print(f"  Errors:       {stats.errors:>8}")


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Context cache with hash-based change detection",
    )
    parser.add_argument(
        "--scan",
        metavar="DIR",
        help="Scan directory and update cache",
    )
    parser.add_argument(
        "--changes",
        action="store_true",
        help="Show changed files since last scan",
    )
    parser.add_argument(
        "--diff",
        action="store_true",
        help="Show unified diffs for changed files",
    )
    parser.add_argument(
        "--stats",
        action="store_true",
        help="Print cache statistics",
    )
    parser.add_argument(
        "--since",
        metavar="COMMIT",
        help="Git commit to diff against (default: working tree vs HEAD)",
    )
    parser.add_argument(
        "--cache-path",
        default=DEFAULT_CACHE_PATH,
        help=f"Path to cache file (default: {DEFAULT_CACHE_PATH})",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable debug logging",
    )

    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s: %(message)s",
    )

    if not any([args.scan, args.changes, args.diff, args.stats]):
        parser.print_help()
        return 1

    cache = ContextCache(cache_path=args.cache_path)

    if args.scan:
        cli_scan(cache, args.scan)
    if args.changes:
        cli_changes(cache, since=args.since)
    if args.diff:
        cli_diff(cache, since=args.since)
    if args.stats:
        cli_stats(cache)

    return 0


if __name__ == "__main__":
    sys.exit(main())
