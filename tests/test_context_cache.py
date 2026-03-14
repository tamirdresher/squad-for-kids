#!/usr/bin/env python3
"""Tests for scripts/context-cache.py – ContextCache module.

Run with:
    python -m pytest tests/test_context_cache.py -v
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import textwrap
from pathlib import Path
from unittest import mock

import pytest

# ---------------------------------------------------------------------------
# Ensure the scripts directory is importable
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

# We import the module by filename (contains a hyphen) via importlib.
# The module must be registered in sys.modules *before* exec so that
# @dataclass can resolve the class's __module__.
import importlib
import importlib.machinery
import importlib.util

_mod_path = REPO_ROOT / "scripts" / "context-cache.py"
_loader = importlib.machinery.SourceFileLoader("context_cache", str(_mod_path))
_spec = importlib.util.spec_from_loader("context_cache", _loader)
context_cache = importlib.util.module_from_spec(_spec)
sys.modules["context_cache"] = context_cache  # register before exec
_loader.exec_module(context_cache)

ContextCache = context_cache.ContextCache
FileEntry = context_cache.FileEntry
CacheStats = context_cache.CacheStats


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def tmp_repo(tmp_path: Path):
    """Create a minimal git repo in a temp directory."""
    subprocess.run(["git", "init"], cwd=str(tmp_path), capture_output=True, check=True)
    subprocess.run(
        ["git", "config", "user.email", "test@test.com"],
        cwd=str(tmp_path), capture_output=True, check=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test"],
        cwd=str(tmp_path), capture_output=True, check=True,
    )
    # Create an initial commit so HEAD exists
    readme = tmp_path / "README.md"
    readme.write_text("# test\n", encoding="utf-8")
    subprocess.run(["git", "add", "."], cwd=str(tmp_path), capture_output=True, check=True)
    subprocess.run(
        ["git", "commit", "-m", "init"],
        cwd=str(tmp_path), capture_output=True, check=True,
    )
    return tmp_path


@pytest.fixture
def cache(tmp_repo: Path):
    """ContextCache pointing at the temp repo."""
    cache_file = str(tmp_repo / ".squad" / ".context-cache.json")
    return ContextCache(cache_path=cache_file, repo_root=str(tmp_repo))


# ---------------------------------------------------------------------------
# FileEntry
# ---------------------------------------------------------------------------

class TestFileEntry:
    def test_round_trip(self):
        entry = FileEntry(
            path="src/main.py",
            content_hash="abc123",
            mtime=1234567890.0,
            size=42,
            token_count=10,
        )
        d = entry.to_dict()
        restored = FileEntry.from_dict(d)
        assert restored == entry

    def test_dict_keys(self):
        entry = FileEntry("a.txt", "h", 0.0, 1, 2)
        keys = set(entry.to_dict().keys())
        assert keys == {"path", "content_hash", "mtime", "size", "token_count"}


# ---------------------------------------------------------------------------
# ContextCache – load_or_update
# ---------------------------------------------------------------------------

class TestLoadOrUpdate:
    def test_new_file(self, cache: ContextCache, tmp_repo: Path):
        f = tmp_repo / "hello.py"
        f.write_text("print('hello')\n", encoding="utf-8")
        entry = cache.load_or_update(str(f))

        assert entry is not None
        assert entry.path == "hello.py"
        assert entry.content_hash  # non-empty SHA-256
        assert entry.token_count >= 1
        assert cache.get_stats().misses == 1

    def test_cache_hit_on_second_call(self, cache: ContextCache, tmp_repo: Path):
        f = tmp_repo / "stable.txt"
        f.write_text("unchanged", encoding="utf-8")

        cache.load_or_update(str(f))
        cache.load_or_update(str(f))

        stats = cache.get_stats()
        # First call is a miss, second is a hit
        assert stats.misses == 1
        assert stats.hits == 1

    def test_detects_content_change(self, cache: ContextCache, tmp_repo: Path):
        f = tmp_repo / "data.txt"
        f.write_text("version 1", encoding="utf-8")
        e1 = cache.load_or_update(str(f))

        # Ensure mtime actually differs (some FS have 1-second resolution)
        import time; time.sleep(0.05)
        f.write_text("version 2", encoding="utf-8")
        e2 = cache.load_or_update(str(f))

        assert e1 is not None and e2 is not None
        assert e1.content_hash != e2.content_hash

    def test_skips_binary(self, cache: ContextCache, tmp_repo: Path):
        f = tmp_repo / "image.png"
        f.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00" * 100)
        # Binary extensions are filtered in scan(), not load_or_update() directly.
        # But load_or_update should still work (it doesn't filter by extension).
        entry = cache.load_or_update(str(f))
        assert entry is not None  # load_or_update doesn't filter by extension

    def test_skips_large_file(self, cache: ContextCache, tmp_repo: Path):
        f = tmp_repo / "huge.txt"
        f.write_text("x" * (3 * 1024 * 1024), encoding="utf-8")  # 3 MB
        entry = cache.load_or_update(str(f))
        assert entry is None

    def test_missing_file(self, cache: ContextCache, tmp_repo: Path):
        entry = cache.load_or_update(str(tmp_repo / "nope.txt"))
        assert entry is None
        assert cache.get_stats().errors == 1


# ---------------------------------------------------------------------------
# ContextCache – scan
# ---------------------------------------------------------------------------

class TestScan:
    def test_scans_directory(self, cache: ContextCache, tmp_repo: Path):
        (tmp_repo / "a.py").write_text("a = 1\n", encoding="utf-8")
        (tmp_repo / "b.md").write_text("# B\n", encoding="utf-8")
        sub = tmp_repo / "src"
        sub.mkdir()
        (sub / "c.go").write_text("package main\n", encoding="utf-8")

        entries = cache.scan(str(tmp_repo))
        paths = {e.path for e in entries}
        assert "a.py" in paths
        assert "b.md" in paths
        assert "src/c.go" in paths

    def test_ignores_dirs(self, cache: ContextCache, tmp_repo: Path):
        hidden = tmp_repo / "node_modules"
        hidden.mkdir()
        (hidden / "x.js").write_text("//nope\n", encoding="utf-8")

        entries = cache.scan(str(tmp_repo))
        paths = {e.path for e in entries}
        assert "node_modules/x.js" not in paths

    def test_ignores_binary_extensions(self, cache: ContextCache, tmp_repo: Path):
        (tmp_repo / "photo.jpg").write_bytes(b"\xff\xd8\xff" + b"\x00" * 50)
        (tmp_repo / "code.py").write_text("x = 1\n", encoding="utf-8")

        entries = cache.scan(str(tmp_repo))
        paths = {e.path for e in entries}
        assert "photo.jpg" not in paths
        assert "code.py" in paths


# ---------------------------------------------------------------------------
# ContextCache – persistence
# ---------------------------------------------------------------------------

class TestPersistence:
    def test_save_and_reload(self, tmp_repo: Path):
        cache_file = str(tmp_repo / ".squad" / ".context-cache.json")

        c1 = ContextCache(cache_path=cache_file, repo_root=str(tmp_repo))
        (tmp_repo / "f.txt").write_text("content", encoding="utf-8")
        c1.load_or_update(str(tmp_repo / "f.txt"))
        c1.save()

        # Reload from disk
        c2 = ContextCache(cache_path=cache_file, repo_root=str(tmp_repo))
        assert c2.get_stats().total_files == 1

    def test_cache_file_format(self, cache: ContextCache, tmp_repo: Path):
        (tmp_repo / "x.txt").write_text("hello", encoding="utf-8")
        cache.load_or_update(str(tmp_repo / "x.txt"))
        cache.save()

        with open(cache.cache_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        assert data["version"] == 1
        assert "entries" in data
        assert "x.txt" in data["entries"]
        assert "updated_at" in data

    def test_handles_corrupt_cache(self, tmp_repo: Path):
        cache_file = str(tmp_repo / ".squad" / ".context-cache.json")
        os.makedirs(os.path.dirname(cache_file), exist_ok=True)
        with open(cache_file, "w") as f:
            f.write("{{{bad json")

        # Should not raise – just logs a warning and starts empty
        c = ContextCache(cache_path=cache_file, repo_root=str(tmp_repo))
        assert c.get_stats().total_files == 0

    def test_handles_wrong_version(self, tmp_repo: Path):
        cache_file = str(tmp_repo / ".squad" / ".context-cache.json")
        os.makedirs(os.path.dirname(cache_file), exist_ok=True)
        with open(cache_file, "w") as f:
            json.dump({"version": 99, "entries": {}}, f)

        c = ContextCache(cache_path=cache_file, repo_root=str(tmp_repo))
        assert c.get_stats().total_files == 0


# ---------------------------------------------------------------------------
# ContextCache – git integration
# ---------------------------------------------------------------------------

class TestGitIntegration:
    def test_get_changed_files(self, cache: ContextCache, tmp_repo: Path):
        readme = tmp_repo / "README.md"
        readme.write_text("# updated\n", encoding="utf-8")

        changed = cache.get_changed_files()
        assert "README.md" in changed

    def test_no_changes(self, cache: ContextCache, tmp_repo: Path):
        changed = cache.get_changed_files()
        assert changed == []

    def test_get_diff_summary(self, cache: ContextCache, tmp_repo: Path):
        readme = tmp_repo / "README.md"
        readme.write_text("# updated title\n", encoding="utf-8")

        diff = cache.get_diff_summary("README.md")
        assert diff is not None
        assert "updated title" in diff

    def test_diff_no_change(self, cache: ContextCache, tmp_repo: Path):
        diff = cache.get_diff_summary("README.md")
        assert diff is None

    def test_changed_since_commit(self, cache: ContextCache, tmp_repo: Path):
        # Make a second commit
        f = tmp_repo / "new.txt"
        f.write_text("new file\n", encoding="utf-8")
        subprocess.run(["git", "add", "."], cwd=str(tmp_repo), capture_output=True, check=True)
        subprocess.run(
            ["git", "commit", "-m", "add new.txt"],
            cwd=str(tmp_repo), capture_output=True, check=True,
        )

        # Get the first commit hash
        result = subprocess.run(
            ["git", "rev-list", "--max-parents=0", "HEAD"],
            cwd=str(tmp_repo), capture_output=True, text=True, check=True,
        )
        first_commit = result.stdout.strip()

        changed = cache.get_changed_files(since_commit=first_commit)
        assert "new.txt" in changed


# ---------------------------------------------------------------------------
# ContextCache – invalidate / clear
# ---------------------------------------------------------------------------

class TestInvalidateAndClear:
    def test_invalidate(self, cache: ContextCache, tmp_repo: Path):
        f = tmp_repo / "gone.txt"
        f.write_text("bye", encoding="utf-8")
        cache.load_or_update(str(f))
        assert cache.get_stats().total_files == 1

        assert cache.invalidate("gone.txt") is True
        assert cache.get_stats().total_files == 0

    def test_invalidate_missing(self, cache: ContextCache):
        assert cache.invalidate("nonexistent.txt") is False

    def test_clear(self, cache: ContextCache, tmp_repo: Path):
        (tmp_repo / "a.txt").write_text("a", encoding="utf-8")
        (tmp_repo / "b.txt").write_text("b", encoding="utf-8")
        cache.load_or_update(str(tmp_repo / "a.txt"))
        cache.load_or_update(str(tmp_repo / "b.txt"))
        assert cache.get_stats().total_files == 2

        cache.clear()
        assert cache.get_stats().total_files == 0


# ---------------------------------------------------------------------------
# Token estimation
# ---------------------------------------------------------------------------

class TestTokenEstimation:
    def test_estimates_tokens(self, cache: ContextCache, tmp_repo: Path):
        f = tmp_repo / "words.txt"
        # 10 words
        f.write_text("one two three four five six seven eight nine ten", encoding="utf-8")
        entry = cache.load_or_update(str(f))
        assert entry is not None
        assert entry.token_count == int(10 * 1.3)  # 13

    def test_empty_file(self, cache: ContextCache, tmp_repo: Path):
        f = tmp_repo / "empty.txt"
        f.write_text("", encoding="utf-8")
        entry = cache.load_or_update(str(f))
        assert entry is not None
        assert entry.token_count == 0


# ---------------------------------------------------------------------------
# CLI (main)
# ---------------------------------------------------------------------------

class TestCLI:
    def test_no_args_prints_help(self, capsys):
        ret = context_cache.main([])
        assert ret == 1

    def test_scan_command(self, tmp_repo: Path, capsys):
        cache_file = str(tmp_repo / ".squad" / ".context-cache.json")
        (tmp_repo / "test.py").write_text("x = 1\n", encoding="utf-8")

        ret = context_cache.main([
            "--scan", str(tmp_repo),
            "--cache-path", cache_file,
        ])
        assert ret == 0
        out = capsys.readouterr().out
        assert "Scanning" in out
        assert "Cached" in out

    def test_stats_command(self, tmp_repo: Path, capsys):
        cache_file = str(tmp_repo / ".squad" / ".context-cache.json")
        (tmp_repo / "test.py").write_text("x = 1\n", encoding="utf-8")

        # Scan first, then stats
        context_cache.main(["--scan", str(tmp_repo), "--cache-path", cache_file])
        ret = context_cache.main(["--stats", "--cache-path", cache_file])
        assert ret == 0
        out = capsys.readouterr().out
        assert "Total files" in out

    def test_changes_command(self, tmp_repo: Path, capsys):
        cache_file = str(tmp_repo / ".squad" / ".context-cache.json")
        ret = context_cache.main([
            "--changes",
            "--cache-path", cache_file,
        ])
        assert ret == 0
