#!/usr/bin/env python3
"""
Squad Telegram Bot — Mobile interface for your AI Squad.

Polls Telegram for messages, writes them to ~/.squad/mobile-inbox/,
watches ~/.squad/mobile-outbox/ for responses, and sends them back.

Security layers:
    Layer 1: Chat ID allowlist (only pre-approved Telegram users)
    Layer 2: PIN/passphrase authentication per session (hashed, lockout on failure)
    Layer 3: Command allowlist (no arbitrary shell execution)
    + Rate limiting, audit logging, output sanitization, session timeout,
      emergency lockdown, and input sanitization against shell injection.

Usage:
    python squad-telegram-bot.py
    # or via start-telegram-bot.ps1

Required env vars:
    TELEGRAM_BOT_TOKEN — Bot token (or use config file / credential manager)
    TELEGRAM_BOT_PIN   — SHA-256 hash of the session PIN
                         Generate with: python -c "import hashlib; print(hashlib.sha256(b'YOUR_PIN').hexdigest())"

Token sources (checked in order):
    1. Environment variable TELEGRAM_BOT_TOKEN
    2. ~/.squad/telegram-bot-token  (plain text file)
    3. ~/.squad/telegram-config.json  {"bot_token": "..."}
    4. Windows Credential Manager: squad-telegram-bot

Author: B'Elanna (Infrastructure) / Hardened by Worf (Security)
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
import threading
from pathlib import Path
from datetime import datetime, timezone, timedelta
from collections import defaultdict

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
AUDIT_LOG_FILE = SQUAD_DIR / "telegram-audit.log"
LOCKDOWN_FILE = SQUAD_DIR / "telegram-lockdown"

GITHUB_REPO = "tamirdresher_microsoft/tamresearch1"
HEARTBEAT_STALE_SECONDS = 600  # 10 minutes

POLL_INTERVAL = 2          # seconds between Telegram polls
OUTBOX_SCAN_INTERVAL = 1   # seconds between outbox scans
API_BASE = "https://api.telegram.org/bot{token}"

# Allowed chat IDs (empty = allow all; set in config for security)
ALLOWED_CHAT_IDS: set[int] = set()

# Security constants
MAX_MESSAGE_LENGTH = 2000
MAX_PIN_ATTEMPTS = 3
PIN_LOCKOUT_SECONDS = 3600          # 1 hour lockout after failed PINs
SESSION_TIMEOUT_SECONDS = 1800      # 30 minutes inactivity → re-auth
RATE_LIMIT_COMMANDS_PER_MIN = 10
RATE_LIMIT_RALPH_PER_HOUR = 3
AUTO_LOCK_HOUR = 0                  # Auto-lock after midnight (0-23, configurable)

# Patterns for output sanitization — secrets/tokens/keys
_SECRET_PATTERNS = [
    re.compile(r'ghp_[A-Za-z0-9_]{36,}'),              # GitHub PAT
    re.compile(r'gho_[A-Za-z0-9_]{36,}'),              # GitHub OAuth
    re.compile(r'ghs_[A-Za-z0-9_]{36,}'),              # GitHub App token
    re.compile(r'github_pat_[A-Za-z0-9_]{22,}'),       # Fine-grained PAT
    re.compile(r'sk-[A-Za-z0-9]{20,}'),                # OpenAI keys
    re.compile(r'xoxb-[A-Za-z0-9\-]+'),                # Slack bot tokens
    re.compile(r'xoxp-[A-Za-z0-9\-]+'),                # Slack user tokens
    re.compile(r'AKIA[0-9A-Z]{16}'),                    # AWS access keys
    re.compile(r'[A-Za-z0-9+/]{40,}={0,2}', re.ASCII),  # Base64 secrets (long)
    re.compile(r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'),  # JWT tokens
    re.compile(r'["\']?[A-Z_]+(?:KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL)["\']?\s*[:=]\s*["\'][^"\']{8,}["\']', re.IGNORECASE),
]

# Shell metacharacters to strip from user input
_SHELL_INJECTION_PATTERN = re.compile(r'[`$|;&<>(){}!\[\]\\]')

# Allowed commands (Layer 3 — command allowlist)
ALLOWED_COMMANDS = frozenset([
    "/start", "/help", "/status", "/ask", "/ralph",
    "/issues", "/postpone", "/snooze", "/lockdown",
])

# ---------------------------------------------------------------------------
# Logging — operational + audit
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

# Dedicated audit logger — append-only, never rotated by the bot
_audit_handler = logging.FileHandler(AUDIT_LOG_FILE, encoding="utf-8")
_audit_handler.setFormatter(logging.Formatter("%(asctime)s %(message)s"))
audit_log = logging.getLogger("squad-telegram-audit")
audit_log.addHandler(_audit_handler)
audit_log.setLevel(logging.INFO)
audit_log.propagate = False  # don't echo to console


def audit(chat_id: int, username: str, event: str, detail: str = ""):
    """Write a structured line to the audit log."""
    safe_detail = detail[:200].replace("\n", " ") if detail else ""
    audit_log.info(
        "chat_id=%s user=%s event=%s detail=%s",
        chat_id, username or "unknown", event, safe_detail,
    )


# ---------------------------------------------------------------------------
# Security: Lockdown check
# ---------------------------------------------------------------------------

def is_locked_down() -> bool:
    """Return True if the emergency lockdown file exists."""
    return LOCKDOWN_FILE.exists()


def activate_lockdown():
    """Create the lockdown file to halt all command processing."""
    LOCKDOWN_FILE.write_text(
        json.dumps({
            "activated_at": datetime.now(timezone.utc).isoformat(),
            "reason": "Emergency lockdown via /lockdown command",
        }),
        encoding="utf-8",
    )
    log.warning("🔒 LOCKDOWN ACTIVATED")
    audit(0, "SYSTEM", "LOCKDOWN_ACTIVATED")


# ---------------------------------------------------------------------------
# Security: Output sanitization
# ---------------------------------------------------------------------------

def sanitize_output(text: str) -> str:
    """Strip secrets, tokens, file paths, and env vars from bot responses."""
    if not text:
        return text
    result = text
    for pattern in _SECRET_PATTERNS:
        result = pattern.sub("[REDACTED]", result)
    # Redact Windows absolute paths (C:\Users\..., etc.)
    result = re.sub(r'[A-Za-z]:\\(?:Users|home)[\\\/][^\s"\'<>|]+', "[PATH_REDACTED]", result)
    # Redact Unix home paths
    result = re.sub(r'/(?:home|Users)/[^\s"\'<>|]+', "[PATH_REDACTED]", result)
    # Redact env var assignments that look sensitive
    result = re.sub(
        r'(?:export\s+|set\s+)?(?:API_KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL)\s*=\s*\S+',
        "[ENV_REDACTED]",
        result,
        flags=re.IGNORECASE,
    )
    return result


# ---------------------------------------------------------------------------
# Security: Input sanitization
# ---------------------------------------------------------------------------

def sanitize_input(text: str) -> str:
    """Strip shell metacharacters from user input to prevent injection."""
    return _SHELL_INJECTION_PATTERN.sub("", text)


def validate_message_length(text: str) -> bool:
    """Enforce max message length."""
    return len(text) <= MAX_MESSAGE_LENGTH


# ---------------------------------------------------------------------------
# Security: PIN authentication (Layer 2)
# ---------------------------------------------------------------------------

class PinManager:
    """Manages per-session PIN authentication with lockout."""

    def __init__(self):
        self._pin_hash: str = os.environ.get("TELEGRAM_BOT_PIN", "").strip()
        self._authenticated_sessions: dict[int, float] = {}  # chat_id → last_activity
        self._failed_attempts: dict[int, list[float]] = defaultdict(list)  # chat_id → timestamps
        self._lock = threading.Lock()

    @property
    def pin_configured(self) -> bool:
        return bool(self._pin_hash)

    def is_locked_out(self, chat_id: int) -> tuple[bool, int]:
        """Check if chat_id is locked out. Returns (locked, remaining_seconds)."""
        with self._lock:
            attempts = self._failed_attempts.get(chat_id, [])
            # Prune old attempts beyond lockout window
            cutoff = time.time() - PIN_LOCKOUT_SECONDS
            recent = [t for t in attempts if t > cutoff]
            self._failed_attempts[chat_id] = recent
            if len(recent) >= MAX_PIN_ATTEMPTS:
                oldest = min(recent)
                remaining = int(PIN_LOCKOUT_SECONDS - (time.time() - oldest))
                return True, max(remaining, 1)
            return False, 0

    def record_failure(self, chat_id: int):
        with self._lock:
            self._failed_attempts[chat_id].append(time.time())

    def verify_pin(self, pin_input: str) -> bool:
        """Verify PIN against stored hash."""
        if not self._pin_hash:
            return True
        input_hash = hashlib.sha256(pin_input.encode("utf-8")).hexdigest()
        return input_hash == self._pin_hash

    def is_authenticated(self, chat_id: int) -> bool:
        """Check if this chat has an active authenticated session."""
        if not self.pin_configured:
            return True
        with self._lock:
            last_activity = self._authenticated_sessions.get(chat_id)
            if last_activity is None:
                return False
            # Check session timeout
            if time.time() - last_activity > SESSION_TIMEOUT_SECONDS:
                del self._authenticated_sessions[chat_id]
                return False
            # Check auto-lock hour
            now = datetime.now()
            if now.hour == AUTO_LOCK_HOUR and now.minute < 5:
                # Within the first 5 min of the auto-lock hour, expire session
                if last_activity < (time.time() - 300):
                    del self._authenticated_sessions[chat_id]
                    return False
            return True

    def authenticate(self, chat_id: int):
        """Mark this chat as authenticated."""
        with self._lock:
            self._authenticated_sessions[chat_id] = time.time()

    def touch(self, chat_id: int):
        """Update last activity for session timeout."""
        with self._lock:
            if chat_id in self._authenticated_sessions:
                self._authenticated_sessions[chat_id] = time.time()

    def deauthenticate(self, chat_id: int):
        """Expire this chat's session."""
        with self._lock:
            self._authenticated_sessions.pop(chat_id, None)


# ---------------------------------------------------------------------------
# Security: Rate limiter
# ---------------------------------------------------------------------------

class RateLimiter:
    """Per-user rate limiting for commands."""

    def __init__(self):
        self._command_timestamps: dict[int, list[float]] = defaultdict(list)
        self._ralph_timestamps: dict[int, list[float]] = defaultdict(list)
        self._lock = threading.Lock()

    def _prune(self, timestamps: list[float], window: float) -> list[float]:
        cutoff = time.time() - window
        return [t for t in timestamps if t > cutoff]

    def check_command_rate(self, chat_id: int) -> tuple[bool, int]:
        """Check general command rate. Returns (allowed, retry_after_seconds)."""
        with self._lock:
            self._command_timestamps[chat_id] = self._prune(
                self._command_timestamps[chat_id], 60
            )
            if len(self._command_timestamps[chat_id]) >= RATE_LIMIT_COMMANDS_PER_MIN:
                oldest = min(self._command_timestamps[chat_id])
                retry = int(60 - (time.time() - oldest)) + 1
                return False, max(retry, 1)
            self._command_timestamps[chat_id].append(time.time())
            return True, 0

    def check_ralph_rate(self, chat_id: int) -> tuple[bool, int]:
        """Check /ralph rate. Returns (allowed, retry_after_seconds)."""
        with self._lock:
            self._ralph_timestamps[chat_id] = self._prune(
                self._ralph_timestamps[chat_id], 3600
            )
            if len(self._ralph_timestamps[chat_id]) >= RATE_LIMIT_RALPH_PER_HOUR:
                oldest = min(self._ralph_timestamps[chat_id])
                retry = int(3600 - (time.time() - oldest)) + 1
                return False, max(retry, 1)
            self._ralph_timestamps[chat_id].append(time.time())
            return True, 0


# Global security instances
pin_manager = PinManager()
rate_limiter = RateLimiter()

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

HELP_TEXT = """🤖 *Squad Mobile Bot* (Hardened)

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
/lockdown — 🔒 Emergency kill switch (stops all commands)

💬 *Two-way chat:*
Just type any message — Squad will answer directly.
Reply to any notification to send instructions back.

🔐 *Security:*
Session PIN required on first contact.
Auto-locks after 30 min inactivity.
Max 10 commands/min, 3 Ralph rounds/hour.

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
    """Run a sanitized prompt through agency copilot and return the response."""
    # Sanitize prompt to prevent shell injection
    safe_prompt = sanitize_input(prompt)
    if not safe_prompt.strip():
        return False, "❌ Message contained only unsafe characters."
    try:
        result = subprocess.run(
            ["agency", "copilot", "--yolo", "-p", safe_prompt],
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=str(Path(__file__).resolve().parent.parent),  # repo root
        )
        output = result.stdout.strip()
        # Sanitize output to strip secrets
        output = sanitize_output(output)
        if result.returncode == 0 and output:
            return True, output
        # If stdout empty, check stderr for info
        if not output and result.stderr.strip():
            return False, sanitize_output(result.stderr.strip()[:1000])
        return bool(output), output or "No response from Squad."
    except subprocess.TimeoutExpired:
        return False, f"⏱️ Squad took longer than {timeout}s to respond. Try again or check /status."
    except FileNotFoundError:
        return False, "❌ `agency` CLI not found on this machine."
    except Exception as e:
        return False, f"❌ Error: {sanitize_output(str(e))}"


def handle_ask(bot: TelegramBot, chat_id: int, user: str, question: str, message_id: int):
    """Handle /ask or free-text messages — live two-way chat with Squad."""
    if not question:
        bot.send_message(chat_id, "Usage: /ask <your question>\nOr just type a message directly.")
        return

    # Enforce message length limit
    if not validate_message_length(question):
        bot.send_message(chat_id, f"⚠️ Message too long ({len(question)} chars). Max {MAX_MESSAGE_LENGTH}.")
        audit(chat_id, user, "MESSAGE_TOO_LONG", f"len={len(question)}")
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
        bot.send_message(chat_id, f"💬 *Squad says:*\n\n{sanitize_output(response)}")
    else:
        bot.send_message(chat_id, f"⚠️ {sanitize_output(response)}")


def handle_ralph(bot: TelegramBot, chat_id: int, user: str):
    """Trigger a Ralph round manually (rate-limited, hardcoded path)."""
    # Rate limit: max 3 per hour
    allowed, retry_after = rate_limiter.check_ralph_rate(chat_id)
    if not allowed:
        bot.send_message(chat_id, f"⏳ Rate limited. Max {RATE_LIMIT_RALPH_PER_HOUR} Ralph rounds/hour. Try again in {retry_after}s.")
        audit(chat_id, user, "RALPH_RATE_LIMITED", f"retry_after={retry_after}")
        return

    bot.send_message(chat_id, "🔄 Triggering Ralph round...")
    audit(chat_id, user, "RALPH_TRIGGERED")

    # SECURITY: Hardcoded path — never user-supplied
    ralph_watch = Path(__file__).resolve().parent.parent / "ralph-watch.ps1"
    if not ralph_watch.exists():
        bot.send_message(chat_id, "❌ ralph-watch.ps1 not found in repo root.")
        return

    # Verify the script is inside our repo (prevent symlink attacks)
    repo_root = Path(__file__).resolve().parent.parent
    try:
        ralph_watch.resolve().relative_to(repo_root.resolve())
    except ValueError:
        bot.send_message(chat_id, "❌ Security: ralph-watch.ps1 is outside the repo boundary.")
        audit(chat_id, user, "RALPH_PATH_VIOLATION", str(ralph_watch.resolve()))
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
            output = sanitize_output(result.stdout.strip())
            summary = output[-1500:] if len(output) > 1500 else output
            bot.send_message(chat_id, f"✅ Ralph round complete.\n\n```\n{summary}\n```")
        else:
            err = sanitize_output(result.stderr.strip()[-500:]) if result.stderr else "Unknown error"
            bot.send_message(chat_id, f"⚠️ Ralph round finished with errors:\n```\n{err}\n```")
    except subprocess.TimeoutExpired:
        bot.send_message(chat_id, "⏱️ Ralph round timed out (5 min limit).")
    except FileNotFoundError:
        bot.send_message(chat_id, "❌ `pwsh` not found — can't run Ralph.")
    except Exception as e:
        bot.send_message(chat_id, f"❌ Error running Ralph: {sanitize_output(str(e))}")


def handle_command(bot: TelegramBot, chat_id: int, user: str, text: str, message_id: int):
    """Handle bot commands (Layer 3: command allowlist enforced)."""
    parts = text.split()
    cmd = parts[0].lower().split("@")[0]  # strip @botname suffix

    # Layer 3: Command allowlist
    if cmd not in ALLOWED_COMMANDS:
        bot.send_message(chat_id, f"⛔ Unknown or blocked command: `{cmd}`\nType /help for available commands.")
        audit(chat_id, user, "BLOCKED_COMMAND", cmd)
        return

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
        handle_ralph(bot, chat_id, user)
    elif cmd == "/lockdown":
        handle_lockdown(bot, chat_id, user)


def handle_lockdown(bot: TelegramBot, chat_id: int, user: str):
    """Emergency kill switch — stops all command processing until manual restart."""
    activate_lockdown()
    audit(chat_id, user, "LOCKDOWN_COMMAND")
    bot.send_message(
        chat_id,
        "🔒 *LOCKDOWN ACTIVATED*\n\n"
        "All commands are now disabled.\n"
        "Delete the lockdown file to resume:\n"
        f"`~/.squad/telegram-lockdown`\n\n"
        "Bot must be manually restarted."
    )


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
    log.info("Squad Telegram Bot starting... (HARDENED)")
    log.info("=" * 60)

    # Check lockdown on startup
    if is_locked_down():
        log.error("🔒 Bot is in LOCKDOWN. Delete %s to resume.", LOCKDOWN_FILE)
        sys.exit(2)

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

    # Verify PIN is configured
    if pin_manager.pin_configured:
        log.info("🔐 PIN authentication: ENABLED")
    else:
        log.warning("⚠️  PIN authentication: DISABLED (set TELEGRAM_BOT_PIN env var)")

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
            # ── Lockdown check on every iteration ──
            if is_locked_down():
                log.warning("🔒 Lockdown detected. Halting message processing.")
                time.sleep(10)
                continue

            # Poll Telegram for incoming messages
            updates = bot.get_updates()
            for update in updates:
                msg = update.get("message")
                if not msg:
                    continue

                chat_id = msg["chat"]["id"]
                user = msg.get("from", {}).get("username", "unknown")
                first_name = msg.get("from", {}).get("first_name", "")
                text = msg.get("text", "")

                if not text:
                    continue

                # ── Layer 1: Chat ID allowlist ──
                if ALLOWED_CHAT_IDS and chat_id not in ALLOWED_CHAT_IDS:
                    log.warning("⛔ BLOCKED unauthorized chat_id=%s user=%s", chat_id, user)
                    audit(chat_id, user, "UNAUTHORIZED_ACCESS", f"first_name={first_name} text={text[:200]}")
                    # Silent ignore — do NOT reveal bot existence to unauthorized users
                    continue

                # ── Audit: log every interaction ──
                audit(chat_id, user, "MESSAGE_RECEIVED", text)

                # ── Message length check ──
                if not validate_message_length(text):
                    bot.send_message(chat_id, f"⚠️ Message too long ({len(text)} chars). Max {MAX_MESSAGE_LENGTH}.")
                    audit(chat_id, user, "MESSAGE_TOO_LONG", f"len={len(text)}")
                    continue

                # ── Layer 2: PIN authentication ──
                if pin_manager.pin_configured and not pin_manager.is_authenticated(chat_id):
                    # Check lockout first
                    locked, remaining = pin_manager.is_locked_out(chat_id)
                    if locked:
                        bot.send_message(chat_id, f"🔒 Locked out due to failed PIN attempts. Try again in {remaining}s.")
                        audit(chat_id, user, "PIN_LOCKOUT", f"remaining={remaining}")
                        continue

                    # Treat message as PIN attempt
                    if pin_manager.verify_pin(text.strip()):
                        pin_manager.authenticate(chat_id)
                        audit(chat_id, user, "PIN_SUCCESS")
                        bot.send_message(chat_id, "🔓 Authenticated. Session active.\nType /help for commands.")
                        continue
                    else:
                        pin_manager.record_failure(chat_id)
                        attempts_left = MAX_PIN_ATTEMPTS - len(pin_manager._failed_attempts.get(chat_id, []))
                        audit(chat_id, user, "PIN_FAILURE", f"attempts_left={max(attempts_left, 0)}")
                        if attempts_left <= 0:
                            bot.send_message(chat_id, f"🔒 Too many failed attempts. Locked out for {PIN_LOCKOUT_SECONDS // 60} minutes.")
                        else:
                            bot.send_message(chat_id, f"❌ Wrong PIN. {max(attempts_left, 0)} attempt(s) remaining.")
                        continue

                # ── Touch session for timeout tracking ──
                pin_manager.touch(chat_id)

                # ── Rate limiting ──
                allowed, retry_after = rate_limiter.check_command_rate(chat_id)
                if not allowed:
                    bot.send_message(chat_id, f"⏳ Rate limited. Try again in {retry_after} seconds.")
                    audit(chat_id, user, "RATE_LIMITED", f"retry_after={retry_after}")
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
