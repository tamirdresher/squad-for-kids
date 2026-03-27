# 🎥 Recording Instructions — Squad for Kids Demos

> Step-by-step guide for recording the 5-minute and 10-minute demo videos.

---

## Equipment & Software

### Recording Tool (pick one)

| Tool | Platform | Best For |
|------|----------|----------|
| **OBS Studio** (recommended) | Windows/Mac/Linux | Full control, scene switching, overlays |
| **Windows Terminal built-in** | Windows | Quick recordings, no setup |
| **ShareX** | Windows | Simple screen capture with GIF support |
| **ScreenPal** | Any | Cloud-based, easy sharing |

### Recommended: OBS Studio Setup

1. Download from [obsproject.com](https://obsproject.com/)
2. Create a new Scene: "Squad Demo"
3. Add Source: "Window Capture" → select Windows Terminal
4. Add Source: "Text (GDI+)" → for section title overlays

---

## Terminal Configuration

### Resolution
- **Recording resolution:** 1920 × 1080 (Full HD)
- **Terminal window:** Maximize to fill screen

### Font
- **Font family:** Cascadia Code (ships with Windows Terminal)
- **Font size:** 16pt (readable on video, even on mobile)
- **Alternative:** JetBrains Mono, Fira Code (any ligature font works)

### Terminal Theme

Use a dark theme with green/cyan accents for readability:

**Windows Terminal settings.json snippet:**
```json
{
  "name": "Squad Demo",
  "background": "#1a1b26",
  "foreground": "#c0caf5",
  "cursorColor": "#c0caf5",
  "selectionBackground": "#33467c",
  "black": "#15161e",
  "red": "#f7768e",
  "green": "#9ece6a",
  "yellow": "#e0af68",
  "blue": "#7aa2f7",
  "purple": "#bb9af7",
  "cyan": "#7dcfff",
  "white": "#a9b1d6",
  "brightBlack": "#414868",
  "brightRed": "#f7768e",
  "brightGreen": "#9ece6a",
  "brightYellow": "#e0af68",
  "brightBlue": "#7aa2f7",
  "brightPurple": "#bb9af7",
  "brightCyan": "#7dcfff",
  "brightWhite": "#c0caf5"
}
```

> This is the **Tokyo Night** theme. Great contrast, easy on the eyes, looks professional on video.

### Shell Prompt

Simplify the prompt to avoid visual clutter:

```powershell
# Add to your PowerShell profile for the recording
function prompt { "squad-for-kids> " }
```

---

## Audio

- **Music:** None. Keep it clean for talks and presentations.
- **Narration:** Optional — record voice-over separately if desired.
- **Typing sounds:** Mute keyboard sounds in recording.
- **System sounds:** Mute all system notification sounds before recording.

---

## Text Overlays

Add section title cards between scenes using OBS text sources or video editor:

### 5-Minute Demo Overlays

| Time | Overlay Text | Duration |
|------|-------------|----------|
| 0:00 | `🎓 Squad for Kids — 5-Minute Demo` | 3 sec |
| 0:30 | `📋 Step 1: Onboarding` | 2 sec |
| 1:30 | `🗣️ Step 2: Language Choice` | 2 sec |
| 2:00 | `🎬 Step 3: Universe Pick` | 2 sec |
| 2:45 | `✨ Step 4: Meet Your Team!` | 2 sec |
| 3:30 | `📐 Step 5: First Lesson` | 2 sec |
| 4:30 | `📊 Step 6: Parent Report` | 2 sec |

### 10-Minute Demo Overlays (additional)

| Time | Overlay Text | Duration |
|------|-------------|----------|
| 5:00 | `🎮 The Gamer: Fred Weasley` | 2 sec |
| 6:00 | `🎬 The YouTuber: George Weasley` | 2 sec |
| 7:00 | `🤗 Study Buddy: When It Gets Hard` | 2 sec |
| 7:45 | `🔄 Grade Transition: Growing Up` | 2 sec |
| 8:30 | `👨‍👩‍👦 Parent Squad: The Parent View` | 2 sec |
| 9:15 | `🇮🇱 Hebrew Mode: חברים ללמידה` | 2 sec |

### Overlay Style
- **Font:** Segoe UI Bold, 48pt
- **Color:** White (#FFFFFF) with dark drop shadow
- **Position:** Top-center of screen
- **Background:** Semi-transparent dark bar (#000000 at 60% opacity)
- **Animation:** Fade in 0.3s, hold 2s, fade out 0.3s

---

## Recording Checklist

### Before Recording

- [ ] Run `.\demos\run-demo.ps1 -Mode Fresh` to reset environment
- [ ] Verify no `.squad/student-profile.json` exists
- [ ] Set terminal font to 16pt Cascadia Code
- [ ] Apply dark theme (Tokyo Night or similar)
- [ ] Maximize terminal window (1920×1080)
- [ ] Simplify shell prompt
- [ ] Close all other apps (no notifications!)
- [ ] Mute system sounds
- [ ] Test recording tool (quick 5-second capture)
- [ ] Have demo script open on a second monitor / phone / printout

### During Recording

- [ ] Type at a natural pace — not too fast
- [ ] Pause 2-3 seconds after each Squad response (let audience read)
- [ ] If you make a typo, don't panic — type it correctly and continue
- [ ] For the grade transition scene (10-min demo), pause recording while loading the profile
- [ ] Keep mouse cursor out of the terminal unless pointing at something

### After Recording

- [ ] Watch the full recording once — check for issues
- [ ] Trim dead time at start/end
- [ ] Add section title overlays
- [ ] Add intro card: "Squad for Kids — [5/10]-Minute Demo"
- [ ] Add outro card: "github.com/tdsquadAI/squad-for-kids"
- [ ] Export at 1080p, H.264, 30fps
- [ ] File naming: `squad-for-kids-demo-5min.mp4` / `squad-for-kids-demo-10min.mp4`

---

## Tips for a Great Recording

1. **Practice the flow twice** before hitting record. Know what to type.
2. **The pauses matter.** Let the team reveal sink in. Let Dobby's response land.
3. **If Copilot gives slightly different output** than the script, that's FINE — it proves it's real, not canned.
4. **The typo rule:** If the AI's response is slightly different from the demo script, it's actually BETTER. It shows authenticity. Only re-record if something is fundamentally wrong.
5. **For Hebrew mode:** Make sure your terminal renders RTL text correctly. Windows Terminal handles this natively.
6. **Energy:** Be genuinely excited when showing the team reveal. It's the "wow" moment.

---

## File Output

| Demo | Expected Output File | Duration |
|------|---------------------|----------|
| 5-minute | `squad-for-kids-demo-5min.mp4` | ~5:00 |
| 10-minute | `squad-for-kids-demo-10min.mp4` | ~10:00 |

Upload to: YouTube (unlisted or public), GitHub release assets, or shared drive for conference submission.
