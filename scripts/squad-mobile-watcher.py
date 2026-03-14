#!/usr/bin/env python3
"""
Squad Mobile Watcher — Bridges mobile inbox to Copilot CLI and routes responses back.

Watches ~/.squad/mobile-inbox/ for incoming messages (from Telegram, Discord, etc.)
and processes them through the Squad, then writes responses to ~/.squad/mobile-outbox/.

This is the "brain" that connects the mobile bots to the actual Squad agents.

Usage:
    python squad-mobile-watcher.py

Architecture:
    [Telegram Bot] → mobile-inbox/ → [Watcher] → Copilot CLI → mobile-outbox/ → [Telegram Bot]
    [Discord Bot]  ↗                                           ↘ [Discord Bot]

Author: B'Elanna (Infrastructure)
"""

import os
import sys
import json
import time
import subprocess
import logging
from pathlib import Path
from datetime import datetime, timezone

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SQUAD_DIR = Path.home() / ".squad"
INBOX_DIR = SQUAD_DIR / "mobile-inbox"
OUTBOX_DIR = SQUAD_DIR / "mobile-outbox"
PROCESSED_DIR = SQUAD_DIR / "mobile-processed"
LOG_FILE = SQUAD_DIR / "mobile-watcher.log"

SCAN_INTERVAL = 3  # seconds between inbox scans

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
    ],
)
log = logging.getLogger("mobile-watcher")

# ---------------------------------------------------------------------------
# Message processing
# ---------------------------------------------------------------------------

def process_message(filepath: Path) -> dict | None:
    """Process a single inbox message and return a response."""
    try:
        data = json.loads(filepath.read_text(encoding="utf-8"))
    except Exception as e:
        log.error("Failed to read %s: %s", filepath.name, e)
        return None

    text = data.get("text", "").strip()
    chat_id = data.get("chat_id")
    source = data.get("source", "unknown")
    user = data.get("user", "unknown")

    if not text or not chat_id:
        log.warning("Skipping %s: missing text or chat_id", filepath.name)
        return None

    log.info("Processing from %s (@%s): %s", source, user, text[:80])

    # Route to Copilot CLI
    response_text = route_to_squad(text, user)

    return {
        "chat_id": chat_id,
        "text": response_text,
        "source": source,
        "in_reply_to": data.get("message_id"),
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }


def route_to_squad(message: str, user: str) -> str:
    """Send a message to the Squad via Copilot CLI and get a response."""

    # Build the prompt with context
    prompt = (
        f"Mobile message from @{user}:\n"
        f"{message}\n\n"
        f"Respond concisely (this goes to a mobile device). "
        f"Keep it under 500 chars if possible."
    )

    try:
        # Try copilot CLI first
        result = subprocess.run(
            ["copilot", "-m", prompt],
            capture_output=True,
            text=True,
            timeout=120,
            cwd=str(SQUAD_DIR.parent),
        )

        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
        else:
            log.warning("Copilot CLI returned no output or errored: %s", result.stderr[:200] if result.stderr else "")
            return f"📋 Message received from @{user}: \"{message}\"\n\n⏳ Squad is processing. Check back later."

    except FileNotFoundError:
        log.warning("Copilot CLI not found — storing message for manual pickup")
        return (
            f"📋 Message queued for Squad:\n"
            f"From: @{user}\n"
            f"Message: {message}\n\n"
            f"⚠️ Auto-routing unavailable. A team member will pick this up."
        )
    except subprocess.TimeoutExpired:
        log.warning("Copilot CLI timed out")
        return "⏱️ Request timed out. The Squad is busy — try again in a minute."
    except Exception as e:
        log.error("Error routing to Squad: %s", e)
        return f"❌ Error processing request: {str(e)[:100]}"


def write_response(response: dict):
    """Write a response to the outbox."""
    OUTBOX_DIR.mkdir(parents=True, exist_ok=True)

    ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S-%f")
    filename = f"response-{ts}.json"
    filepath = OUTBOX_DIR / filename

    filepath.write_text(
        json.dumps(response, indent=2, ensure_ascii=False),
        encoding="utf-8"
    )
    log.info("Response written: %s", filename)


def archive_message(filepath: Path):
    """Move processed message to archive."""
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    dest = PROCESSED_DIR / filepath.name
    filepath.rename(dest)
    log.info("Archived: %s", filepath.name)

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

def main():
    log.info("=" * 60)
    log.info("Squad Mobile Watcher starting...")
    log.info("=" * 60)
    log.info("Inbox:  %s", INBOX_DIR)
    log.info("Outbox: %s", OUTBOX_DIR)

    # Ensure directories
    INBOX_DIR.mkdir(parents=True, exist_ok=True)
    OUTBOX_DIR.mkdir(parents=True, exist_ok=True)

    log.info("Watching for messages... (Ctrl+C to stop)")

    try:
        while True:
            # Scan inbox for new messages
            for filepath in sorted(INBOX_DIR.glob("*.json")):
                response = process_message(filepath)
                if response:
                    write_response(response)
                archive_message(filepath)

            time.sleep(SCAN_INTERVAL)

    except KeyboardInterrupt:
        log.info("Watcher stopped by user.")
    except Exception as e:
        log.error("Unexpected error: %s", e, exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
