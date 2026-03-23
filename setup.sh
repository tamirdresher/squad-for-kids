#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════
#  Squad for Kids — macOS / Linux Setup Script
#  https://github.com/tamirdresher/squad-for-kids
#
#  Usage:
#    bash setup.sh                        # English, interactive
#    bash setup.sh --language he           # Hebrew
#    bash setup.sh --language en           # English (explicit)
#    bash setup.sh --skip-profile          # Skip student profile wizard
#    bash setup.sh --language he --skip-profile
# ═══════════════════════════════════════════════════════════════════════════

# ── ANSI Color Codes ──────────────────────────────────────────────────────
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[1;36m'
readonly RED='\033[1;31m'
readonly MAGENTA='\033[1;35m'
readonly WHITE='\033[1;37m'
readonly DIM='\033[2m'
readonly RESET='\033[0m'

# ── Global State ──────────────────────────────────────────────────────────
LANG_CODE="auto"   # auto = ask interactively
SKIP_PROFILE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_STEPS=8
CURRENT_STEP=0

# ── Cleanup trap ──────────────────────────────────────────────────────────
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        if [[ "${LANG_CODE}" == "he" ]]; then
            echo -e "  ${RED}❌  ההתקנה נכשלה בשלב ${CURRENT_STEP}/${TOTAL_STEPS}${RESET}"
            echo -e "  ${YELLOW}💡  ניתן להריץ שוב — השלבים שהושלמו לא יחזרו על עצמם${RESET}"
            echo -e "  ${DIM}     קוד שגיאה: ${exit_code}${RESET}"
        else
            echo -e "  ${RED}❌  Setup failed at step ${CURRENT_STEP}/${TOTAL_STEPS}${RESET}"
            echo -e "  ${YELLOW}💡  You can run this script again — completed steps will be skipped${RESET}"
            echo -e "  ${DIM}     Exit code: ${exit_code}${RESET}"
        fi
        echo ""
    fi
}
trap cleanup EXIT

# ── Logging Helpers ───────────────────────────────────────────────────────
step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo ""
    echo -e "  ${CYAN}[$CURRENT_STEP/$TOTAL_STEPS] $1  $2${RESET}"
    echo -e "  ${DIM}$(printf '─%.0s' {1..50})${RESET}"
}

ok() {
    echo -e "    ${GREEN}✅ $1${RESET}"
}

warn() {
    echo -e "    ${YELLOW}⚠️  $1${RESET}"
}

err() {
    echo -e "    ${RED}❌ $1${RESET}"
}

info() {
    echo -e "    ${MAGENTA}$1${RESET}"
}

dim() {
    echo -e "    ${DIM}$1${RESET}"
}

# ── Utility: check if a command exists ────────────────────────────────────
command_exists() {
    command -v "$1" &>/dev/null
}

# ── Utility: detect OS ───────────────────────────────────────────────────
detect_os() {
    local uname_out
    uname_out="$(uname -s)"
    case "$uname_out" in
        Darwin*) echo "macos" ;;
        Linux*)  echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

# ── Utility: open a URL in the default browser ──────────────────────────
open_url() {
    local url="$1"
    if [[ "$(detect_os)" == "macos" ]]; then
        open "$url" 2>/dev/null || true
    else
        xdg-open "$url" 2>/dev/null || true
    fi
}

# ── Localized message helper ─────────────────────────────────────────────
# Usage: msg "English text" "Hebrew text"
msg() {
    if [[ "${LANG_CODE}" == "he" ]]; then
        echo "$2"
    else
        echo "$1"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
#  Parse CLI Arguments
# ═══════════════════════════════════════════════════════════════════════════
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --language)
                shift
                if [[ $# -eq 0 ]]; then
                    echo -e "${RED}Error: --language requires a value (en or he)${RESET}"
                    exit 1
                fi
                LANG_CODE="$1"
                if [[ "$LANG_CODE" != "en" && "$LANG_CODE" != "he" ]]; then
                    echo -e "${RED}Error: --language must be 'en' or 'he'${RESET}"
                    exit 1
                fi
                ;;
            --skip-profile)
                SKIP_PROFILE=true
                ;;
            --help|-h)
                echo "Usage: bash setup.sh [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --language en|he   Set language (default: ask interactively)"
                echo "  --skip-profile     Skip the student profile wizard"
                echo "  --help, -h         Show this help"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${RESET}"
                echo "Run 'bash setup.sh --help' for usage."
                exit 1
                ;;
        esac
        shift
    done
}

# ═══════════════════════════════════════════════════════════════════════════
#  STEP 0 — Banner
# ═══════════════════════════════════════════════════════════════════════════
show_banner() {
    echo ""
    echo -e "${MAGENTA}  ╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${MAGENTA}  ║                                                          ║${RESET}"
    echo -e "${MAGENTA}  ║   ${CYAN}🎓  ___                      _                         ${MAGENTA}║${RESET}"
    echo -e "${MAGENTA}  ║   ${CYAN}   / __| __ _ _  _ __ _ __| |                         ${MAGENTA}║${RESET}"
    echo -e "${MAGENTA}  ║   ${CYAN}   \\__ \\/ _\` | || / _\` / _\` |                         ${MAGENTA}║${RESET}"
    echo -e "${MAGENTA}  ║   ${CYAN}   |___/\\__, |\\_,_\\__,_\\__,_|                         ${MAGENTA}║${RESET}"
    echo -e "${MAGENTA}  ║   ${CYAN}           |_|                                        ${MAGENTA}║${RESET}"
    echo -e "${MAGENTA}  ║   ${GREEN}    __           _  ___    _    _                      ${MAGENTA}║${RESET}"
    echo -e "${MAGENTA}  ║   ${GREEN}   / _|___ _ _  | |/ (_)__| |__| |                    ${MAGENTA}║${RESET}"
    echo -e "${MAGENTA}  ║   ${GREEN}  |  _/ _ \\ '_| | ' <| / _\` (_-<_|                    ${MAGENTA}║${RESET}"
    echo -e "${MAGENTA}  ║   ${GREEN}  |_| \\___/_|   |_|\\_\\_\\__,_/__(_)                    ${MAGENTA}║${RESET}"
    echo -e "${MAGENTA}  ║                                                          ║${RESET}"
    echo -e "${MAGENTA}  ║   ${WHITE}🚀 AI-Powered Learning Platform for Children          ${MAGENTA}║${RESET}"
    echo -e "${MAGENTA}  ║   ${WHITE}🚀 פלטפורמת למידה מונעת AI לילדים                     ${MAGENTA}║${RESET}"
    echo -e "${MAGENTA}  ║                                                          ║${RESET}"
    echo -e "${MAGENTA}  ╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
#  STEP 1 — Language Selection
# ═══════════════════════════════════════════════════════════════════════════
select_language() {
    if [[ "$LANG_CODE" != "auto" ]]; then
        return
    fi

    echo -e "  ${CYAN}🌐 Choose your language / בחר שפה:${RESET}"
    echo ""
    echo -e "    ${WHITE}1)${RESET} 🇬🇧  English"
    echo -e "    ${WHITE}2)${RESET} 🇮🇱  עברית (Hebrew)"
    echo ""
    read -rp "    Enter 1 or 2 [1]: " lang_choice
    lang_choice="${lang_choice:-1}"

    case "$lang_choice" in
        2|he|HE|עברית)
            LANG_CODE="he"
            echo -e "    ${GREEN}✅ שפה: עברית${RESET}"
            ;;
        *)
            LANG_CODE="en"
            echo -e "    ${GREEN}✅ Language: English${RESET}"
            ;;
    esac
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
#  STEP 2 — OS Detection
# ═══════════════════════════════════════════════════════════════════════════
detect_platform() {
    local os
    os="$(detect_os)"
    step "🖥️" "$(msg "Detecting operating system..." "זיהוי מערכת הפעלה...")"

    case "$os" in
        macos)
            ok "$(msg "macOS detected — will use Homebrew (brew) for installs" "macOS זוהה — ישתמש ב-Homebrew (brew) להתקנות")"
            OS_TYPE="macos"
            # Ensure Homebrew is available
            if ! command_exists brew; then
                warn "$(msg "Homebrew not found. Installing..." "Homebrew לא נמצא. מתקין...")"
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
                    err "$(msg "Failed to install Homebrew. Install manually: https://brew.sh" "התקנת Homebrew נכשלה. התקן ידנית: https://brew.sh")"
                    exit 1
                }
                # Add brew to PATH for Apple Silicon Macs
                if [[ -f /opt/homebrew/bin/brew ]]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                elif [[ -f /usr/local/bin/brew ]]; then
                    eval "$(/usr/local/bin/brew shellenv)"
                fi
                ok "$(msg "Homebrew installed successfully" "Homebrew הותקן בהצלחה")"
            fi
            ;;
        linux)
            ok "$(msg "Linux detected — will use apt/snap for installs" "Linux זוהה — ישתמש ב-apt/snap להתקנות")"
            OS_TYPE="linux"
            ;;
        *)
            err "$(msg "Unsupported OS: $(uname -s). This script supports macOS and Linux." "מערכת הפעלה לא נתמכת: $(uname -s). הסקריפט תומך ב-macOS ו-Linux.")"
            exit 1
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════
#  STEP 3 — Fork Detection
# ═══════════════════════════════════════════════════════════════════════════
check_fork() {
    step "🍴" "$(msg "Checking repository fork status..." "בודק מצב פורק של המאגר...")"

    if ! command_exists git; then
        warn "$(msg "Git not installed yet — skipping fork check (will install next)" "Git עדיין לא מותקן — מדלג על בדיקת פורק")"
        return
    fi

    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        warn "$(msg "Not inside a git repository. That's OK — we'll set things up!" "לא בתוך מאגר git. זה בסדר — נגדיר הכל!")"
        return
    fi

    local origin_url
    origin_url="$(git remote get-url origin 2>/dev/null || echo "")"

    if [[ -z "$origin_url" ]]; then
        warn "$(msg "No git remote 'origin' found." "לא נמצא remote 'origin' של git.")"
        return
    fi

    if [[ "$origin_url" == *"tamirdresher/squad-for-kids"* ]]; then
        warn "$(msg "This appears to be the ORIGINAL repo, not a fork." "נראה שזה המאגר המקורי, לא פורק.")"
        echo ""
        if [[ "$LANG_CODE" == "he" ]]; then
            echo -e "    ${WHITE}לחוויה הטובה ביותר, עשו פורק קודם:${RESET}"
            echo -e "    ${WHITE}  1. לכו ל-https://github.com/tamirdresher/squad-for-kids${RESET}"
            echo -e "    ${WHITE}  2. לחצו על כפתור 'Fork' (למעלה-ימין)${RESET}"
            echo -e "    ${WHITE}  3. שכפלו את הפורק שלכם והריצו את הסקריפט שם${RESET}"
        else
            echo -e "    ${WHITE}For the best experience, fork the repo first:${RESET}"
            echo -e "    ${WHITE}  1. Go to https://github.com/tamirdresher/squad-for-kids${RESET}"
            echo -e "    ${WHITE}  2. Click the 'Fork' button (top-right)${RESET}"
            echo -e "    ${WHITE}  3. Clone YOUR fork and run this script there${RESET}"
        fi
        echo ""
        read -rp "    $(msg "Open the fork page in your browser? (y/n) [y]: " "לפתוח את דף הפורק בדפדפן? (כ/ל) [כ]: ")" open_fork
        open_fork="${open_fork:-y}"
        if [[ "$open_fork" =~ ^[yYכ]$ ]]; then
            open_url "https://github.com/tamirdresher/squad-for-kids/fork"
            info "$(msg "Opening fork page..." "פותח דף פורק...")"
        fi
        echo ""
        read -rp "    $(msg "Continue setup anyway? (y/n) [y]: " "להמשיך בהתקנה בכל זאת? (כ/ל) [כ]: ")" cont
        cont="${cont:-y}"
        if [[ ! "$cont" =~ ^[yYכ]$ ]]; then
            info "$(msg "OK! Fork first, then re-run this script. 👋" "בסדר! עשו פורק קודם ואז הריצו שוב. 👋")"
            exit 0
        fi
    else
        ok "$(msg "This is a fork! Origin: $origin_url" "זה פורק! Origin: $origin_url")"

        # Set up upstream if not already configured
        local upstream_url
        upstream_url="$(git remote get-url upstream 2>/dev/null || echo "")"
        if [[ -z "$upstream_url" ]]; then
            git remote add upstream "https://github.com/tamirdresher/squad-for-kids.git" 2>/dev/null || true
            ok "$(msg "Upstream remote added for syncing updates" "נוסף upstream remote לסנכרון עדכונים")"
        else
            ok "$(msg "Upstream already configured: $upstream_url" "Upstream כבר מוגדר: $upstream_url")"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
#  STEP 4 — Prerequisites
# ═══════════════════════════════════════════════════════════════════════════
install_prerequisites() {
    step "🔧" "$(msg "Checking & installing prerequisites..." "בודק ומתקין תוכנות נדרשות...")"

    # ── Git ────────────────────────────────────────────────────────────
    if command_exists git; then
        local git_ver
        git_ver="$(git --version 2>&1)"
        ok "$(msg "Git installed — $git_ver" "Git מותקן — $git_ver")"
    else
        warn "$(msg "Git not found. Installing..." "Git לא נמצא. מתקין...")"
        if [[ "$OS_TYPE" == "macos" ]]; then
            # Xcode Command Line Tools include git on macOS
            if xcode-select -p &>/dev/null; then
                brew install git
            else
                info "$(msg "Installing Xcode Command Line Tools (includes Git)..." "מתקין Xcode Command Line Tools (כולל Git)...")"
                xcode-select --install 2>/dev/null || true
                echo -e "    ${YELLOW}$(msg "Please complete the Xcode tools popup, then re-run this script." "אנא השלם את חלון הקופץ של Xcode ואז הרץ שוב את הסקריפט.")${RESET}"
                exit 0
            fi
        else
            sudo apt-get update -qq && sudo apt-get install -y -qq git
        fi
        if command_exists git; then
            ok "$(msg "Git installed successfully ✨" "Git הותקן בהצלחה ✨")"
        else
            err "$(msg "Git installation failed. Install manually: https://git-scm.com" "התקנת Git נכשלה. התקן ידנית: https://git-scm.com")"
        fi
    fi

    # ── Node.js ────────────────────────────────────────────────────────
    if command_exists node; then
        local node_ver
        node_ver="$(node --version 2>&1)"
        ok "$(msg "Node.js installed — $node_ver" "Node.js מותקן — $node_ver")"
    else
        warn "$(msg "Node.js not found. Installing..." "Node.js לא נמצא. מתקין...")"
        if [[ "$OS_TYPE" == "macos" ]]; then
            brew install node
        else
            # Install Node.js LTS via NodeSource
            if command_exists curl; then
                curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
                sudo apt-get install -y -qq nodejs
            else
                sudo apt-get update -qq && sudo apt-get install -y -qq nodejs npm
            fi
        fi
        if command_exists node; then
            ok "$(msg "Node.js installed successfully ✨" "Node.js הותקן בהצלחה ✨")"
        else
            err "$(msg "Node.js installation failed. Install manually: https://nodejs.org" "התקנת Node.js נכשלה. התקן ידנית: https://nodejs.org")"
        fi
    fi

    # ── VS Code ────────────────────────────────────────────────────────
    if command_exists code; then
        ok "$(msg "VS Code installed" "VS Code מותקן")"
    else
        warn "$(msg "VS Code not found. Installing..." "VS Code לא נמצא. מתקין...")"
        if [[ "$OS_TYPE" == "macos" ]]; then
            brew install --cask visual-studio-code
        else
            # Try snap first, fall back to apt
            if command_exists snap; then
                sudo snap install code --classic
            else
                # Download and install via apt repository
                info "$(msg "Adding VS Code apt repository..." "מוסיף מאגר apt של VS Code...")"
                curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /tmp/microsoft.gpg
                sudo install -o root -g root -m 644 /tmp/microsoft.gpg /etc/apt/keyrings/microsoft.gpg
                echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
                sudo apt-get update -qq && sudo apt-get install -y -qq code
                rm -f /tmp/microsoft.gpg
            fi
        fi
        if command_exists code; then
            ok "$(msg "VS Code installed successfully ✨" "VS Code הותקן בהצלחה ✨")"
        else
            err "$(msg "VS Code installation failed. Install manually: https://code.visualstudio.com" "התקנת VS Code נכשלה. התקן ידנית: https://code.visualstudio.com")"
        fi
    fi

    # ── GitHub CLI ─────────────────────────────────────────────────────
    if command_exists gh; then
        ok "$(msg "GitHub CLI installed" "GitHub CLI מותקן")"
    else
        warn "$(msg "GitHub CLI not found. Installing..." "GitHub CLI לא נמצא. מתקין...")"
        if [[ "$OS_TYPE" == "macos" ]]; then
            brew install gh
        else
            # Official GitHub CLI install for Linux
            if command_exists curl; then
                (type -p wget >/dev/null || (sudo apt-get update -qq && sudo apt-get install -y -qq wget)) \
                    && sudo mkdir -p -m 755 /etc/apt/keyrings \
                    && out=$(mktemp) && wget -qO "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                    && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null \
                    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
                    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null \
                    && sudo apt-get update -qq && sudo apt-get install -y -qq gh \
                    && rm -f "$out"
            else
                err "$(msg "Cannot install GitHub CLI — curl/wget not found" "לא ניתן להתקין GitHub CLI — curl/wget לא נמצאו")"
            fi
        fi
        if command_exists gh; then
            ok "$(msg "GitHub CLI installed successfully ✨" "GitHub CLI הותקן בהצלחה ✨")"
        else
            err "$(msg "GitHub CLI installation failed. Install manually: https://cli.github.com" "התקנת GitHub CLI נכשלה. התקן ידנית: https://cli.github.com")"
        fi
    fi

    # ── GitHub Copilot Extension ───────────────────────────────────────
    if command_exists code; then
        local copilot_ext
        copilot_ext="$(code --list-extensions 2>/dev/null | grep -i "github.copilot" || echo "")"
        if [[ -n "$copilot_ext" ]]; then
            ok "$(msg "GitHub Copilot extension found in VS Code" "תוסף GitHub Copilot נמצא ב-VS Code")"
        else
            warn "$(msg "GitHub Copilot extension not found — will install in a later step" "תוסף GitHub Copilot לא נמצא — יותקן בשלב מאוחר יותר")"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
#  STEP 5 — GitHub Login
# ═══════════════════════════════════════════════════════════════════════════
github_login() {
    step "🔑" "$(msg "GitHub authentication..." "התחברות ל-GitHub...")"

    if ! command_exists gh; then
        warn "$(msg "GitHub CLI not available — skipping authentication" "GitHub CLI לא זמין — מדלג על התחברות")"
        return
    fi

    if gh auth status &>/dev/null; then
        local gh_user
        gh_user="$(gh auth status 2>&1 | grep -oP 'Logged in to github.com account \K\S+' || echo "unknown")"
        ok "$(msg "Already logged into GitHub ($gh_user)" "כבר מחובר ל-GitHub ($gh_user)")"
        return
    fi

    echo ""
    if [[ "$LANG_CODE" == "he" ]]; then
        echo -e "    ${WHITE}אם עדיין אין לך חשבון GitHub, צור אחד כאן:${RESET}"
        echo -e "    ${CYAN}  https://github.com/signup${RESET}"
        echo ""
        read -rp "    יש לך חשבון GitHub ומוכן להתחבר? (כ/ל) [כ]: " ready
    else
        echo -e "    ${WHITE}If you don't have a GitHub account yet, create one here:${RESET}"
        echo -e "    ${CYAN}  https://github.com/signup${RESET}"
        echo ""
        read -rp "    Do you have a GitHub account and ready to log in? (y/n) [y]: " ready
    fi
    ready="${ready:-y}"

    if [[ ! "$ready" =~ ^[yYכ]$ ]]; then
        warn "$(msg "Skipped login — you can log in later with: gh auth login" "דילגת על ההתחברות — תוכל להתחבר מאוחר יותר עם: gh auth login")"
        return
    fi

    info "$(msg "Opening browser for GitHub login..." "פותח דפדפן להתחברות ל-GitHub...")"
    if gh auth login --web --git-protocol https; then
        ok "$(msg "Logged into GitHub successfully! 🎉" "התחברת ל-GitHub בהצלחה! 🎉")"
    else
        warn "$(msg "Login didn't complete — try later with: gh auth login" "ההתחברות לא הושלמה — נסה מאוחר יותר עם: gh auth login")"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
#  STEP 6 — Student Profile
# ═══════════════════════════════════════════════════════════════════════════
setup_student_profile() {
    step "👤" "$(msg "Student profile setup..." "הגדרת פרופיל תלמיד...")"

    local profile_path="${SCRIPT_DIR}/student-profile.json"

    if [[ -f "$profile_path" ]]; then
        ok "$(msg "student-profile.json already exists — not overwriting" "student-profile.json כבר קיים — לא נדרס")"
        return
    fi

    if [[ "$SKIP_PROFILE" == true ]]; then
        info "$(msg "Skipping profile (--skip-profile). Creating template..." "מדלג על פרופיל (--skip-profile). יוצר תבנית...")"
        create_profile_template "$profile_path" "" "" "" "" "" ""
        ok "$(msg "Created blank student-profile.json template" "נוצרה תבנית student-profile.json ריקה")"
        dim "$(msg "The Squad will fill this in during your child's first session!" "הסקוואד ימלא את זה בפגישה הראשונה של הילד!")"
        return
    fi

    echo ""
    if [[ "$LANG_CODE" == "he" ]]; then
        echo -e "    ${WHITE}בואו נכיר את הילד/ה! 🌟${RESET}"
        echo ""
        read -rp "    👤 מה שם הילד/ה? " kid_name
        read -rp "    🎂 בן/בת כמה? " kid_age
        read -rp "    🏫 באיזו כיתה? (לדוגמה: ד, ה, ו) " kid_grade
        read -rp "    🌍 באיזו שפה הילד/ה רוצה ללמוד? (עברית/אנגלית) [עברית]: " kid_lang
        kid_lang="${kid_lang:-עברית}"
        echo ""
        echo -e "    ${WHITE}🎯 מה מעניין את הילד/ה? (הקלד מספרים מופרדים בפסיקים)${RESET}"
        echo -e "    ${DIM}   1) משחקים  2) מדע  3) אומנות  4) מוזיקה  5) ספורט${RESET}"
        echo -e "    ${DIM}   6) רובוטיקה  7) סיפורים  8) מתמטיקה  9) אחר${RESET}"
        read -rp "    בחירה [1]: " interest_nums
        interest_nums="${interest_nums:-1}"
    else
        echo -e "    ${WHITE}Let's get to know your child! 🌟${RESET}"
        echo ""
        read -rp "    👤 Child's name: " kid_name
        read -rp "    🎂 Age: " kid_age
        read -rp "    🏫 Grade (e.g. 3rd, 4th, 5th): " kid_grade
        read -rp "    🌍 Preferred learning language? (English/Hebrew) [English]: " kid_lang
        kid_lang="${kid_lang:-English}"
        echo ""
        echo -e "    ${WHITE}🎯 What interests your child? (enter numbers separated by commas)${RESET}"
        echo -e "    ${DIM}   1) Gaming  2) Science  3) Art  4) Music  5) Sports${RESET}"
        echo -e "    ${DIM}   6) Robotics  7) Stories  8) Math  9) Other${RESET}"
        read -rp "    Choice [1]: " interest_nums
        interest_nums="${interest_nums:-1}"
    fi

    # Map interest numbers to labels
    local -a interests=()
    local IFS=','
    for num in $interest_nums; do
        num="$(echo "$num" | tr -d ' ')"
        case "$num" in
            1) interests+=("$(msg "Gaming" "משחקים")") ;;
            2) interests+=("$(msg "Science" "מדע")") ;;
            3) interests+=("$(msg "Art" "אומנות")") ;;
            4) interests+=("$(msg "Music" "מוזיקה")") ;;
            5) interests+=("$(msg "Sports" "ספורט")") ;;
            6) interests+=("$(msg "Robotics" "רובוטיקה")") ;;
            7) interests+=("$(msg "Stories" "סיפורים")") ;;
            8) interests+=("$(msg "Math" "מתמטיקה")") ;;
            9) interests+=("$(msg "Other" "אחר")") ;;
        esac
    done

    # Build interests JSON array
    local interests_json="[]"
    if [[ ${#interests[@]} -gt 0 ]]; then
        interests_json="["
        local first=true
        for interest in "${interests[@]}"; do
            if [[ "$first" == true ]]; then
                first=false
            else
                interests_json+=", "
            fi
            interests_json+="\"$interest\""
        done
        interests_json+="]"
    fi

    create_profile_json "$profile_path" "$kid_name" "$kid_age" "$kid_grade" "$kid_lang" "$interests_json"

    echo ""
    ok "$(msg "Student profile saved! 🎉" "פרופיל תלמיד נשמר! 🎉")"
    dim "$(msg "  → $profile_path" "  → $profile_path")"
}

create_profile_template() {
    local path="$1"
    local now
    now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    cat > "$path" <<JSONEOF
{
  "_comment": "This file will be populated by the Squad during the child's first session",
  "name": "",
  "age": null,
  "grade": "",
  "country": "",
  "curriculum": "",
  "language": "",
  "interests": [],
  "universe": "",
  "xp": 0,
  "level": 1,
  "badges": [],
  "streak": 0,
  "created_at": "${now}",
  "last_session": null
}
JSONEOF
}

create_profile_json() {
    local path="$1"
    local name="$2"
    local age="$3"
    local grade="$4"
    local lang="$5"
    local interests_json="$6"
    local now
    now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    # Sanitize age to be a number or null
    local age_val="null"
    if [[ "$age" =~ ^[0-9]+$ ]]; then
        age_val="$age"
    fi

    cat > "$path" <<JSONEOF
{
  "_comment": "Student profile for Squad for Kids",
  "name": "${name}",
  "age": ${age_val},
  "grade": "${grade}",
  "country": "",
  "curriculum": "",
  "language": "${lang}",
  "interests": ${interests_json},
  "universe": "",
  "xp": 0,
  "level": 1,
  "badges": [],
  "streak": 0,
  "created_at": "${now}",
  "last_session": null
}
JSONEOF
}

# ═══════════════════════════════════════════════════════════════════════════
#  STEP 7 — VS Code Extensions
# ═══════════════════════════════════════════════════════════════════════════
install_vscode_extensions() {
    step "🧩" "$(msg "Installing VS Code extensions..." "מתקין תוספים ל-VS Code...")"

    if ! command_exists code; then
        warn "$(msg "VS Code not found — skipping extension install" "VS Code לא נמצא — מדלג על התקנת תוספים")"
        return
    fi

    local -a extensions=(
        "GitHub.copilot"
        "GitHub.copilot-chat"
    )

    for ext in "${extensions[@]}"; do
        local installed
        installed="$(code --list-extensions 2>/dev/null | grep -i "^${ext}$" || echo "")"
        if [[ -n "$installed" ]]; then
            ok "$(msg "$ext already installed" "$ext כבר מותקן")"
        else
            info "$(msg "Installing $ext..." "מתקין $ext...")"
            if code --install-extension "$ext" --force &>/dev/null; then
                ok "$(msg "$ext installed ✨" "$ext הותקן ✨")"
            else
                warn "$(msg "Could not install $ext — install manually from VS Code" "לא ניתן להתקין $ext — התקן ידנית מ-VS Code")"
            fi
        fi
    done
}

# ═══════════════════════════════════════════════════════════════════════════
#  STEP 8 — Final: Open VS Code & Success Message
# ═══════════════════════════════════════════════════════════════════════════
show_success() {
    step "🎉" "$(msg "Setup complete!" "ההתקנה הושלמה!")"

    # Ensure .squad directories exist
    mkdir -p "${SCRIPT_DIR}/.squad/reports" 2>/dev/null || true

    echo ""
    echo -e "  ${GREEN}╔══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "  ${GREEN}║                                                          ║${RESET}"
    if [[ "$LANG_CODE" == "he" ]]; then
        echo -e "  ${GREEN}║   🎉  ההתקנה הושלמה! הכל מוכן!                          ║${RESET}"
    else
        echo -e "  ${GREEN}║   🎉  Setup complete! You're all set!                    ║${RESET}"
    fi
    echo -e "  ${GREEN}║                                                          ║${RESET}"
    echo -e "  ${GREEN}╚══════════════════════════════════════════════════════════╝${RESET}"
    echo ""

    if [[ "$LANG_CODE" == "he" ]]; then
        echo -e "  ${WHITE}📝 השלבים הבאים:${RESET}"
        echo -e "    ${WHITE}1. פתחו את VS Code (ייפתח עכשיו!)${RESET}"
        echo -e "    ${WHITE}2. פתחו את Copilot Chat (💬 או Ctrl+Alt+I)${RESET}"
        echo -e "    ${WHITE}3. בחרו את 'squad' מהתפריט${RESET}"
        echo -e "    ${WHITE}4. לחצו על 'Autopilot (Preview)'${RESET}"
        echo -e "    ${WHITE}5. תנו לילד/ה להקליד: היי!${RESET}"
        echo ""
        echo -e "  ${DIM}📖 מדריך להורים: docs/parent-guide-he.md${RESET}"
        echo -e "  ${DIM}📖 Parent guide: docs/parent-guide.md${RESET}"
        echo ""
        echo -e "  ${DIM}🔄 לסנכרון עדכונים מהמאגר המקורי:${RESET}"
        echo -e "  ${DIM}   לחצו 'Sync fork' בדף הפורק שלכם ב-GitHub${RESET}"
        echo -e "  ${DIM}   או הריצו: git fetch upstream && git merge upstream/main${RESET}"
        echo ""
        echo -e "  ${CYAN}🔒 ההתקדמות של הילד/ה נשמרת בפורק שלכם — רק אתם רואים אותה.${RESET}"
    else
        echo -e "  ${WHITE}📝 Next steps:${RESET}"
        echo -e "    ${WHITE}1. Open VS Code (opening now!)${RESET}"
        echo -e "    ${WHITE}2. Open Copilot Chat (💬 icon or Ctrl+Alt+I / Cmd+Alt+I)${RESET}"
        echo -e "    ${WHITE}3. Select the 'squad' agent from the dropdown${RESET}"
        echo -e "    ${WHITE}4. Click 'Autopilot (Preview)'${RESET}"
        echo -e "    ${WHITE}5. Let your child type: Hi!${RESET}"
        echo ""
        echo -e "  ${DIM}📖 Parent guide: docs/parent-guide.md${RESET}"
        echo -e "  ${DIM}📖 מדריך להורים: docs/parent-guide-he.md${RESET}"
        echo ""
        echo -e "  ${DIM}🔄 To sync updates from the original repo:${RESET}"
        echo -e "  ${DIM}   Click 'Sync fork' on your GitHub fork page${RESET}"
        echo -e "  ${DIM}   Or run: git fetch upstream && git merge upstream/main${RESET}"
        echo ""
        echo -e "  ${CYAN}🔒 Your child's progress stays in YOUR fork — safe and private.${RESET}"
    fi
    echo ""

    # Open VS Code in the project directory
    if command_exists code; then
        info "$(msg "Opening VS Code..." "פותח VS Code...")"
        code "${SCRIPT_DIR}" &>/dev/null &
    fi

    echo -e "  ${GREEN}🚀 $(msg "Happy learning!" "למידה מהנה!") 🚀${RESET}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════════════════
main() {
    parse_args "$@"
    show_banner
    select_language
    detect_platform
    check_fork
    install_prerequisites
    github_login
    setup_student_profile
    install_vscode_extensions
    show_success
}

main "$@"
