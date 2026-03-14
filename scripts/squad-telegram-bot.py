#!/usr/bin/env python3
"""
Squad Telegram Bot — Mobile interface for your AI Squad.

Polls Telegram for messages, writes them to ~/.squad/mobile-inbox/,
watches ~/.squad/mobile-outbox/ for responses, and sends them back.

Usage:
    python squad-telegram-bot.py
    # or via start-telegram-bot.ps1

Token sources (checked in order):
    1. Environment variable TELEGRAM_BOT_TOKEN
    2. ~/.squad/telegram-bot-token  (plain text file)
    3. ~/.squad/telegram-config.json  {"bot_token": "..."}
    4. Windows Credential Manager: squad-telegram-bot

Author: B'Elanna (Infrastructure)
"""

import os
import sys
import json
import time
import glob
import logging
import hashlib
from pathlib import Path
from datetime import datetime, timezone

try:
    import requests
except ImportError:
    print("ERROR: 'requests' module not installed. Run: pip install requests")
    sys.exit(1)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SQUAD_DIR = Path.home() / ".squad"
INBOX_DIR = SQUAD_DIR / "mobile-inbox"
OUTBOX_DIR = SQUAD_DIR / "mobile-outbox"
CONFIG_FILE = SQUAD_DIR / "telegram-config.json"
STATE_FILE = SQUAD_DIR / "telegram-bot-state.json"
LOG_FILE = SQUAD_DIR / "telegram-bot.log"

POLL_INTERVAL = 2          # seconds between Telegram polls
OUTBOX_SCAN_INTERVAL = 1   # seconds between outbox scans
API_BASE = "https://api.telegram.org/bot{token}"

# Allowed chat IDs (empty = allow all; set in config for security)
ALLOWED_CHAT_IDS: set[int] = set()

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
log = logging.getLogger("squad-telegram")

# ---------------------------------------------------------------------------
# Token resolution
# ---------------------------------------------------------------------------

def get_token() -> str:
    """Resolve bot token from env → config file → credential manager."""

    # 1. Environment variable
    token = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
    if token:
        log.info("Token loaded from environment variable")
        return token

    # 2. Dedicated token file (~/.squad/telegram-bot-token)
    token_file = SQUAD_DIR / "telegram-bot-token"
    if token_file.exists():
        token = token_file.read_text(encoding="utf-8").strip()
        if token:
            log.info("Token loaded from %s", token_file)
            return token

    # 3. Config file
    if CONFIG_FILE.exists():
        try:
            cfg = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
            token = cfg.get("bot_token", "").strip()
            if token:
                log.info("Token loaded from %s", CONFIG_FILE)
                # Load allowed chat IDs if present
                for cid in cfg.get("allowed_chat_ids", []):
                    ALLOWED_CHAT_IDS.add(int(cid))
                return token
        except Exception as e:
            log.warning("Failed to read config: %s", e)

    # 4. Windows Credential Manager (via cmdkey / PowerShell)
    if sys.platform == "win32":
        try:
            import subprocess
            result = subprocess.run(
                ["powershell", "-NoProfile", "-Command",
                 "(New-Object System.Net.NetworkCredential('', "
                 "(Get-StoredCredential -Target 'squad-telegram-bot').Password))"
                 ".Password"],
                capture_output=True, text=True, timeout=5
            )
            token = result.stdout.strip()
            if token and not token.startswith("Get-StoredCredential"):
                log.info("Token loaded from Windows Credential Manager")
                return token
        except Exception:
            pass

    return ""

# ---------------------------------------------------------------------------
# Telegram API helpers
# ---------------------------------------------------------------------------

class TelegramBot:
    def __init__(self, token: str):
        self.token = token
        self.base = API_BASE.format(token=token)
        self.offset = 0
        self._load_state()

    def _load_state(self):
        if STATE_FILE.exists():
            try:
                state = json.loads(STATE_FILE.read_text(encoding="utf-8"))
                self.offset = state.get("offset", 0)
            except Exception:
                pass

    def _save_state(self):
        STATE_FILE.write_text(
            json.dumps({"offset": self.offset}, indent=2),
            encoding="utf-8"
        )

    def api(self, method: str, **params) -> dict:
        """Call Telegram Bot API."""
        url = f"{self.base}/{method}"
        try:
            resp = requests.post(url, json=params, timeout=35)
            resp.raise_for_status()
            return resp.json()
        except requests.exceptions.RequestException as e:
            log.error("API error (%s): %s", method, e)
            return {"ok": False, "description": str(e)}

    def get_me(self) -> dict:
        return self.api("getMe")

    def get_updates(self) -> list[dict]:
        """Long-poll for updates."""
        result = self.api("getUpdates", offset=self.offset, timeout=30)
        if not result.get("ok"):
            return []
        updates = result.get("result", [])
        if updates:
            self.offset = updates[-1]["update_id"] + 1
            self._save_state()
        return updates

    def send_message(self, chat_id: int, text: str, parse_mode: str = "Markdown") -> dict:
        """Send a message. Falls back to plain text if Markdown fails."""
        result = self.api("sendMessage", chat_id=chat_id, text=text, parse_mode=parse_mode)
        if not result.get("ok") and parse_mode:
            # Retry without parse_mode if markdown caused issues
            result = self.api("sendMessage", chat_id=chat_id, text=text)
        return result

# ---------------------------------------------------------------------------
# Inbox / Outbox
# ---------------------------------------------------------------------------

def write_to_inbox(chat_id: int, user: str, text: str, message_id: int):
    """Write an incoming message to the inbox as a JSON file."""
    INBOX_DIR.mkdir(parents=True, exist_ok=True)

    ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    msg_hash = hashlib.md5(f"{chat_id}{message_id}".encode()).hexdigest()[:6]
    filename = f"{ts}_{msg_hash}.json"

    payload = {
        "source": "telegram",
        "chat_id": chat_id,
        "message_id": message_id,
        "user": user,
        "text": text,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "status": "pending",
    }

    filepath = INBOX_DIR / filename
    filepath.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    log.info("Inbox: %s from %s → %s", text[:50], user, filename)


def scan_outbox(bot: TelegramBot):
    """Check outbox for response files and send them."""
    OUTBOX_DIR.mkdir(parents=True, exist_ok=True)

    for filepath in sorted(OUTBOX_DIR.glob("*.json")):
        try:
            data = json.loads(filepath.read_text(encoding="utf-8"))
            chat_id = data.get("chat_id")
            text = data.get("text", "")
            if not chat_id or not text:
                log.warning("Outbox file missing chat_id or text: %s", filepath.name)
                continue

            result = bot.send_message(chat_id, text)
            if result.get("ok"):
                log.info("Sent response to %s: %s", chat_id, text[:50])
                # Move to processed
                processed = filepath.with_suffix(".sent")
                filepath.rename(processed)
            else:
                log.error("Failed to send to %s: %s", chat_id, result)
        except Exception as e:
            log.error("Error processing outbox file %s: %s", filepath.name, e)

# ---------------------------------------------------------------------------
# Command handlers
# ---------------------------------------------------------------------------

HELP_TEXT = """🤖 *Squad Mobile Bot*

Commands:
/start — Welcome message
/help — This help text
/status — Check Squad status
/ask <question> — Ask your Squad something

Or just type any message — it goes to your Squad's inbox.

🇮🇱 *בוט הסקוואד לנייד*
פשוט כתוב הודעה — היא תגיע לצוות ה-AI שלך.
"""

WELCOME_TEXT = """👋 *Welcome to your Squad!*

I'm your mobile gateway to your AI team.
Send me any message and I'll relay it to your Squad.

Type /help for commands.

---
👋 *!ברוכים הבאים לסקוואד שלכם*
אני הגשר הנייד לצוות ה-AI שלכם.
שלחו לי כל הודעה ואני אעביר אותה לצוות.
"""


def handle_command(bot: TelegramBot, chat_id: int, user: str, text: str, message_id: int):
    """Handle bot commands."""
    cmd = text.split()[0].lower()

    if cmd == "/start":
        bot.send_message(chat_id, WELCOME_TEXT)
    elif cmd == "/help":
        bot.send_message(chat_id, HELP_TEXT)
    elif cmd == "/status":
        # Check for recent inbox/outbox activity
        inbox_count = len(list(INBOX_DIR.glob("*.json")))
        outbox_count = len(list(OUTBOX_DIR.glob("*.json")))
        status = (
            f"📊 *Squad Status*\n\n"
            f"📥 Pending inbox: {inbox_count}\n"
            f"📤 Pending outbox: {outbox_count}\n"
            f"⏰ Bot uptime: running\n"
            f"🔗 Connected: ✅"
        )
        bot.send_message(chat_id, status)
    elif cmd == "/ask":
        question = text[len("/ask"):].strip()
        if question:
            write_to_inbox(chat_id, user, question, message_id)
            bot.send_message(chat_id, "📨 Question sent to Squad. I'll relay the answer when it's ready.")
        else:
            bot.send_message(chat_id, "Usage: /ask <your question>")
    else:
        bot.send_message(chat_id, f"Unknown command: {cmd}\nType /help for available commands.")

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

def main():
    log.info("=" * 60)
    log.info("Squad Telegram Bot starting...")
    log.info("=" * 60)

    # Resolve token
    token = get_token()
    if not token:
        log.error(
            "No Telegram bot token found!\n"
            "Set it via one of:\n"
            "  1. Environment variable: TELEGRAM_BOT_TOKEN\n"
            "  2. Config file: %s\n"
            "  3. Run: scripts/setup-telegram-bot.ps1",
            CONFIG_FILE
        )
        sys.exit(1)

    # Ensure directories
    INBOX_DIR.mkdir(parents=True, exist_ok=True)
    OUTBOX_DIR.mkdir(parents=True, exist_ok=True)

    # Init bot
    bot = TelegramBot(token)
    me = bot.get_me()
    if me.get("ok"):
        bot_info = me["result"]
        log.info("Bot connected: @%s (%s)", bot_info.get("username"), bot_info.get("first_name"))
    else:
        log.error("Failed to connect to Telegram: %s", me)
        sys.exit(1)

    log.info("Listening for messages... (Ctrl+C to stop)")
    log.info("Inbox:  %s", INBOX_DIR)
    log.info("Outbox: %s", OUTBOX_DIR)

    last_outbox_scan = 0

    try:
        while True:
            # Poll Telegram for incoming messages
            updates = bot.get_updates()
            for update in updates:
                msg = update.get("message")
                if not msg:
                    continue

                chat_id = msg["chat"]["id"]
                user = msg.get("from", {}).get("username", "unknown")
                text = msg.get("text", "")

                if not text:
                    continue

                # Security: check allowed chat IDs
                if ALLOWED_CHAT_IDS and chat_id not in ALLOWED_CHAT_IDS:
                    log.warning("Blocked message from unauthorized chat: %s", chat_id)
                    bot.send_message(chat_id, "⛔ Unauthorized. Your chat ID: " + str(chat_id))
                    continue

                log.info("Message from @%s (chat %s): %s", user, chat_id, text[:80])

                if text.startswith("/"):
                    handle_command(bot, chat_id, user, text, msg["message_id"])
                else:
                    # Regular message → inbox
                    write_to_inbox(chat_id, user, text, msg["message_id"])
                    bot.send_message(
                        chat_id,
                        "📨 Got it! Your message is in the Squad inbox."
                    )

            # Scan outbox for responses to send
            now = time.time()
            if now - last_outbox_scan >= OUTBOX_SCAN_INTERVAL:
                scan_outbox(bot)
                last_outbox_scan = now

            time.sleep(POLL_INTERVAL)

    except KeyboardInterrupt:
        log.info("Bot stopped by user.")
    except Exception as e:
        log.error("Unexpected error: %s", e, exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
