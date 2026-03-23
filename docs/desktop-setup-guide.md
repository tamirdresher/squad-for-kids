# 🖥️ Desktop Setup Guide — Squad for Kids

> Setting up your child's personal AI learning team on your computer.
> ⏱️ Estimated time: 15–20 minutes | 💰 Cost: Free

---

Welcome! 🎉

You're about to give your child something truly amazing — their own team of AI learning specialists that adapts to their age, interests, and pace. Whether your child loves dinosaurs, Harry Potter, or Minecraft, the Squad will meet them where they are.

This guide walks you through **every single step** with clear explanations. No technical background required. You've got this! 💪

---

## 📋 Table of Contents

1. [Before You Start](#-before-you-start)
2. [Step 1: Create a GitHub Account](#-step-1-create-a-github-account)
3. [Step 2: Fork the Repository](#-step-2-fork-the-repository)
4. [Step 3: Run the Setup Script (Recommended)](#-step-3-run-the-setup-script-recommended)
5. [Step 4: Manual Setup (Alternative)](#-step-4-manual-setup-alternative)
6. [Step 5: Start Learning!](#-step-5-start-learning)
7. [Troubleshooting](#-troubleshooting)
8. [FAQ](#-faq)

---

## 📦 Before You Start

### What You'll Need

| ✅ | Item | Notes |
|---|------|-------|
| ☐ | A laptop or desktop computer | Windows 10/11, macOS, or Linux |
| ☐ | An internet connection | Needed for setup and AI features |
| ☐ | A GitHub account (free) | We'll create one together below! |
| ☐ | About 15–20 minutes | Grab a coffee ☕ — we'll handle the rest |

> 💡 **Tip:** You do NOT need a powerful computer. If it can browse the web, it can run Squad for Kids.

### What Gets Installed

Here's what each tool does, in plain language:

| Tool | What It Is | Why We Need It |
|------|-----------|----------------|
| 🏫 **VS Code** | A free text editor by Microsoft | This is the "classroom" where your child will learn and interact with their squad |
| 🧠 **GitHub Copilot** | The AI "teacher brain" | Powers the squad's ability to teach, create stories, check work, and adapt to your child |
| 📓 **Git** | A progress tracker | Like an automatic diary — saves every learning session so nothing is ever lost |
| ⚙️ **Node.js** | A behind-the-scenes helper | Runs the learning tools quietly in the background (your child never sees it) |
| 🔗 **GitHub CLI** | A connector tool | Links your computer to GitHub, where your child's progress is safely stored |

> 🔒 **Privacy note:** All of these tools are free, open-source or from Microsoft/GitHub. Nothing shady, nothing hidden. Your child's learning data stays in YOUR GitHub account.

### System Requirements

- **CPU:** Any modern processor (2+ cores recommended)
- **RAM:** 4 GB minimum
- **Storage:** 1–2 GB free space
- **OS:** Windows 10+, macOS 10.15+, or any modern Linux distribution

---

## 👤 Step 1: Create a GitHub Account

> Already have a GitHub account? Skip to [Step 2](#-step-2-fork-the-repository)! ⏭️

GitHub is where your child's progress will be saved — think of it as a cloud drive specifically designed for learning projects.

### 1.1 — Go to GitHub

Open your web browser and navigate to:

👉 **[github.com/signup](https://github.com/signup)**

<!-- Screenshot: The GitHub signup page with a clean form asking for email -->

### 1.2 — Enter Your Email

Type **your email address** (the parent's email).

> ⚠️ **Important for parents of children under 13:** GitHub's Terms of Service require users to be at least 13 years old. Please use **your own** (parent's) email and account. Your child will use the account under your supervision.

<!-- Screenshot: Email field filled in on the GitHub signup page -->

### 1.3 — Create a Password

Choose a strong password. GitHub will show you a green checkmark ✅ when it's strong enough.

<!-- Screenshot: Password strength indicator showing green -->

### 1.4 — Pick a Username

This will be visible on your child's projects. Some ideas:

- `maya-learns` 
- `familyname-kids`
- `parent-kidname`

> 💡 You can always change this later in Settings.

<!-- Screenshot: Username field with suggestions -->

### 1.5 — Verify Your Account

GitHub will ask you to solve a quick puzzle (like identifying pictures). Complete it and click **"Create account."**

<!-- Screenshot: The verification puzzle page -->

### 1.6 — Check Your Email

GitHub sends a verification code to your email. Open your inbox, find the email from GitHub, and enter the code.

<!-- Screenshot: Email verification code entry page -->

### 1.7 — Skip the Personalization

GitHub will ask some optional questions about how you plan to use it. You can click **"Skip this step"** at the bottom — or answer them if you'd like.

🎉 **Congratulations!** You now have a GitHub account. Let's keep going!

<!-- Screenshot: GitHub dashboard after successful signup -->

---

## 🍴 Step 2: Fork the Repository

### What Does "Fork" Mean?

Think of it like this:

```
📚 Original textbook (Squad for Kids)
       ↓  You press "Fork"
📖 Your child's personal copy (same content, but YOURS to write in!)
```

When you "fork" a project on GitHub, you get your own copy. Your child's progress, notes, and achievements are saved in YOUR copy. When we release updates (new lessons, bug fixes), you can easily pull them in.

### 2.1 — Go to the Squad for Kids Repository

Open this link in your browser:

👉 **[github.com/tamirdresher/squad-for-kids](https://github.com/tamirdresher/squad-for-kids)**

<!-- Screenshot: The Squad for Kids repository main page showing the README with colorful badges -->

### 2.2 — Click the "Fork" Button

Look at the **top-right corner** of the page. You'll see three buttons: **Watch**, **Fork**, and **Star**.

Click **🍴 Fork**.

<!-- Screenshot: Arrow pointing to the Fork button in the top-right corner of the page -->

### 2.3 — Create Your Fork

On the "Create a new fork" page:

1. **Owner:** Select your GitHub account from the dropdown
2. **Repository name:** Keep it as `squad-for-kids` (don't change this!)
3. ✅ **Check** "Copy the `main` branch only"
4. Click the green **"Create fork"** button

<!-- Screenshot: The "Create a new fork" page with all fields filled in correctly -->

### 2.4 — Verify Your Fork

After a few seconds, you'll be redirected to your new fork. Look at the top-left — it should say:

```
YOUR-USERNAME / squad-for-kids
forked from tamirdresher/squad-for-kids
```

<!-- Screenshot: The fork page showing "forked from tamirdresher/squad-for-kids" text -->

> ⚠️ **Double-check:** Make sure it says YOUR username, not `tamirdresher`. If it says `tamirdresher`, you're looking at the original — go back and fork it!

✅ **You now have your own copy!** Your child's progress will be saved here.

---

## 🚀 Step 3: Run the Setup Script (Recommended)

This is the **easiest way** to set up everything on your computer. One command installs all the tools automatically!

> 🤔 **Prefer to install everything yourself?** Jump to [Step 4: Manual Setup](#-step-4-manual-setup-alternative).

---

### 🪟 Windows Setup

#### 3.1 — Open PowerShell

1. Click the **Start menu** (Windows icon, bottom-left corner)
2. Type **`PowerShell`**
3. Right-click on **"Windows PowerShell"** and select **"Run as Administrator"**

<!-- Screenshot: Start menu search showing PowerShell with "Run as Administrator" option highlighted -->

> 💡 **Why "Run as Administrator"?** The script needs to install programs like VS Code, which requires admin permission — just like installing any other program on your computer.

#### 3.2 — Allow Script Execution

Windows sometimes blocks scripts for safety. Type this command and press **Enter**:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

If asked to confirm, type **`Y`** and press **Enter**.

> 🔒 **Is this safe?** Yes! This setting allows you to run scripts you've downloaded (like ours), while still blocking scripts that aren't properly signed. It's a standard setting for developers.

<!-- Screenshot: PowerShell window showing the execution policy command and confirmation prompt -->

#### 3.3 — Run the Setup Script

Copy and paste this entire command into PowerShell, then press **Enter**:

```powershell
irm https://raw.githubusercontent.com/tamirdresher/squad-for-kids/main/setup.ps1 | iex
```

<!-- Screenshot: PowerShell window with the setup command pasted and ready to run -->

> 💡 **How to paste in PowerShell:** Right-click inside the PowerShell window — it pastes automatically!

#### 3.4 — Watch the Magic Happen ✨

The script will install everything your child needs. Here's what you'll see:

| Step | What Happens | What You See |
|------|-------------|-------------|
| 1️⃣ | Checks your system | `✅ Checking system requirements...` |
| 2️⃣ | Installs Git | `📦 Installing Git...` |
| 3️⃣ | Installs Node.js v20 | `📦 Installing Node.js...` |
| 4️⃣ | Installs VS Code | `📦 Installing VS Code...` |
| 5️⃣ | Installs GitHub CLI | `📦 Installing GitHub CLI...` |
| 6️⃣ | Logs into GitHub | `🔐 Logging into GitHub...` (opens browser) |
| 7️⃣ | Clones your fork | `📥 Cloning your repository...` |
| 8️⃣ | Installs extensions | `🧩 Installing Copilot extensions...` |
| 9️⃣ | Opens VS Code | `🎉 Opening VS Code... Ready to learn!` |

> ⏱️ This takes about 5–10 minutes depending on your internet speed. Great time for another coffee! ☕

<!-- Screenshot: PowerShell showing the setup script running with green checkmarks -->

#### 3.5 — Sign Into GitHub (When Prompted)

During step 6, the script will open your web browser and ask you to sign into GitHub. 

1. Your browser opens automatically
2. Enter a one-time code shown in PowerShell
3. Click **"Authorize"**
4. Return to PowerShell — it continues automatically!

<!-- Screenshot: Browser showing GitHub device authorization page with code entry field -->

> ✅ **Done with Windows setup!** Jump to [Step 5: Start Learning!](#-step-5-start-learning)

---

### 🍎 macOS Setup

#### 3.1 — Open Terminal

You can open Terminal in two ways:

**Option A:** Press `Cmd + Space` to open Spotlight, type **`Terminal`**, and press Enter.

**Option B:** Open **Finder** → **Applications** → **Utilities** → **Terminal**.

<!-- Screenshot: Spotlight search showing Terminal app -->

#### 3.2 — Run the Setup Script

Copy and paste this command into Terminal, then press **Enter**:

```bash
curl -fsSL https://raw.githubusercontent.com/tamirdresher/squad-for-kids/main/setup.sh | bash
```

<!-- Screenshot: macOS Terminal with the setup command pasted -->

> 💡 **How to paste in Terminal:** Press `Cmd + V`.

#### 3.3 — Enter Your Password (If Asked)

macOS may ask for your computer password to install software. This is your Mac login password (not your GitHub password). Type it and press Enter.

> 🔒 **Note:** You won't see any characters while typing your password — that's normal! It's a security feature. Just type it and press Enter.

#### 3.4 — Watch the Setup Progress

You'll see the same steps as described in the Windows section above. The script installs Git, Node.js, VS Code, and GitHub CLI automatically (using Homebrew on macOS).

When prompted to sign into GitHub, your browser will open — follow the on-screen instructions.

> ✅ **Done with macOS setup!** Jump to [Step 5: Start Learning!](#-step-5-start-learning)

---

### 🐧 Linux Setup

#### 3.1 — Open Terminal

Most Linux distributions: press `Ctrl + Alt + T` to open Terminal.

Or find **Terminal** in your Applications menu.

#### 3.2 — Run the Setup Script

Copy and paste this command into Terminal, then press **Enter**:

```bash
curl -fsSL https://raw.githubusercontent.com/tamirdresher/squad-for-kids/main/setup.sh | bash
```

#### 3.3 — Enter Your Password (If Asked)

The script may need `sudo` (admin) access to install packages. Enter your Linux user password when prompted.

#### 3.4 — Follow the Prompts

Same process as macOS — the script handles everything. Sign into GitHub when your browser opens.

> ✅ **Done with Linux setup!** Jump to [Step 5: Start Learning!](#-step-5-start-learning)

---

## 🔧 Step 4: Manual Setup (Alternative)

> This section is for parents who prefer to install each tool themselves. If you already ran the setup script in Step 3, **skip this step entirely!** ⏭️

### 4.1 — Install VS Code

1. Go to 👉 **[code.visualstudio.com](https://code.visualstudio.com/)**
2. Click the big **"Download"** button (it detects your operating system automatically)
3. Run the downloaded installer
4. Accept all defaults — click "Next" through the wizard
5. ✅ Check **"Add to PATH"** if offered (important!)

<!-- Screenshot: VS Code download page with the big blue Download button -->
<!-- Screenshot: VS Code installer with "Add to PATH" checkbox highlighted -->

### 4.2 — Install Git

1. Go to 👉 **[git-scm.com/downloads](https://git-scm.com/downloads)**
2. Download the installer for your operating system
3. Run it and accept all default settings

> 💡 **macOS users:** If you have Homebrew, just run `brew install git` in Terminal.

<!-- Screenshot: Git download page -->

### 4.3 — Install Node.js

1. Go to 👉 **[nodejs.org](https://nodejs.org/)**
2. Download the **LTS** version (the big green button on the left — LTS means "Long Term Support," i.e., the stable one)
3. Run the installer, accept all defaults

<!-- Screenshot: Node.js download page with LTS version highlighted -->

### 4.4 — Install GitHub CLI

1. Go to 👉 **[cli.github.com](https://cli.github.com/)**
2. Download and install for your operating system
3. After installation, open a **new terminal window** and run:

```bash
gh auth login
```

4. Follow the prompts:
   - Choose **GitHub.com**
   - Choose **HTTPS**
   - Choose **Login with a web browser**
   - Copy the one-time code, press Enter
   - Authorize in your browser

<!-- Screenshot: Terminal showing "gh auth login" with the web browser option selected -->

### 4.5 — Clone Your Fork

Open a terminal (PowerShell on Windows, Terminal on macOS/Linux) and run:

```bash
git clone https://github.com/YOUR-USERNAME/squad-for-kids.git
```

> ⚠️ **Replace `YOUR-USERNAME`** with your actual GitHub username! For example, if your username is `maya-learns`, the command would be:
> ```bash
> git clone https://github.com/maya-learns/squad-for-kids.git
> ```

Then move into the folder:

```bash
cd squad-for-kids
```

<!-- Screenshot: Terminal showing successful git clone output -->

### 4.6 — Install Dependencies

In the same terminal, run:

```bash
npm install
```

This installs the behind-the-scenes tools the squad needs.

### 4.7 — Run the Parent Setup Script

Still in the terminal, run:

**Windows (PowerShell):**
```powershell
.\setup-parent.ps1
```

**macOS/Linux:**
```bash
pwsh setup-parent.ps1
```

This creates your child's profile template and sets up progress tracking folders.

<!-- Screenshot: Terminal showing setup-parent.ps1 output with success messages -->

### 4.8 — Install VS Code Extensions

1. Open VS Code
2. Open the **Extensions** panel: click the blocks icon on the left sidebar, or press `Ctrl+Shift+X` (Windows/Linux) / `Cmd+Shift+X` (macOS)
3. Search for and install each of these extensions:
   - 🔍 Search **"GitHub Copilot"** → click **Install**
   - 🔍 Search **"GitHub Copilot Chat"** → click **Install**
4. After installing, VS Code will ask you to sign into GitHub — click **"Sign in"** and follow the prompts.

<!-- Screenshot: VS Code Extensions panel with "GitHub Copilot" search results showing the Install button -->
<!-- Screenshot: VS Code asking to sign into GitHub for Copilot -->

### 4.9 — Open Your Fork in VS Code

In VS Code:
1. Click **File** → **Open Folder...**
2. Navigate to the `squad-for-kids` folder you cloned in step 4.5
3. Click **"Select Folder"** (Windows) or **"Open"** (macOS)

<!-- Screenshot: VS Code with the squad-for-kids project open, showing the file explorer -->

> ✅ **Done with manual setup!** Continue to Step 5 below.

---

## 🎓 Step 5: Start Learning!

This is the exciting part! 🎉 Everything is installed — time to introduce your child to their Squad.

### 5.1 — Open VS Code

If VS Code isn't already open, launch it:
- **Windows:** Search for "VS Code" in the Start menu
- **macOS:** Search for "Visual Studio Code" in Spotlight (`Cmd + Space`)
- **Linux:** Search for "code" in your Applications menu or type `code` in terminal

### 5.2 — Open the Squad for Kids Project

If the project isn't already open:
1. Click **File** → **Open Folder...**
2. Navigate to the `squad-for-kids` folder
3. Click **Open** / **Select Folder**

<!-- Screenshot: VS Code with the squad-for-kids project files visible in the sidebar -->

### 5.3 — Open Copilot Chat

You have three ways to open it — use whichever is easiest:

| Method | How |
|--------|-----|
| ⌨️ **Keyboard shortcut** | Press `Ctrl + Alt + I` (Windows/Linux) or `Cmd + Alt + I` (macOS) |
| 🖱️ **Click the icon** | Click the 💬 **chat icon** in the left sidebar |
| 📝 **Command Palette** | Press `Ctrl + Shift + P`, type "Copilot Chat," and select it |

<!-- Screenshot: VS Code with the Copilot Chat panel open on the right side -->

### 5.4 — Select the Squad Agent

At the **bottom of the chat window**, you'll see a dropdown menu. Click it and select **"squad"** from the list.

<!-- Screenshot: Close-up of the agent dropdown showing "squad" option highlighted -->

> 🔍 **Don't see "squad" in the list?** Make sure you opened the `squad-for-kids` folder in VS Code (not a different folder). The squad agent only appears when this project is open.

### 5.5 — Enable Autopilot Mode

Click the **"Autopilot (Preview)"** button at the top of the chat panel. This lets the Squad work more independently — creating files, building projects, and managing your child's learning automatically.

<!-- Screenshot: The Autopilot toggle button in the chat panel header -->

### 5.6 — Hand It to Your Child! 🎉

Your child can now type their first message. The Squad will greet them and start the onboarding:

**In English:**
```
Hello! I'm ready to learn!
```

**In Hebrew:**
```
!שלום
```

**In Arabic:**
```
!مرحبا
```

The Squad will:
1. 👋 Greet your child warmly
2. 📝 Ask their name
3. 🎂 Ask their age/grade
4. 🎮 Let them pick a theme (Harry Potter, Minecraft, Pokémon, Star Wars...)
5. 🌍 Ask about their interests
6. 🏗️ Build their personalized learning team
7. 🚀 Suggest a first project!

<!-- Screenshot: Copilot Chat showing the Squad's friendly greeting and first onboarding question -->

> 🎯 **What happens behind the scenes:** Based on your child's age, the Squad creates the right-sized team:
> - **Ages 8–10:** 3 specialists (Teacher, Designer, Checker) — "Young Explorers Squad"
> - **Ages 11–13:** 4 specialists (Teacher, Coder, Designer, Checker) — "Builders Squad"
> - **Ages 14+:** 5 specialists (Teacher, Coder, Researcher, Designer, Checker) — "Full Squad"

---

## 🔧 Troubleshooting

Don't worry if something goes wrong — here are fixes for the most common issues!

---

### ❌ "PowerShell won't run the script"

**What you see:**
```
running scripts is disabled on this system
```

**Fix:** Run this command in PowerShell (as Administrator), then try the setup script again:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

Type `Y` when prompted and press Enter.

> 💡 **What this does:** Tells Windows it's OK to run scripts you've downloaded. This is a one-time change.

---

### ❌ "I get a 'not recognized' error"

**What you see:**
```
'git' is not recognized as an internal or external command
```
or
```
'node' is not recognized...
```

**Fix:**
1. **Close** your terminal/PowerShell window completely
2. **Open a new one** — this refreshes the system PATH (where your computer looks for programs)
3. Try the command again

> 💡 **Still not working?** Restart your computer. Some installs need a restart to take effect.

---

### ❌ "VS Code doesn't show Copilot"

**What you see:** No Copilot icon, no chat option, or a message saying "Copilot is not available."

**Fix:**
1. In VS Code, click the **person icon** (bottom-left corner) → **"Sign in to GitHub"**
2. Complete the sign-in flow in your browser
3. Restart VS Code (`Ctrl + Shift + P` → type "Reload Window" → Enter)

<!-- Screenshot: VS Code bottom-left showing the Sign In option -->

> 💡 **Still no Copilot?** Make sure the GitHub Copilot and GitHub Copilot Chat extensions are installed. Go to Extensions (`Ctrl+Shift+X`) and search for "GitHub Copilot."

---

### ❌ "The setup script stops in the middle"

**Possible causes:** Internet interruption, a download server was temporarily slow, or a permission issue.

**Fix:** Just **run the script again!** It's smart enough to skip what's already installed and continue from where it stopped.

---

### ❌ "I can't find the Squad agent in the dropdown"

**Fix checklist:**
1. ✅ Make sure you opened the **`squad-for-kids` folder** in VS Code (File → Open Folder)
2. ✅ Make sure GitHub Copilot Chat extension is installed and enabled
3. ✅ Make sure you're signed into GitHub in VS Code
4. ✅ Try reloading: `Ctrl + Shift + P` → "Developer: Reload Window"
5. ✅ Check that the file `.github/agents/squad.agent.md` exists in your project

---

### ❌ "My child accidentally deleted a file"

**Don't panic!** 😅 Git saves everything. Here's how to get it back:

Open a terminal in VS Code (`Ctrl + ~`) and run:

```bash
git restore filename.txt
```

Replace `filename.txt` with the actual file name. To restore ALL changed files:

```bash
git restore .
```

> 💡 **Everything is recoverable.** That's the beauty of Git — it's like an infinite undo button!

---

### ❌ "How do I update to the latest version?"

New lessons, features, and improvements are added regularly. Here's how to get them:

**Option A — From GitHub (easiest):**
1. Go to your fork on GitHub (`github.com/YOUR-USERNAME/squad-for-kids`)
2. You'll see a banner saying **"This branch is X commits behind tamirdresher:main"**
3. Click **"Sync fork"** → **"Update branch"**
4. On your computer, open a terminal in the project folder and run:
   ```bash
   git pull
   ```

**Option B — From the command line:**
```bash
git fetch upstream
git merge upstream/main
```

> 💡 **Don't have `upstream` set up?** Run this first:
> ```bash
> git remote add upstream https://github.com/tamirdresher/squad-for-kids.git
> ```

---

### ❌ "Copilot says I need a subscription"

GitHub Copilot is **free** for personal use with a monthly limit. If you hit the limit:
- Wait for the monthly reset (limits reset on the 1st of each month)
- Or sign up for [GitHub Copilot Free](https://github.com/features/copilot) — it includes generous free usage

For **students and educators**, Copilot is completely free with a [GitHub Education](https://education.github.com/) account.

---

## ❓ FAQ

### 💰 Do I need to pay for anything?

**No!** Everything is free:
- ✅ **VS Code** — free and open source
- ✅ **GitHub account** — free
- ✅ **GitHub Copilot** — free tier available for personal use
- ✅ **Squad for Kids** — open source, free forever
- ✅ **Git, Node.js, GitHub CLI** — all free

---

### 🔒 Is my child's data safe?

**Yes, absolutely.**

- 🏠 Everything stays on **your computer** and **your GitHub account**
- 🚫 No data is sent to third parties
- 🔍 The code is **100% open source** — you (or anyone) can inspect every line
- 🗑️ You can delete everything at any time by deleting the fork
- 👤 No personal information is required beyond a first name (which your child chooses)

---

### 📱 Can I use this on iPad/tablet?

Not directly — VS Code needs a desktop computer for the full experience. **However**, you have two great alternatives:

1. **GitHub Codespaces** (recommended) — runs VS Code in your browser on ANY device, including tablets! See the Codespace instructions in the [parent guide](parent-guide.md).
2. **vscode.dev** — a lightweight version that works in mobile browsers.

---

### 👨‍👧‍👦 Can multiple children use this?

**Yes!** Each child should have their own fork. Here's how:

1. Create a second GitHub account (or use GitHub Organizations)
2. Fork `tamirdresher/squad-for-kids` from that account
3. Each child gets their own personalized Squad, progress tracking, and learning path

> 💡 See the [Parent Guide](parent-guide.md) for detailed multi-child instructions.

---

### 🌍 What if we don't speak English?

**The Squad is multilingual!** Currently supported languages:

| Language | How to Activate |
|----------|----------------|
| 🇺🇸 English | Just type in English |
| 🇮🇱 Hebrew (עברית) | Type in Hebrew — Squad auto-detects! |
| 🇸🇦 Arabic (العربية) | Type in Arabic — Squad auto-detects! |
| 🌐 Other languages | Type in your language — the AI adapts! |

The Squad auto-detects your child's language from their first message. No configuration needed!

---

### ⏱️ How much screen time is involved?

Learning sessions are typically **15–30 minutes**. The Squad is designed for focused, meaningful interactions — not endless scrolling.

**Tips for managing screen time:**
- 🎯 Set a timer before each session
- 📋 Look at the learning report after each session (in `.squad/reports/`)
- 🏆 Celebrate completed projects, not time spent
- 🔄 Mix computer sessions with offline activities inspired by what they learned

---

### 🤷 Do I need programming knowledge?

**Absolutely not!** 

- The setup script handles all the technical stuff
- This guide explains everything in plain language
- Your child doesn't need prior experience either — the Squad starts from scratch
- The AI adapts to your child's level automatically

---

### 📊 Can I see what my child is learning?

**Yes!** There are several ways to check your child's progress:

| What | Where | How to Check |
|------|-------|-------------|
| 📝 **Student Profile** | `student-profile.json` | Open in VS Code — shows name, level, XP, badges |
| 📈 **Weekly Reports** | `.squad/reports/` folder | Summaries of what was learned each week |
| 📚 **Teaching Plan** | `.squad/teaching-plan.md` | Curriculum progress and upcoming topics |
| 📋 **Decisions Log** | `.squad/decisions.md` | What the Squad decided and why |
| 🏆 **XP & Badges** | `student-profile.json` | Points earned, level, and badges collected |

> 💡 **Tip:** Ask your child to show you what they built! The best progress check is seeing their excitement about what they created.

---

### 📚 What curricula are supported?

Squad for Kids aligns with major curricula worldwide:

- 🇺🇸 US Common Core
- 🇬🇧 UK National Curriculum
- 🇮🇱 Israeli Bagrut
- 🇦🇺 Australian ACARA
- 🇨🇦 Canadian Provincial
- 🇮🇳 Indian CBSE/ICSE

The Squad asks about your child's country and grade during onboarding and adapts accordingly.

---

### 🔄 What if I want to start over?

If you want a completely fresh start:

1. Delete your fork on GitHub (Settings → Danger Zone → Delete this repository)
2. Re-fork from `tamirdresher/squad-for-kids`
3. Delete the local folder and re-clone

Or, for a lighter reset — just delete `student-profile.json` and the `.squad/reports/` folder. The Squad will re-onboard your child on the next session.

---

## 🎉 You Did It!

Your child now has their very own AI learning team. Here's what to remember:

| Tip | Details |
|-----|---------|
| 🔄 **Update regularly** | Sync your fork to get new lessons and features |
| 📊 **Check reports** | Browse `.squad/reports/` to see weekly progress |
| 💬 **Encourage exploration** | The Squad adapts — the more your child asks, the better it gets |
| 🆘 **Need help?** | Open an issue at [github.com/tamirdresher/squad-for-kids/issues](https://github.com/tamirdresher/squad-for-kids/issues) |

> 💛 **Thank you for investing in your child's education.** You're giving them a superpower — a personal team of AI teachers that meets them exactly where they are. That's pretty amazing.

Happy learning! 🚀📚✨
