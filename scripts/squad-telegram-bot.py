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
import re
import sys
import json
import time
import glob
import logging
import hashlib
import subprocess
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
HEARTBEAT_DIR = SQUAD_DIR / "heartbeats"
CONFIG_FILE = SQUAD_DIR / "telegram-config.json"
STATE_FILE = SQUAD_DIR / "telegram-bot-state.json"
LOG_FILE = SQUAD_DIR / "telegram-bot.log"

GITHUB_REPO = "tamirdresher_microsoft/tamresearch1"
HEARTBEAT_STALE_SECONDS = 600  # 10 minutes

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
/status — Ralph status across all machines
/ask <question> — Ask your Squad a question (live response)
/ralph — Trigger a Ralph round manually
/issues — List open GitHub issues
/issues mine — Issues assigned to you
/postpone N until DATE — Postpone issue N
/snooze N until DATE — Same as /postpone

💬 *Two-way chat:*
Just type any message — Squad will answer directly.
Reply to any notification to send instructions back.

🇮🇱 *בוט הסקוואד לנייד*
פשוט כתוב הודעה — הסקוואד יענה ישירות.
"""

WELCOME_TEXT = """👋 *Welcome to your Squad!*

I'm your mobile gateway to your AI team.
Send me any message and I'll chat with your Squad live.

Type /help for commands, or just send a message.

---
👋 *!ברוכים הבאים לסקוואד שלכם*
אני הגשר הנייד לצוות ה-AI שלכם.
שלחו לי כל הודעה ואני אדבר עם הצוות בשבילכם.
"""

# Maximum seconds to wait for a copilot response
COPILOT_TIMEOUT = 120


def run_copilot(prompt: str, timeout: int = COPILOT_TIMEOUT) -> tuple[bool, str]:
    """Run a prompt through agency copilot and return the response."""
    try:
        result = subprocess.run(
            ["agency", "copilot", "--yolo", "-p", prompt],
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=str(Path(__file__).resolve().parent.parent),  # repo root
        )
        output = result.stdout.strip()
        if result.returncode == 0 and output:
            return True, output
        # If stdout empty, check stderr for info
        if not output and result.stderr.strip():
            return False, result.stderr.strip()[:1000]
        return bool(output), output or "No response from Squad."
    except subprocess.TimeoutExpired:
        return False, f"⏱️ Squad took longer than {timeout}s to respond. Try again or check /status."
    except FileNotFoundError:
        return False, "❌ `agency` CLI not found on this machine."
    except Exception as e:
        return False, f"❌ Error: {e}"


def handle_ask(bot: TelegramBot, chat_id: int, user: str, question: str, message_id: int):
    """Handle /ask or free-text messages — live two-way chat with Squad."""
    if not question:
        bot.send_message(chat_id, "Usage: /ask <your question>\nOr just type a message directly.")
        return

    # Acknowledge receipt
    bot.send_message(chat_id, "🤔 Thinking...")

    # Log to inbox for audit trail
    write_to_inbox(chat_id, user, question, message_id)

    # Run through copilot for live response
    ok, response = run_copilot(question)

    if ok:
        # Truncate very long responses for Telegram (4096 char limit)
        if len(response) > 3800:
            response = response[:3800] + "\n\n_...truncated (response too long for Telegram)_"
        bot.send_message(chat_id, f"💬 *Squad says:*\n\n{response}")
    else:
        bot.send_message(chat_id, f"⚠️ {response}")


def handle_ralph(bot: TelegramBot, chat_id: int):
    """Trigger a Ralph round manually."""
    bot.send_message(chat_id, "🔄 Triggering Ralph round...")

    ralph_watch = Path(__file__).resolve().parent.parent / "ralph-watch.ps1"
    if not ralph_watch.exists():
        bot.send_message(chat_id, "❌ ralph-watch.ps1 not found in repo root.")
        return

    try:
        result = subprocess.run(
            ["pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass",
             "-Command", f"& '{ralph_watch}' -SingleRound"],
            capture_output=True,
            text=True,
            timeout=300,  # 5 min max for a Ralph round
            cwd=str(ralph_watch.parent),
        )
        if result.returncode == 0:
            output = result.stdout.strip()
            summary = output[-1500:] if len(output) > 1500 else output
            bot.send_message(chat_id, f"✅ Ralph round complete.\n\n```\n{summary}\n```")
        else:
            err = result.stderr.strip()[-500:] if result.stderr else "Unknown error"
            bot.send_message(chat_id, f"⚠️ Ralph round finished with errors:\n```\n{err}\n```")
    except subprocess.TimeoutExpired:
        bot.send_message(chat_id, "⏱️ Ralph round timed out (5 min limit).")
    except FileNotFoundError:
        bot.send_message(chat_id, "❌ `pwsh` not found — can't run Ralph.")
    except Exception as e:
        bot.send_message(chat_id, f"❌ Error running Ralph: {e}")


def handle_command(bot: TelegramBot, chat_id: int, user: str, text: str, message_id: int):
    """Handle bot commands."""
    parts = text.split()
    cmd = parts[0].lower().split("@")[0]  # strip @botname suffix

    if cmd == "/start":
        bot.send_message(chat_id, WELCOME_TEXT)
    elif cmd == "/help":
        bot.send_message(chat_id, HELP_TEXT)
    elif cmd == "/status":
        handle_status(bot, chat_id)
    elif cmd == "/issues":
        mine_only = len(parts) > 1 and parts[1].lower() == "mine"
        handle_issues(bot, chat_id, mine_only)
    elif cmd in ("/postpone", "/snooze"):
        handle_postpone(bot, chat_id, text)
    elif cmd == "/ask":
        question = text[len("/ask"):].strip()
        handle_ask(bot, chat_id, user, question, message_id)
    elif cmd == "/ralph":
        handle_ralph(bot, chat_id)
    else:
        bot.send_message(chat_id, f"Unknown command: {cmd}\nType /help for available commands.")


# ---------------------------------------------------------------------------
# /status — Ralph heartbeat overview
# ---------------------------------------------------------------------------

def handle_status(bot: TelegramBot, chat_id: int):
    """Show status of all Ralphs from heartbeat files plus inbox/outbox stats."""
    inbox_count = len(list(INBOX_DIR.glob("*.json")))
    outbox_count = len(list(OUTBOX_DIR.glob("*.json")))

    lines = ["📊 *Squad Status*\n"]

    # Bot connectivity
    lines.append(f"📥 Pending inbox: {inbox_count}")
    lines.append(f"📤 Pending outbox: {outbox_count}")
    lines.append(f"🔗 Bot: ✅ connected\n")

    # Ralph heartbeats
    lines.append("🤖 *Ralph Agents*\n")

    heartbeat_files = sorted(HEARTBEAT_DIR.glob("*.json")) if HEARTBEAT_DIR.exists() else []
    if not heartbeat_files:
        lines.append("_No Ralphs currently reporting._")
        lines.append("_Run ralph-heartbeat.ps1 to start reporting._")
    else:
        now = datetime.now(timezone.utc)
        for hb_file in heartbeat_files:
            try:
                hb = json.loads(hb_file.read_text(encoding="utf-8"))
            except Exception:
                continue

            machine = hb.get("machine", hb_file.stem)
            status = hb.get("status", "unknown")
            rnd = hb.get("round", "?")
            last_ts = hb.get("last_activity", "")
            failures = hb.get("failures", 0)

            # Determine freshness
            stale = True
            age_str = "unknown"
            if last_ts:
                try:
                    last_dt = datetime.fromisoformat(last_ts.replace("Z", "+00:00"))
                    age_secs = (now - last_dt).total_seconds()
                    stale = age_secs > HEARTBEAT_STALE_SECONDS
                    if age_secs < 60:
                        age_str = f"{int(age_secs)}s ago"
                    elif age_secs < 3600:
                        age_str = f"{int(age_secs // 60)}m ago"
                    else:
                        age_str = f"{int(age_secs // 3600)}h ago"
                except Exception:
                    pass

            icon = "🟢" if not stale and status == "running" else "🟡" if not stale else "🔴"
            fail_str = f" ⚠️ {failures} failures" if failures else ""

            lines.append(f"{icon} *{machine}*")
            lines.append(f"    Round {rnd} · {status} · {age_str}{fail_str}")

    bot.send_message(chat_id, "\n".join(lines))


# ---------------------------------------------------------------------------
# /issues — GitHub issue list
# ---------------------------------------------------------------------------

def _run_gh(args: list[str], timeout: int = 30) -> tuple[bool, str]:
    """Run a gh CLI command, return (success, output)."""
    try:
        result = subprocess.run(
            ["gh"] + args,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        if result.returncode == 0:
            return True, result.stdout.strip()
        return False, result.stderr.strip() or f"gh exited with code {result.returncode}"
    except FileNotFoundError:
        return False, "gh CLI not found — install from https://cli.github.com"
    except subprocess.TimeoutExpired:
        return False, "gh command timed out"
    except Exception as e:
        return False, str(e)


def handle_issues(bot: TelegramBot, chat_id: int, mine_only: bool = False):
    """List open GitHub issues."""
    gh_args = [
        "issue", "list",
        "--repo", GITHUB_REPO,
        "--search", "is:open",
        "--json", "number,title,labels",
        "--limit", "20",
    ]
    if mine_only:
        gh_args.extend(["--assignee", "@me"])

    bot.send_message(chat_id, "🔍 Fetching issues...")

    ok, output = _run_gh(gh_args)
    if not ok:
        bot.send_message(chat_id, f"❌ Failed to fetch issues:\n`{output}`")
        return

    try:
        issues = json.loads(output)
    except json.JSONDecodeError:
        bot.send_message(chat_id, f"❌ Unexpected gh output:\n`{output[:200]}`")
        return

    if not issues:
        msg = "📋 No open issues found."
        if mine_only:
            msg = "📋 No open issues assigned to you."
        bot.send_message(chat_id, msg)
        return

    header = "📋 *Your Open Issues*\n" if mine_only else "📋 *Open Issues*\n"
    lines = [header]

    for issue in issues:
        num = issue.get("number", "?")
        title = issue.get("title", "Untitled")
        labels = issue.get("labels", [])
        label_names = [lb.get("name", "") for lb in labels if lb.get("name")]

        # Truncate long titles for mobile readability
        if len(title) > 60:
            title = title[:57] + "..."

        label_str = ""
        if label_names:
            tags = " ".join(f"`{n}`" for n in label_names[:3])
            label_str = f"\n    {tags}"

        lines.append(f"• *#{num}* {title}{label_str}")

    lines.append(f"\n_Showing {len(issues)} issue(s)_")
    bot.send_message(chat_id, "\n".join(lines))


# ---------------------------------------------------------------------------
# /postpone | /snooze — Postpone an issue
# ---------------------------------------------------------------------------

# Matches: /postpone 42 until 2025-07-15
#          /snooze 42 until next Monday
#          /postpone 42 until tomorrow
_POSTPONE_RE = re.compile(
    r"^/(?:postpone|snooze)\s+#?(\d+)\s+until\s+(.+)$",
    re.IGNORECASE,
)


def handle_postpone(bot: TelegramBot, chat_id: int, text: str):
    """Postpone a GitHub issue by adding a label and comment."""
    m = _POSTPONE_RE.match(text.strip())
    if not m:
        bot.send_message(
            chat_id,
            "Usage: /postpone <issue#> until <date>\n"
            "Example: `/postpone 42 until 2025-07-15`",
        )
        return

    issue_num = m.group(1)
    date_str = m.group(2).strip()

    bot.send_message(chat_id, f"⏳ Postponing issue #{issue_num}...")

    # 1. Add label
    ok, err = _run_gh([
        "issue", "edit", issue_num,
        "--repo", GITHUB_REPO,
        "--add-label", "status:postponed",
    ])
    if not ok:
        # Label might not exist yet — try to create it first
        _run_gh([
            "label", "create", "status:postponed",
            "--repo", GITHUB_REPO,
            "--description", "Issue postponed via Telegram",
            "--color", "FBCA04",
            "--force",
        ])
        ok, err = _run_gh([
            "issue", "edit", issue_num,
            "--repo", GITHUB_REPO,
            "--add-label", "status:postponed",
        ])
        if not ok:
            bot.send_message(chat_id, f"❌ Failed to add label: `{err}`")
            return

    # 2. Add comment
    comment = f"⏸️ Postponed until {date_str} via Telegram"
    ok, err = _run_gh([
        "issue", "comment", issue_num,
        "--repo", GITHUB_REPO,
        "--body", comment,
    ])
    if not ok:
        bot.send_message(chat_id, f"⚠️ Label added but comment failed: `{err}`")
        return

    bot.send_message(
        chat_id,
        f"✅ Issue *#{issue_num}* postponed until *{date_str}*\n"
        f"🏷️ Label: `status:postponed`\n"
        f"💬 Comment added",
    )

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
                    # Free-text message → live two-way chat with Squad
                    handle_ask(bot, chat_id, user, text, msg["message_id"])

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
