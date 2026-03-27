# 🎬 Video 01: Fork & Setup

> **Title (EN):** Fork, Open, Learn — Getting Started in 60 Seconds
> **Title (HE):** פורק, פתח, למד — מתחילים בדקה אחת

---

## Metadata

| Field | Value |
|-------|-------|
| **Duration** | ~4 minutes |
| **Target Audience** | Parents, educators, developers |
| **Languages** | English + Hebrew (separate recordings) |
| **Prerequisites** | GitHub account, browser |
| **Difficulty** | Beginner |

---

## Key Takeaway

> A parent can set up a personalized AI learning team for their child in under 2 minutes — just fork, open a Codespace, and start chatting.

---

## Pre-Recording Setup

### Environment

```powershell
# 1. Ensure a clean fork target (or use a fresh GitHub account)
# 2. Open Edge in CDP mode for browser automation
& "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
    --remote-debugging-port=9222 `
    --user-data-dir="C:\temp\edge-demo-profile" `
    --start-maximized

# 3. Log into GitHub in the browser
# 4. Navigate to https://github.com/tdsquadAI/squad-for-kids
```

### Profile Setup

No student profile needed — this video shows the initial fork/setup before any profile exists.

### OBS Scene Setup

- **Scene 1:** Browser fullscreen (GitHub repo page)
- **Scene 2:** Codespace terminal (after launch)
- **Scene 3:** Split view (browser left, terminal right) for the "start chatting" moment

---

## Storyboard

### Scene 1: The Repo Page [0:00–0:30]

**Screen:** Browser showing `github.com/tdsquadAI/squad-for-kids`

**Narration (EN):**
> "Every child deserves a personal learning team. Let me show you how to set one up in under two minutes. Start at the Squad for Kids repository on GitHub."

**Narration (HE):**
> "כל ילד מגיע לו צוות למידה אישי. בואו אראה לכם איך להקים אחד בפחות משתי דקות. מתחילים במאגר סקוואד לילדים בגיטהאב."

**On Screen:**
1. Show the README briefly (scroll down to see the agent table)
2. Hover over the "Fork" button
3. **Click Fork**

**Expected:** GitHub fork dialog appears

---

### Scene 2: Fork the Repo [0:30–1:00]

**Screen:** GitHub fork creation dialog

**Narration (EN):**
> "Click Fork to create your own copy. This becomes your child's personal learning space — their squad lives here."

**Narration (HE):**
> "לחצו על פורק כדי ליצור עותק משלכם. זה הופך למרחב הלמידה האישי של הילד שלכם — הסקוואד שלהם חי כאן."

**On Screen:**
1. Keep default fork name `squad-for-kids`
2. Click "Create fork"
3. Wait for fork to complete (~5 seconds)

**Expected:** Redirected to your fork: `github.com/YOUR-USERNAME/squad-for-kids`

---

### Scene 3: Open Codespace [1:00–1:45]

**Screen:** Your forked repo page

**Narration (EN):**
> "Now click the green Code button, then Codespaces, then Create. That's it — no installs, no configuration. Everything runs in the cloud."

**Narration (HE):**
> "עכשיו לחצו על כפתור הקוד הירוק, אז קודספייסס, ואז צרו. זהו — בלי התקנות, בלי הגדרות. הכל רץ בענן."

**On Screen:**
1. Click green "Code" button
2. Switch to "Codespaces" tab
3. Click "Create codespace on main"
4. Show the Codespace loading (container building) — speed up 4x in post-production

**Expected:** VS Code in browser opens with the repo loaded

---

### Scene 4: The Welcome Message [1:45–2:30]

**Screen:** Codespace terminal

**Narration (EN):**
> "The Codespace comes pre-configured. Open the terminal, and you'll see a welcome message explaining what to do next."

**Narration (HE):**
> "הקודספייס מגיע מוגדר מראש. פתחו את הטרמינל ותראו הודעת ברוכים הבאים שמסבירה מה לעשות."

**On Screen:**
1. Open terminal in Codespace (Ctrl+`)
2. Show the devcontainer welcome script output
3. Highlight the instructions: "Type `copilot` to start"

**Expected:** Terminal shows welcome banner with Squad for Kids branding

---

### Scene 5: Child Starts Chatting [2:30–3:30]

**Screen:** Codespace terminal with Copilot CLI

**Type:**
```
copilot
```

Then:
```
hi! my name is Yoav and I'm 7 years old
```

**Narration (EN):**
> "And that's it! The child types 'hi' and the Squad takes over — asking their name, age, grade, and interests. Within a minute, they have their own personalized team of AI learning agents."

**Narration (HE):**
> "וזהו! הילד מקליד 'שלום' והסקוואד לוקח פיקוד — שואל את השם, הגיל, הכיתה והתחומי עניין. תוך דקה, יש להם צוות סוכני AI ללמידה מותאם אישית."

**Expected Response (verify on screen):**
```
🎉 Welcome to Squad for Kids! 🎉

I'm going to build you your very own team of awesome learning helpers!
But first, I need to get to know you a little bit. Ready? Let's go! 🚀
```

---

### Scene 6: Closing [3:30–4:00]

**Screen:** Terminal showing the onboarding in progress

**Narration (EN):**
> "Fork, Codespace, chat. Three steps to a personal AI tutor for your child. The whole setup takes less than two minutes. Try it yourself — the link is in the description."

**Narration (HE):**
> "פורק, קודספייס, צ'אט. שלושה צעדים למורה פרטי AI לילד שלכם. כל ההקמה לוקחת פחות משתי דקות. נסו בעצמכם — הלינק בתיאור."

**On Screen:**
1. Freeze on the welcome message
2. Fade to title card with repo URL

---

## Reset / Cleanup

```powershell
# After recording, delete the fork if using a demo account
# Or run the reset script to clear the student profile
.\demos\reset-demo.ps1

# Close the Codespace to avoid charges
# GitHub → Your Codespaces → Delete
```

---

## Screen Recording Notes

| Setting | Value |
|---------|-------|
| **Resolution** | 1920×1080 |
| **Main area** | Browser (Scenes 1-3), Terminal (Scenes 4-5) |
| **Speed adjustments** | 4x during Codespace build wait |
| **Pause points** | After fork creation, after welcome message |

---

## TTS Commands

```powershell
# English narration
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --file scripts/01-fork-and-setup-en.txt `
    --write-media output/narration/01-fork-and-setup-en.mp3

# Hebrew narration
edge-tts --voice "he-IL-HilaNeural" --rate "+0%" `
    --file scripts/01-fork-and-setup-he.txt `
    --write-media output/narration/01-fork-and-setup-he.mp3
```
