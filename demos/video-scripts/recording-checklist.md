# 🎥 Recording Checklist — Squad for Kids Demos

> Everything needed to record, edit, and publish demo videos.

---

## Hardware Requirements

| Item | Minimum | Recommended |
|------|---------|-------------|
| **Display** | 1920×1080 | 2560×1440 (record at 1080p) |
| **RAM** | 8 GB | 16 GB (Copilot CLI + OBS + browser) |
| **CPU** | 4 cores | 8 cores (smooth encoding) |
| **Microphone** | Built-in laptop | USB condenser (Blue Yeti, AT2020) |
| **Storage** | 10 GB free | 50 GB free (raw footage is large) |

---

## Software Requirements

### Recording & Capture

| Tool | Purpose | Install |
|------|---------|---------|
| **OBS Studio** | Screen recording + overlays | `winget install OBSProject.OBSStudio` |
| **ShareX** | Quick screenshots/GIFs | `winget install ShareX.ShareX` |
| **Windows Terminal** | Terminal for demos | Built-in on Windows 11 |
| **Edge** (CDP mode) | Browser automation demos | `msedge --remote-debugging-port=9222` |

### Audio Generation (TTS)

| Tool | Purpose | Install |
|------|---------|---------|
| **edge-tts** | Microsoft neural voices (free) | `pip install edge-tts` |
| **gTTS** | Google TTS fallback | `pip install gTTS` |
| **ffmpeg** | Audio/video processing | `winget install Gyan.FFmpeg` |

### Post-Processing

| Tool | Purpose | Install |
|------|---------|---------|
| **ffmpeg** | Trim, crop, speed, concat | `winget install Gyan.FFmpeg` |
| **DaVinci Resolve** | Advanced editing (optional) | Free from blackmagicdesign.com |
| **Audacity** | Audio editing/noise removal | `winget install Audacity.Audacity` |

---

## Common Recording Settings

### OBS Configuration

```
Resolution:     1920 × 1080
Frame rate:     30 FPS (sufficient for terminal demos)
Encoder:        x264 (software) or NVENC (if NVIDIA GPU)
Rate control:   CRF 18 (high quality)
Output format:  MKV (remux to MP4 after)
Audio:          48 kHz, 192 kbps AAC
```

### Terminal Setup (before every recording)

```powershell
# 1. Set simplified prompt
function prompt { "squad-for-kids> " }

# 2. Set font size to 16pt in Windows Terminal settings
# 3. Use Tokyo Night theme (see demos/RECORDING.md)
# 4. Maximize terminal window
# 5. Close all other visible windows
# 6. Disable desktop notifications (Focus Assist → Alarms Only)
```

### Browser Setup (for GitHub/web demos)

```powershell
# Launch Edge in CDP mode for Playwright automation
& "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
    --remote-debugging-port=9222 `
    --user-data-dir="C:\temp\edge-demo-profile" `
    --start-maximized
```

### Screen Regions to Capture

| Demo Type | What to Show | OBS Source |
|-----------|-------------|------------|
| Terminal-only | Full terminal window | Window Capture → Terminal |
| GitHub issues | Browser + terminal side-by-side | Display Capture, cropped |
| Onboarding | Terminal centered, 80% screen | Window Capture + padding |
| WhatsApp/Telegram | Phone mockup + terminal | Multi-source scene |

---

## Audio Generation Pipeline

### English Narration (edge-tts)

```powershell
# Female narrator — natural, warm
edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
    --text "Welcome to Squad for Kids!" `
    --write-media narration-en.mp3

# Male narrator alternative
edge-tts --voice "en-US-GuyNeural" --rate "+5%" `
    --text "Welcome to Squad for Kids!" `
    --write-media narration-en-male.mp3
```

### Hebrew Narration (edge-tts)

```powershell
# Hebrew female — for parent-facing content
edge-tts --voice "he-IL-HilaNeural" --rate "+0%" `
    --text "ברוכים הבאים לסקוואד לילדים!" `
    --write-media narration-he.mp3

# Hebrew male
edge-tts --voice "he-IL-AvriNeural" --rate "+0%" `
    --text "ברוכים הבאים לסקוואד לילדים!" `
    --write-media narration-he-male.mp3
```

### Arabic Narration (edge-tts)

```powershell
# Arabic female — for multi-language demo
edge-tts --voice "ar-SA-ZariyahNeural" --rate "+0%" `
    --text "مرحبا بكم في سكواد للأطفال!" `
    --write-media narration-ar.mp3
```

### Batch Generation Script

```powershell
# Generate all narrations from script file
# Format: one line per segment, pipe-separated: segment_id|text
Get-Content narration-segments.txt | ForEach-Object {
    $parts = $_ -split '\|'
    $id = $parts[0]
    $text = $parts[1]
    edge-tts --voice "en-US-JennyNeural" --rate "+5%" `
        --text "$text" `
        --write-media "output/narration-${id}.mp3"
}
```

---

## Post-Processing Steps

### 1. Remux MKV → MP4

```powershell
# Lossless remux (instant, no re-encoding)
ffmpeg -i recording.mkv -c copy output.mp4
```

### 2. Trim Start/End

```powershell
# Trim from 00:03 to 04:30 (skip first 3 seconds of fumbling)
ffmpeg -i output.mp4 -ss 00:00:03 -to 00:04:30 -c copy trimmed.mp4
```

### 3. Speed Up Slow Sections

```powershell
# 2x speed for "waiting" sections (re-encodes)
ffmpeg -i slow-section.mp4 -filter:v "setpts=0.5*PTS" -filter:a "atempo=2.0" fast.mp4
```

### 4. Add Narration Track

```powershell
# Overlay narration on screen recording
ffmpeg -i trimmed.mp4 -i narration.mp3 `
    -filter_complex "[0:a][1:a]amix=inputs=2:duration=longest" `
    -c:v copy final.mp4
```

### 5. Add Title Card (3 seconds)

```powershell
# Create title card image first, then:
ffmpeg -loop 1 -t 3 -i title-card.png -i final.mp4 `
    -filter_complex "[0:v][1:v]concat=n=2:v=1:a=0" `
    with-title.mp4
```

### 6. Generate Thumbnail

```powershell
# Extract a frame at the "money shot" moment
ffmpeg -i final.mp4 -ss 00:01:30 -vframes 1 thumbnail.png
```

### 7. Compress for Web

```powershell
# Web-optimized MP4 (good quality, smaller file)
ffmpeg -i final.mp4 -c:v libx264 -preset slow -crf 22 `
    -c:a aac -b:a 128k -movflags +faststart `
    web-ready.mp4

# WebM alternative (smaller, browser-native)
ffmpeg -i final.mp4 -c:v libvpx-vp9 -crf 30 -b:v 0 `
    -c:a libopus -b:a 128k `
    web-ready.webm
```

---

## Pre-Recording Checklist (do this every session)

- [ ] Close all unnecessary apps (Slack, Teams, email)
- [ ] Enable Focus Assist → Alarms Only
- [ ] Check terminal font size (16pt minimum)
- [ ] Set simplified prompt: `function prompt { "squad-for-kids> " }`
- [ ] Run `demos/reset-demo.ps1` for clean state
- [ ] Verify Copilot CLI is working: `copilot --version`
- [ ] Start OBS, verify capture source shows terminal
- [ ] Check audio levels if recording live narration
- [ ] Have the script open on a second monitor (or printed)
- [ ] Do a 10-second test recording and review

## Post-Recording Checklist (after each video)

- [ ] Stop OBS recording
- [ ] Remux MKV → MP4
- [ ] Trim dead air from start/end
- [ ] Speed up any waiting sections (>5 seconds of no change)
- [ ] Generate TTS narration if not recording live
- [ ] Mix narration with screen recording
- [ ] Add title card and end card
- [ ] Generate thumbnail
- [ ] Compress for web (MP4 + WebM)
- [ ] Update status in [README.md](README.md)
- [ ] Push output to `demos/output/video/`

---

## File Naming Convention

```
squad-kids-{nn}-{slug}-{lang}.{ext}

Examples:
squad-kids-01-fork-and-setup-en.mp4
squad-kids-01-fork-and-setup-he.mp4
squad-kids-09-onboarding-en.mp4
squad-kids-11-homework-helper-en.webm
```

## Output Directory Structure

```
demos/output/video/
├── 01-fork-and-setup/
│   ├── squad-kids-01-fork-and-setup-en.mp4
│   ├── squad-kids-01-fork-and-setup-he.mp4
│   └── thumbnail.png
├── 02-ralph-watch/
│   ├── squad-kids-02-ralph-watch-en.mp4
│   └── ...
└── narration/
    ├── 01-fork-and-setup-en.mp3
    ├── 01-fork-and-setup-he.mp3
    └── ...
```
