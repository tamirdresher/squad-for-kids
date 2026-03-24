# 🔴 VIDEO QUALITY AUDIT — Squad for Kids (`docs/`)

**Auditor:** Q (Devil's Advocate & Fact Checker)
**Date:** 2025-07-25
**Scope:** All 23 `.mp4` files in `C:\temp\squad-for-kids\docs\`
**Method:** ffprobe metadata · ffmpeg volumedetect · frame extraction at 25%/50%/75% · MD5 hash comparison · visual inspection of every extracted frame

---

## Executive Summary

| Metric | Count |
|--------|-------|
| **Total videos** | 23 |
| **❌ BROKEN — must fix before any public use** | 5 |
| **⚠️ NEEDS ATTENTION — misleading or degraded** | 3 |
| **✅ ACCEPTABLE** | 15 |
| **Total wasted disk space (broken videos)** | ~23.4 MB |

> **Bottom line:** Nearly **22% of all videos are broken** — they show raw desktops, ffmpeg terminal output, or have silent audio. Another 13% are deceptive duplicates. **No one has watched these videos before shipping them.** This is a quality control failure.

---

## 🔴 CRITICAL FINDINGS

### Finding #1: Wrong-Capture Videos (Desktop/Terminal Recordings)

Three videos recorded the **encoding process or bare desktop** instead of actual product demos:

| Video | Duration | What It Actually Shows | Verdict |
|-------|----------|----------------------|---------|
| `demo-onboarding-en.mp4` | 2:45 | ffmpeg terminal encoding output + Chrome "Restore pages?" dialog | ❌ **UNUSABLE** |
| `demo-onboarding-he.mp4` | 2:45 | Identical to onboarding-en (same frames, proven by MD5) | ❌ **UNUSABLE** |
| `demo-frozen-real-he.mp4` | 1:48 | Raw desktop with terminal/CLI running ffmpeg encoding commands | ❌ **UNUSABLE** |
| `demo-minecraft-real-he.mp4` | 3:23 | Bare Windows desktop with Lenovo corporate wallpaper — no Minecraft content whatsoever | ❌ **UNUSABLE** |

**Root cause:** Screen recording was started, the operator began an ffmpeg encode or didn't navigate to the correct window, and the resulting capture was committed without review.

**Evidence:** Frame hashes for `demo-onboarding-en` and `demo-onboarding-he` are byte-identical at 25%, 50%, and 75% marks — confirming they're the same wrong recording with localized audio slapped on top of garbage video.

### Finding #2: Silent Audio Track

| Video | Mean Volume | Max Volume | Normal Range |
|-------|------------|------------|--------------|
| `sample-parent-hebrew.mp4` | **-52.4 dB** | **-25.6 dB** | -20 to -23 dB |

At -52 dB mean, this audio track is **functionally silent**. A user would hear nothing. The audio stream exists (AAC codec present) but contains near-silence. This is not a "quiet narration" — it's 30 dB below the quietest acceptable video in the set.

### Finding #3: Three "Different" Videos Are the Same Video

MD5 hash comparison at 25%, 50%, and 75% proves these three files have **pixel-identical video frames**:

| Video | File Size | Audio Level | MD5 @ 50% |
|-------|-----------|-------------|-----------|
| `sample-developer-english.mp4` | 3.36 MB | -20.7 dB (OK) | `5CA57B1B8820534A6E1E7AC9A2052C60` |
| `sample-parent-hebrew.mp4` | 2.13 MB | **-52.4 dB (SILENT)** | `5CA57B1B8820534A6E1E7AC9A2052C60` |
| `sample-teacher-english.mp4` | 3.02 MB | -21.7 dB (OK) | `5CA57B1B8820534A6E1E7AC9A2052C60` |

They differ only in their audio track. The filenames suggest three different audience-specific demos (developer, parent, teacher). In reality: **one VS Code screen recording of a Hebrew game-building Copilot session, with three audio dubs.** The "parent" version got a silent/broken audio track.

**Implication:** If these are shown to parents, teachers, and developers as "personalized demos," users will notice they're watching the exact same screen. The names are deceptive.

---

## Per-Video Audit Detail

### ❌ BROKEN — Must Fix

| # | File | Duration | Size | Audio | Visual Content | Issue |
|---|------|----------|------|-------|---------------|-------|
| 1 | `demo-onboarding-en.mp4` | 2:45 | 4.53 MB | -21.2 dB | ffmpeg terminal + Chrome restore dialog | **Wrong capture** — recorded encoding process |
| 2 | `demo-onboarding-he.mp4` | 2:45 | 4.48 MB | -20.0 dB | Identical to onboarding-en | **Wrong capture** + duplicate of broken EN version |
| 3 | `demo-frozen-real-he.mp4` | 1:48 | 4.61 MB | -22.0 dB | Desktop with ffmpeg CLI commands | **Wrong capture** — recorded terminal |
| 4 | `demo-minecraft-real-he.mp4` | 3:23 | 7.67 MB | -23.5 dB | Bare Lenovo desktop wallpaper | **Wrong capture** — no Minecraft content |
| 5 | `sample-parent-hebrew.mp4` | 2:13 | 2.13 MB | **-52.4 dB** | VS Code (same as developer/teacher) | **Silent audio** + misleading duplicate |

### ⚠️ Needs Attention

| # | File | Duration | Size | Audio | Visual Content | Issue |
|---|------|----------|------|-------|---------------|-------|
| 6 | `sample-developer-english.mp4` | 2:13 | 3.36 MB | -20.7 dB | VS Code Copilot Chat — Hebrew game conversation | **Misleading name** — identical video to teacher/parent versions |
| 7 | `sample-teacher-english.mp4` | 2:13 | 3.02 MB | -21.7 dB | VS Code Copilot Chat — same Hebrew game conversation | **Misleading name** — identical video to developer/parent versions |
| 8 | `tutorial-video-he.mp4` | 2:05 | 6.55 MB | -22.7 dB | CLI terminal with MCP server connection errors + Copilot CLI | **Shows error messages** — may be intentional tutorial but looks broken to viewer |

### ✅ Acceptable

| # | File | Duration | Size | Audio (Mean) | Visual Content | Style | Notes |
|---|------|----------|------|-------------|---------------|-------|-------|
| 9 | `demo-boy-en.mp4` | 1:00 | 0.64 MB | -30.6 dB | Blue slides — Star Wars gamification + game screenshot | Slideshow | Quiet audio; OK for auto-play |
| 10 | `demo-boy-he.mp4` | 0:45 | 0.62 MB | -30.7 dB | Blue slides — Hebrew gamification + game completion | Slideshow | Quiet audio; OK for auto-play |
| 11 | `demo-girl-en.mp4` | 1:00 | 0.64 MB | -32.1 dB | Purple slides — "Earns house points at Hogwarts" | Slideshow | Quiet audio; OK for auto-play |
| 12 | `demo-girl-he.mp4` | 0:45 | 0.61 MB | -30.7 dB | Light blue slides — Hebrew ice palace theme | Slideshow | Quiet audio; OK for auto-play |
| 13 | `demo-quick-en.mp4` | 0:52 | 0.95 MB | -31.3 dB | Composite: curriculum text overlay + VS Code Copilot below | Hybrid | Good layout; quiet narration |
| 14 | `demo-quick-he.mp4` | 0:55 | 0.97 MB | -30.5 dB | Composite: Hebrew title overlay + VS Code below | Hybrid | Good layout; quiet narration |
| 15 | `demo-social-30s.mp4` | 0:23 | 0.31 MB | -30.7 dB | Colorful marketing slides | Marketing clip | Short teaser; works as social media content |
| 16 | `demo-video-en.mp4` | 2:45 | 4.26 MB | -22.2 dB | VS Code Copilot — "Homework help for 11-year-old" | Screen recording | ✅ Legitimate product demo |
| 17 | `demo-video-he.mp4` | 2:55 | 3.64 MB | -21.2 dB | VS Code with Hebrew homework conversation | Screen recording | ✅ Legitimate product demo |
| 18 | `exam-prep-he.mp4` | 0:24 | 0.22 MB | -30.9 dB | Purple slide — "Gets customized learning schedule" (HE) | Feature highlight | Very short; text-only slide |
| 19 | `gamification-he.mp4` | 0:24 | 0.26 MB | -31.3 dB | Blue slide — "Levels up and unlocks achievements" (HE) | Feature highlight | Very short; text-only slide |
| 20 | `homework-helper-he.mp4` | 0:24 | 0.24 MB | -30.5 dB | Blue slide — "Teacher explains step by step" (HE) | Feature highlight | Very short; text-only slide |
| 21 | `parent-report-he.mp4` | 0:24 | 0.21 MB | -31.3 dB | Teal/green slide — "How much time invested" (HE) | Feature highlight | Very short; text-only slide |
| 22 | `safety-he.mp4` | 0:24 | 0.25 MB | -30.8 dB | Blue slide — "Routing gently to inappropriate topics" (HE) | Feature highlight | Very short; text-only slide |
| 23 | `sample-teaser-30s.mp4` | 0:30 | 0.88 MB | -21.8 dB | Colorful marketing presentation | Marketing clip | Good audio; punchy teaser |

---

## Duplicate Video Map

```
GROUP A — Identical video frames (different audio only):
  ├── sample-developer-english.mp4  (3.36 MB, good audio)
  ├── sample-teacher-english.mp4    (3.02 MB, good audio)
  └── sample-parent-hebrew.mp4      (2.13 MB, ❌ SILENT audio)

GROUP B — Identical video frames (different audio only):
  ├── demo-onboarding-en.mp4        (4.53 MB, ❌ WRONG CAPTURE)
  └── demo-onboarding-he.mp4        (4.48 MB, ❌ WRONG CAPTURE)
```

---

## Audio Level Distribution

```
LOUD  ─20 dB ┤████████████ demo-onboarding-he (-20.0)
             ┤████████████ sample-developer-english (-20.7)
             ┤████████████ demo-onboarding-en (-21.2)
             ┤████████████ demo-video-he (-21.2)
             ┤████████████ sample-teacher-english (-21.7)
             ┤████████████ sample-teaser-30s (-21.8)
NORMAL       ┤████████████ demo-frozen-real-he (-22.0)
      ─23 dB ┤████████████ demo-video-en (-22.2)
             ┤████████████ tutorial-video-he (-22.7)
             ┤████████████ demo-minecraft-real-he (-23.5)
             ┤
QUIET ─30 dB ┤██████ demo-quick-he (-30.5)
             ┤██████ homework-helper-he (-30.5)
             ┤██████ demo-boy-en (-30.6)
             ┤██████ demo-boy-he, demo-girl-he, demo-social-30s (-30.7)
             ┤██████ safety-he (-30.8)
             ┤██████ exam-prep-he (-30.9)
             ┤██████ demo-quick-en, gamification-he, parent-report-he (-31.3)
             ┤██████ demo-girl-en (-32.1)
             ┤
SILENT─52 dB ┤▏ sample-parent-hebrew (-52.4) ← ❌ BROKEN
```

**Observation:** There's a clear two-tier split. Screen recordings with voiceover sit around -20 to -23 dB (normal). Slideshow/presentation videos with background music/TTS narration sit at -30 to -32 dB (10 dB quieter — noticeable volume difference when switching between video types on a website).

---

## Technical Consistency

| Property | Value | All 23 match? |
|----------|-------|--------------|
| Resolution | 1280×720 | ✅ Yes |
| Video codec | H.264 | ✅ Yes |
| Audio codec | AAC | ✅ Yes |
| Audio stream present | Yes | ✅ Yes |
| Container | MP4 | ✅ Yes |

No resolution mismatches, codec inconsistencies, or missing audio streams. The technical encoding is uniform. The problems are all **content-level**, not encoding-level.

---

## 🔨 Recommended Actions

### Immediate — Block Shipping

| Priority | Action | Videos Affected |
|----------|--------|----------------|
| **P0** | **DELETE or REPLACE** — These show raw desktops/terminals and are embarrassing if seen by users | `demo-onboarding-en.mp4`, `demo-onboarding-he.mp4` |
| **P0** | **DELETE or REPLACE** — Bare desktop wallpaper, zero product content | `demo-minecraft-real-he.mp4` |
| **P0** | **DELETE or REPLACE** — Terminal encoding capture, not a Frozen demo | `demo-frozen-real-he.mp4` |
| **P0** | **RE-RECORD AUDIO or DELETE** — Silent audio makes this useless | `sample-parent-hebrew.mp4` |

### Short-term — Before Public Launch

| Priority | Action | Videos Affected |
|----------|--------|----------------|
| **P1** | **Re-record unique content** for each audience (dev/parent/teacher) or rename honestly (e.g., `sample-copilot-demo.mp4`) | `sample-developer-english.mp4`, `sample-teacher-english.mp4`, `sample-parent-hebrew.mp4` |
| **P1** | **Review tutorial content** — currently shows MCP connection errors, verify this is intentional | `tutorial-video-he.mp4` |
| **P2** | **Normalize audio levels** — 10 dB gap between screen recordings (-21 dB) and slideshows (-31 dB) will cause jarring volume changes on a website | All slideshow videos |

### Nice-to-have

| Priority | Action | Videos Affected |
|----------|--------|----------------|
| **P3** | Add English versions of feature highlight videos (currently Hebrew-only) | `exam-prep-he`, `gamification-he`, `homework-helper-he`, `parent-report-he`, `safety-he` |
| **P3** | Add English version of tutorial | `tutorial-video-he` |

---

## Video Style Classification

| Style | Count | Videos |
|-------|-------|--------|
| **Screen recording** (VS Code / Copilot demo) | 5 | demo-video-en/he, sample-developer-english, sample-teacher-english, tutorial-video-he |
| **Slideshow/presentation** (text on colored background) | 12 | demo-boy-en/he, demo-girl-en/he, demo-quick-en/he, demo-social-30s, exam-prep-he, gamification-he, homework-helper-he, parent-report-he, safety-he |
| **Marketing teaser** | 1 | sample-teaser-30s |
| **Wrong capture (garbage)** | 4 | demo-onboarding-en/he, demo-frozen-real-he, demo-minecraft-real-he |
| **Silent/broken** | 1 | sample-parent-hebrew |

---

## Process Recommendations

1. **Add a video review gate** — No video should be committed to `docs/` without at least one human watching it end-to-end. The 4 wrong-capture videos prove nobody watched them.

2. **Automate audio sanity checks** — A CI check that runs `ffmpeg -af volumedetect` and fails if mean_volume < -40 dB would have caught the silent `sample-parent-hebrew` instantly.

3. **Hash-check for duplicate video tracks** — The three "audience-specific" samples being identical video is misleading. Either make them genuinely different or don't pretend they are.

4. **Normalize audio in post** — Run `ffmpeg -af loudnorm=I=-23:TP=-1.5` on all videos to bring them to consistent broadcast-standard levels before shipping.

---

*Audit complete. 69 frames extracted, 23 videos probed, 0 mercy shown.*
