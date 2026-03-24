# YouTube Thumbnail Design System
## TechAI Explained — Visual Design Standard

**Issue:** [#812 — Thumbnail Generation & Visual Design System](../../issues/812)  
**Status:** Draft v1.0  
**Owner:** Visual Production (@paris), Growth/CTR (@geordi)  
**Brand Authority:** Decision #32 — Content Production Rules (MANDATORY)  
**Last Updated:** 2026-03-24

---

## Table of Contents

1. [Technical Specifications](#1-technical-specifications)
2. [Brand Identity](#2-brand-identity)
3. [Template Variants](#3-template-variants)
   - [T1: Breaking News](#t1-breaking-news)
   - [T2: Tutorial / How-To](#t2-tutorial--how-to)
   - [T3: Interview / Opinion](#t3-interview--opinion)
   - [T4: Tool Review](#t4-tool-review)
   - [T5: Weekly Digest](#t5-weekly-digest)
4. [RTL Adaptation Guide (Hebrew)](#4-rtl-adaptation-guide-hebrew)
5. [Localization Matrix](#5-localization-matrix)
6. [AI Image Prompt Templates](#6-ai-image-prompt-templates)
7. [A/B Testing Strategy](#7-ab-testing-strategy)
8. [Canva / Figma Checklist](#8-canva--figma-checklist)
9. [Automation Notes](#9-automation-notes)

---

## 1. Technical Specifications

### Canvas Dimensions

| Property | Value |
|----------|-------|
| Width | 1280 px |
| Height | 720 px |
| Aspect Ratio | 16:9 |
| Resolution (export) | 72 dpi (screen) |
| File Format | PNG (lossless), JPG < 2 MB for upload |
| Color Mode | RGB |

### Safe Zones

YouTube overlays UI elements (channel name, watch-later icon, timestamp) on corners and bottom edge. All **critical content** must remain inside the safe zone.

```
┌──────────────────────────────────────┐  ← 1280 px
│  [40px margin — outer bleed zone]   │
│  ┌────────────────────────────────┐  │  ← Row 40 px
│  │                                │  │
│  │        SAFE ZONE               │  │
│  │      1200 × 640 px             │  │
│  │  (centered, 40px padding all)  │  │
│  │                                │  │
│  │                                │  │
│  └────────────────────────────────┘  │  ← Row 680 px
│  [40px bottom margin — timestamp]   │
└──────────────────────────────────────┘  ← 720 px
```

- **Outer bleed zone (40 px all sides):** Background only — no text, no logos
- **Safe zone:** 1200 × 640 px — all text, logos, key visuals
- **Bottom-right 200 × 60 px:** Reserved — YouTube places timestamp here
- **Top-left 300 × 60 px:** Reserved — YouTube places channel branding here (mobile)

### Text Size Guidelines

| Element | Min Size | Recommended | Max Size | Notes |
|---------|----------|-------------|----------|-------|
| Primary headline | 72 px | 88–96 px | 120 px | Bold/Black weight |
| Secondary headline | 40 px | 48 px | 64 px | Semi-Bold |
| Label / tag | 24 px | 28 px | 36 px | Caps, letter-spaced |
| Eyebrow text | 18 px | 22 px | 28 px | Avoid if < 22 px |

**Rule:** Thumbnails are viewed at ~168 × 94 px in mobile feeds. Test legibility at 15% scale before finalizing.

### Composition Grid

Use a **rule-of-thirds** grid. Place the primary focal element (face, product, icon) at a thirds intersection. Text block occupies no more than 40% of canvas width.

---

## 2. Brand Identity

> **Decision #32 is MANDATORY.** Never use personal names. Brand name is **"TechAI Explained"** only.

### Color Palette

| Name | HEX | Usage |
|------|-----|-------|
| Deep Navy | `#0a0a2e` | Primary background |
| Electric Cyan | `#00d4ff` | Headlines, highlights, glow effects |
| Magenta | `#ff006e` | Alerts, breaking news accent, urgent CTAs |
| Gold | `#ffd700` | Verdicts, star ratings, premium emphasis |
| Off-White | `#f0f0f0` | Body text on dark backgrounds |
| Dark Overlay | `rgba(10,10,46,0.75)` | Text-protection scrim over images |

### Typography

| Role | Font | Weight | Style |
|------|------|--------|-------|
| Display / Headline | Inter | Black (900) | Uppercase or Title Case |
| Sub-headline | Inter | Bold (700) | Title Case |
| Label / Tag | Inter | SemiBold (600) | ALL CAPS, +1.5 letter-spacing |
| Code / technical | JetBrains Mono | Regular or Bold | As-is |

**Fallback stack:** `"Inter", "Helvetica Neue", Arial, sans-serif`

### Logo

- Use **"TechAI Explained"** wordmark (horizontal variant) at bottom-left safe zone edge
- Minimum size: 120 px wide
- Clear space: 1× logo height on all sides
- On light backgrounds: use dark variant
- On dark/image backgrounds: use white/cyan variant

### Visual Style

- **Mood:** Technical authority meets accessible energy — not corporate grey, not screaming clickbait
- **Background treatment:** Dark sci-fi / deep space aesthetic (consistent with blog hero art)
- **Lighting:** Dramatic directional light, neon glow accents (cyan/magenta rim lighting on subjects)
- **Textures:** Subtle grid/circuit overlays, particle/node effects — keep at < 15% opacity

---

## 3. Template Variants

---

### T1: Breaking News

**Use case:** New AI model release, major industry announcement, regulatory development, outage/incident.

**Visual Language:** Urgency, importance, NOW.

#### Layout Description (Canva / Figma)

```
┌─────────────────────────────────────────────┐
│  [BACKGROUND: Dark navy, subtle scan lines] │
│                                             │
│  ┌──────────────────────────────┐  [icon]  │
│  │ ⚡ BREAKING                 │   60×60  │
│  │ [Magenta pill label, 28 px] │          │
│  └──────────────────────────────┘          │
│                                             │
│  [HEADLINE — 2 lines max]                  │
│  GPT-6 Just                                │
│  Changed Everything                        │
│  [Inter Black, 88 px, Off-White]           │
│                                             │
│  [Sub-head — 1 line]                       │
│  What it means for developers              │
│  [Inter SemiBold, 40 px, Cyan]             │
│                                             │
│  [Bottom bar — Magenta 4px stroke]         │
│  [TechAI Explained logo — bottom-left]     │
└─────────────────────────────────────────────┘
```

**Composition notes:**
- Full-bleed dark background (Deep Navy gradient with subtle scan-line texture at 8% opacity)
- Magenta `⚡ BREAKING` pill label: rounded rect (8px radius), Magenta fill, white text, 28px Inter SemiBold CAPS
- Optional: **Red urgency bar** (4px) running full width at top edge
- Headline: Left-aligned, two lines max, Inter Black 88 px, Off-White
- Sub-headline: Left-aligned, Cyan, 40px SemiBold
- Right 30% of canvas: abstract glow/spark effect (Magenta/Cyan, low opacity) for visual interest
- Logo: bottom-left, white variant, 120px wide

**Accent color override:** Use Magenta (`#ff006e`) for primary accent (not Cyan) to signal urgency.

**AI Background Prompt:**
See [Section 6, Prompt T1](#prompt-t1-breaking-news).

---

### T2: Tutorial / How-To

**Use case:** Step-by-step guides, code walkthroughs, setup tutorials, Kubernetes/Docker/DevOps how-tos.

**Visual Language:** Clarity, competence, I-can-do-this.

#### Layout Description

```
┌─────────────────────────────────────────────┐
│  [BACKGROUND: Code screenshot, dark-tinted] │
│  [Overlay: Dark Navy at 70% opacity]        │
│                                             │
│  [Tag — top-left, Cyan outline pill]        │
│  TUTORIAL                                   │
│                                             │
│  [Step count — large, right side]           │
│  ┌────┐                                     │
│  │ 3  │  ← Gold, 120 px, Inter Black        │
│  │STEPS│  ← Inter SemiBold, 28 px           │
│  └────┘                                     │
│                                             │
│  [HEADLINE]                                 │
│  Deploy to Kubernetes                       │
│  in 10 Minutes                              │
│  [Inter Black, 80 px, Off-White]            │
│                                             │
│  [Bottom row: terminal icon + sub-text]     │
│  ⌨️  kubectl apply -f deploy.yaml           │
│  [JetBrains Mono, 24 px, Cyan]              │
│                                             │
│  [TechAI Explained logo — bottom-left]      │
└─────────────────────────────────────────────┘
```

**Composition notes:**
- Background: actual terminal/code screenshot (blurred 4px) with Deep Navy overlay at 70%
- Top-left: `TUTORIAL` pill — Cyan outline (2px stroke), transparent fill, Cyan text
- Right panel (30% width): large step-count number in Gold, bold — serves as visual anchor
- Headline: Left-aligned, 2 lines max, Inter Black 80px, Off-White
- Code snippet line at bottom: JetBrains Mono 24px, Cyan — gives technical credibility
- Optional horizontal divider: 1px Cyan line between headline and code

**Accent color:** Gold (`#ffd700`) for step count, Cyan for labels and code.

**AI Background Prompt:**
See [Section 6, Prompt T2](#prompt-t2-tutorial--how-to).

---

### T3: Interview / Opinion

**Use case:** Recorded conversations, solo opinion takes, "hot takes", debate-format content.

**Visual Language:** Authority, personality, conversation.

#### Layout Description

```
┌─────────────────────────────────────────────┐
│  [LEFT 40%: Subject photo / avatar]         │
│  [Neon rim-light: Cyan left, Magenta right] │
│                                             │
│  [RIGHT 60%: Text block]                    │
│                                             │
│  [Eyebrow — Cyan, 22 px CAPS]              │
│  HOT TAKE                                   │
│                                             │
│  [HEADLINE — quote or bold claim]           │
│  AI Will Replace                            │
│  Junior Devs                                │
│  By 2026                                    │
│  [Inter Black, 72 px, Off-White]            │
│                                             │
│  [Attribution]                              │
│  "Here's why I agree"                       │
│  [Inter Bold, 32 px, Gold]                  │
│                                             │
│  [TechAI Explained logo — bottom-left]      │
└─────────────────────────────────────────────┘
```

**Composition notes:**
- Left panel (40%): subject photo with aggressive crop at shoulders; no background (cut-out or gradient fade)
- Rim lighting: Cyan (#00d4ff) glow from left, Magenta (#ff006e) glow from right — creates drama
- Right panel background: Deep Navy with diagonal grid texture at 6% opacity
- Optional vertical Cyan divider line between panels
- Eyebrow: ALL CAPS, Cyan, 22 px, 2px letter spacing — sets the frame (HOT TAKE / MY OPINION / DEBATE)
- Headline: 3 lines max, Inter Black, 72 px — bold declarative statement
- Attribution: Gold, 32 px bold — a conversational hook

**Note for brand safety:** No personal names. If using a face, use AI-generated avatar or tech-themed abstract face. See Decision #32.

**AI Background Prompt:**
See [Section 6, Prompt T3](#prompt-t3-interview--opinion).

---

### T4: Tool Review

**Use case:** Product deep-dives, comparisons, "Is it worth it?" evaluations, sponsored reviews.

**Visual Language:** Evaluation, authority, verdict.

#### Layout Description

```
┌─────────────────────────────────────────────┐
│  [BACKGROUND: Product logo, large, center]  │
│  [Overlay: Dark Navy at 55%, vignette]      │
│                                             │
│  [TOP CENTER: Tag pill]                     │
│  ⭐ TOOL REVIEW                             │
│  [Gold fill, Navy text, 28 px SemiBold]     │
│                                             │
│  [CENTER: Product name]                     │
│  GitHub Copilot                             │
│  [Inter Bold, 64 px, Cyan]                  │
│                                             │
│  [Verdict badge — bottom-center]            │
│  ┌────────────────┐                         │
│  │  ✅ MUST-HAVE  │  Gold border, Cyan bg  │
│  └────────────────┘                         │
│  [or: ⚠️ OVERHYPED  /  ❌ SKIP IT]          │
│                                             │
│  [Score bar: 5 stars, Gold, 36 px]          │
│  ★★★★☆  4.2 / 5                             │
│                                             │
│  [TechAI Explained logo — bottom-left]      │
└─────────────────────────────────────────────┘
```

**Composition notes:**
- Background: product logo at 200–250px, centered/right-of-center, heavily overlaid
- If no brand logo available: use product UI screenshot with heavy Dark Overlay
- Top-center tag: Gold pill (`TOOL REVIEW` / `VS BATTLE` / `IS IT WORTH IT?`)
- Product name: Cyan, Inter Bold 64px, center-aligned
- Verdict badge: High-contrast pill — color-coded by verdict:
  - ✅ MUST-HAVE: Cyan background, Gold border
  - ⚠️ OVERHYPED: Gold background, Navy border
  - ❌ SKIP IT: Magenta background, white border
- Star rating: 5 stars in Gold, Inter Black 36px
- Optional: split-screen variant for comparisons (Tool A vs Tool B, divider line)

**AI Background Prompt:**
See [Section 6, Prompt T4](#prompt-t4-tool-review).

---

### T5: Weekly Digest

**Use case:** "This Week in AI" roundups, weekly news summaries, 5-links digest.

**Visual Language:** Organized, comprehensive, trustworthy newsroom.

#### Layout Description

```
┌─────────────────────────────────────────────┐
│  [BACKGROUND: Deep Navy grid/particle]      │
│                                             │
│  [TOP: Banner bar]                          │
│  📰 THIS WEEK IN AI    [date: Mar 24, 2026] │
│  [Cyan text, Gold date, full-width bar]     │
│                                             │
│  [CENTER GRID: 3 item tiles]                │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐    │
│  │  GPT-6   │ │  K8s 1.3 │ │  Cursor  │    │
│  │ released │ │   EOL    │ │  vs CoPlt│    │
│  └──────────┘ └──────────┘ └──────────┘    │
│  [Each tile: icon + 2-line text, 24 px]     │
│                                             │
│  [MAIN HEADLINE below grid]                 │
│  5 Things That Mattered                     │
│  This Week                                  │
│  [Inter Black, 64 px, Off-White]            │
│                                             │
│  [TechAI Explained logo — bottom-left]      │
│  [Issue number — bottom-right, Gold]        │
│  #42                                        │
└─────────────────────────────────────────────┘
```

**Composition notes:**
- Top banner: full-width Cyan bar, `📰 THIS WEEK IN AI` in Deep Navy text (Inter Black 32 px), date in Gold right-aligned
- Center grid: 3 tiles (equal width), each with a simple icon (emoji or thin-stroke icon), topic title in white (Inter SemiBold 22 px), 2-line description in light gray (18 px)
- Tile borders: 1px Cyan stroke, 6px border-radius, Deep Navy fill
- Below grid: primary headline, left-aligned, 2 lines
- Issue number (bottom-right): Gold, large (#42 style) — builds episode identity
- Optional 4th "and more…" tile with `+12 more stories` in Cyan italic

---

## 4. RTL Adaptation Guide (Hebrew)

All Hebrew (`he`) thumbnails must be full RTL mirrors. This is not just text alignment — it is a complete layout reversal.

### Core RTL Rules

| Element | LTR (EN/ES/FR) | RTL (HE) |
|---------|---------------|----------|
| Text alignment | Left | Right |
| Logo position | Bottom-left | Bottom-right |
| Image/face position | Left panel | Right panel |
| Reading flow | Left → Right | Right → Left |
| Icon before text | Icon on left | Icon on right |
| Progress bars | Fill left → right | Fill right → left |

### Hebrew Typography

| Role | Font | Notes |
|------|------|-------|
| Headline (HE) | Noto Sans Hebrew | Bold/Black weight (700/900) |
| Body (HE) | Noto Sans Hebrew | Regular (400) |
| Code (HE labels) | JetBrains Mono | Code stays LTR even in RTL layout |
| Fallback | Assistant (Hebrew), David | Both available on Google Fonts |

**Key:** `Noto Sans Hebrew` renders all Hebrew weights and supports nikud (vowel marks) — required for accessibility and natural reading.

### Canvas Mirroring Checklist (per template)

```
✅ Flip entire composition horizontally in design tool
✅ Re-position logo: bottom-LEFT → bottom-RIGHT
✅ Re-align all text: text-align: right (or start)
✅ Move image/face from left panel to right panel
✅ Check directional arrows/icons — flip if directional
✅ Ensure pill/badge text reads RTL
✅ Code snippets remain LTR (use dir="ltr" wrapper if HTML)
✅ Number order (dates, scores) remains standard Western numerals
✅ Test at 15% scale — Hebrew glyphs can be dense, verify legibility
```

### Hebrew Font Sizes

Hebrew characters are slightly taller and denser than Latin. Reduce font sizes by ~10% vs Latin equivalents:

| Latin size | Hebrew size |
|------------|-------------|
| 88 px | 80 px |
| 72 px | 64 px |
| 40 px | 36 px |
| 28 px | 26 px |

### Cultural Considerations (Hebrew Market)

- **Color meaning:** No specific color taboos for HE market in tech content
- **Date format:** DD/MM/YYYY (not MM/DD)
- **Number format:** Standard Western numerals (1, 2, 3) — not Hebrew numerals (used in religious contexts)
- **Tone:** Israeli tech audience responds to direct, no-hype communication — avoid excessive exclamation marks

---

## 5. Localization Matrix

| Language | Direction | Font | Date Format | Headline Length | Notes |
|----------|-----------|------|-------------|-----------------|-------|
| English (EN) | LTR | Inter | MM/DD/YYYY | Up to 40 chars | Default template |
| Hebrew (HE) | RTL | Noto Sans Hebrew | DD/MM/YYYY | Up to 32 chars (Hebrew is compact) | Full layout mirror |
| Spanish (ES) | LTR | Inter | DD/MM/YYYY | Up to 44 chars (Spanish can be verbose) | Same template as EN |
| French (FR) | LTR | Inter | DD/MM/YYYY | Up to 42 chars | Watch for accented chars: é, ê, à, ç |

### Per-Language Brand Name

| Language | Brand Name |
|----------|-----------|
| EN | TechAI Explained |
| HE | TechAI מוסבר (TechAI Mevoar) |
| ES | TechAI Explicado |
| FR | TechAI Expliqué |

> **Note:** Keep the English "TechAI" prefix untranslated across all languages for brand recognition. Only translate the descriptor word.

### Text Overflow Strategy

Long translated strings are the #1 thumbnail failure mode. Rules:
1. Write the headline in the shortest language first (usually EN or HE)
2. Test that translated version fits within 2 lines at the specified font size
3. If overflow: reduce font size by 8px, then by another 8px
4. If still overflowing at minimum readable size (see Section 1 table): rewrite the headline — do not shrink below minimum

---

## 6. AI Image Prompt Templates

These prompts generate background/hero images via DALL-E 3, Ideogram, or Imagen. They follow the established visual style from the blog series (established in `blog-part4-image-prompt.txt`).

**Style baseline (prepend to all prompts):**
> Dark cinematic sci-fi digital art. High quality, photorealistic lighting. Deep black/dark navy background (#0a0a2e), electric cyan and neon blue accents, gold/amber highlights, subtle purple nebula tones. No text, no labels, no UI elements, no watermarks. Pure cinematic background art. 16:9 aspect ratio, 1280×720 px.

---

### Prompt T1: Breaking News

**Use for:** T1 Breaking News template background

```
Dark cinematic sci-fi digital art. High quality, photorealistic lighting. 
Deep black/dark navy background, electric cyan and neon blue accents, 
gold/amber highlights, subtle purple nebula tones. No text, no labels, 
no UI elements, no watermarks. Pure cinematic background art. 16:9.

Scene: A massive shockwave rippling outward through a dark digital space — 
representing an information explosion. The wave front glows electric cyan 
and white-hot, with scattered data fragments (abstract hexagons and binary 
particles) flying outward from the center impact point. Red-orange sparks 
at the very center. The background is deep navy with subtle grid lines. 
The feeling is: something important just happened. 
Mood: urgent, dramatic, important.
Color palette: Deep navy background, electric cyan shockwave, 
white-hot center point, red sparks, amber particle fragments.
```

---

### Prompt T2: Tutorial / How-To

**Use for:** T2 Tutorial template background

```
Dark cinematic sci-fi digital art. High quality, photorealistic lighting. 
Deep black/dark navy background, electric cyan and neon blue accents, 
gold/amber highlights. No text, no labels, no UI elements. 16:9.

Scene: A dark command-line terminal aesthetic — glowing green-cyan 
lines of code cascading down the background at a very slight angle 
(Matrix-inspired but subtle, at 6% opacity). In the foreground: 
a single glowing blueprint-style diagram with interconnected nodes — 
representing a deployment topology. Nodes glow soft cyan, connection 
lines pulse with gentle light. The left side of the image is darker 
to allow text overlay. The right side has the blueprint visualization.
Mood: technical competence, clarity, step-by-step mastery.
Color palette: Deep navy, soft cyan node glows, 
faint green-cyan cascading code, amber accent lines on diagram.
```

---

### Prompt T3: Interview / Opinion

**Use for:** T3 Interview/Opinion template background (right panel / atmosphere)

```
Dark cinematic sci-fi digital art. Dramatic, photorealistic lighting. 
Deep black/dark navy background. No text, no labels, no people, 
no faces, no UI elements. 16:9.

Scene: An abstract representation of a single powerful mind — 
a glowing neural network visualization, not anatomical, entirely geometric: 
concentric rings of light nodes connected by pulsing light threads, 
all in deep space. The central node radiates electric cyan light. 
Outer nodes pulse with magenta/purple light. The left 40% of the image 
is darker (for placing a subject cutout). The right 60% has the neural 
network visualization, which fades into darkness at its edges.
Mood: thought leadership, bold perspective, intellectual authority.
Color palette: Deep navy, electric cyan center glow, 
magenta-purple outer nodes, white light threads, dark left side.
```

---

### Prompt T4: Tool Review

**Use for:** T4 Tool Review template background (when no product logo is available)

```
Dark cinematic sci-fi digital art. High quality, photorealistic lighting. 
Deep black/dark navy background. No text, no labels, no logos, 
no UI elements. 16:9.

Scene: A holographic product-display pedestal in empty dark space — 
a sleek floating platform with a soft cyan spotlight from above. 
On the pedestal: a glowing abstract object (a perfect geometric shape, 
neither cube nor sphere but between both — a rounded dodecahedron) 
rotating slowly and emitting a gold aura. 
The background shows faint hexagonal grid lines at 8% opacity. 
The pedestal and platform glow cyan at the edges. 
The scene feels like a premium product unboxing — is this worth it?
Mood: evaluation, premium, judgment.
Color palette: Deep navy, cyan spotlight and platform glow, 
gold aura on central object, faint hex grid.
```

---

### Prompt T5: Weekly Digest (Bonus)

**Use for:** T5 Weekly Digest template background

```
Dark cinematic sci-fi digital art. High quality, photorealistic lighting. 
Deep black/dark navy background. No text, no labels, no UI. 16:9.

Scene: A dark newsroom control panel — an array of glowing screens 
represented abstractly as floating rectangular panels of light 
arranged in a 3-column grid pattern. Each panel has a soft glow 
(cyan, magenta, gold — one color each). Data streams flow between panels 
as thin light lines. The composition is organized, grid-like, 
and suggests "multiple stories, organized and curated."
The panels should be 70% to the right side of the image, 
leaving the left 35% dark for text overlay.
Mood: comprehensive, organized, trustworthy, weekly rhythm.
Color palette: Deep navy, cyan/magenta/gold panel glows, 
white data-stream lines, subtle grid background.
```

---

## 7. A/B Testing Strategy

### Per-Video Test Plan

For each video, produce **2 variants** of the thumbnail before publishing:

| Variant | Description | What to Test |
|---------|-------------|-------------|
| A | Primary template (as specified) | Baseline |
| B | Alternate: change one variable | Headline copy, accent color, or composition |

**Single-variable rule:** Only change ONE element between A and B. Never test multiple variables simultaneously — it makes analysis impossible.

### Variables to Test (Priority Order)

1. **Headline copy** — "Deploy Kubernetes in 10 Min" vs "K8s Setup: The Fast Way"
2. **Accent color** — Cyan vs Magenta for primary highlight
3. **Composition** — Text-dominant vs image-dominant
4. **Curiosity gap** — Full statement vs partial hint ("You Won't Believe What…" — use sparingly)
5. **Number placement** — "3 Steps" on right vs on left

### Per-Market A/B Notes

- EN: Standard A/B, test after 48 hours (enough data)
- HE: Small audience — run for 7 days before reading results
- ES/FR: Test EN variant first; only produce localized variants if EN performs well

### Success Metrics (from issue #812)

| Metric | Target | Red Flag |
|--------|--------|----------|
| CTR (Click-Through Rate) | > 4% | < 2.5% |
| Impressions-to-click | > 1 in 25 | < 1 in 40 |
| A/B lift | > 15% between variants | < 5% |

---

## 8. Canva / Figma Checklist

### Before Creating Any Thumbnail

- [ ] Confirm video title and finalize headline (max 40 chars EN)
- [ ] Identify which template variant applies (T1–T5)
- [ ] Source or generate background image (see Section 6 prompts)
- [ ] Confirm language and direction (LTR or RTL)

### Canva Setup Checklist

- [ ] Canvas: 1280 × 720 px (custom size)
- [ ] Enable rulers and guides; set margins to 40 px all sides (outer safe zone)
- [ ] Add inner guide at: left 40px, right 1240px, top 40px, bottom 680px
- [ ] Upload background image to Canva media library
- [ ] Install fonts: Inter (from Canva font library or upload TTF)
- [ ] For Hebrew: upload Noto Sans Hebrew (if not in Canva library)

### Design Execution Checklist

- [ ] Background layer: image at correct opacity (per template spec)
- [ ] Dark overlay scrim applied (if background has image)
- [ ] All text within safe zone (40 px margin respected)
- [ ] Bottom-right 200 × 60 px region is clear (YouTube timestamp)
- [ ] Top-left 300 × 60 px region is clear (YouTube channel badge, mobile)
- [ ] Headline: correct font (Inter Black), correct size (see Section 1), correct color
- [ ] Sub-headline: correct font, size, color
- [ ] Logo: TechAI Explained wordmark, correct variant (white/dark), bottom-left (bottom-right for HE)
- [ ] Template tag/pill element present and correct
- [ ] For HE: layout fully mirrored (see Section 4 checklist)
- [ ] No personal names anywhere on thumbnail (Decision #32 Rule 1)

### Export Checklist

- [ ] Export as PNG (lossless, best quality for YouTube upload)
- [ ] Verify file size: PNG < 10 MB, JPG < 2 MB
- [ ] Test at thumbnail size: zoom out to 168 × 94 px preview — is headline readable?
- [ ] Test on both light and dark backgrounds (how it looks in different YouTube themes)
- [ ] Name file: `[video-slug]-thumb-[variant]-[lang].png`
  - Example: `gpt6-breaking-thumb-A-en.png`, `k8s-tutorial-thumb-B-he.png`

### Figma Component Notes

When building in Figma, structure components as:
```
📦 TechAI Thumbnail System
 ├── 🎨 Tokens (colors, fonts, spacing)
 ├── 🧱 Components
 │    ├── Pill/Tag (all variants)
 │    ├── Verdict Badge (✅/⚠️/❌)
 │    ├── Logo Block (LTR + RTL)
 │    └── Text Block (LTR + RTL)
 ├── 📄 Templates
 │    ├── T1 Breaking News (EN + HE)
 │    ├── T2 Tutorial (EN + HE)
 │    ├── T3 Interview (EN + HE)
 │    ├── T4 Tool Review (EN + HE)
 │    └── T5 Weekly Digest (EN + HE)
 └── 📋 Examples (5 sample topics, all 4 languages)
```

---

## 9. Automation Notes

> This section feeds the automated thumbnail generation script (planned under issue #812).

### Thumbnail Generation Script Requirements

For AI-automated thumbnail production, the script must:

1. **Accept input:** `topic`, `template_id` (T1–T5), `language` (en/he/es/fr), `headline`, `sub_headline`
2. **Generate background:** Call image generation API with appropriate prompt from Section 6
3. **Compose thumbnail:** Use a headless canvas library (e.g., `sharp` + `canvas` in Node.js, or Pillow in Python) to:
   - Load background image
   - Apply dark overlay scrim
   - Render text at specified positions, fonts, colors
   - Apply RTL layout if language is `he`
   - Stamp logo at correct position
4. **Export:** PNG to output directory, named per convention
5. **A/B variant:** Run twice with two headlines for A/B pair

### Font Loading (Headless)

```js
// Node.js canvas font registration
const { registerFont, createCanvas } = require('canvas');
registerFont('./fonts/Inter-Black.ttf', { family: 'Inter', weight: '900' });
registerFont('./fonts/Inter-Bold.ttf', { family: 'Inter', weight: '700' });
registerFont('./fonts/NotoSansHebrew-Bold.ttf', { family: 'Noto Sans Hebrew', weight: '700' });
registerFont('./fonts/JetBrainsMono-Regular.ttf', { family: 'JetBrains Mono', weight: '400' });
```

### RTL Text Rendering Note

Most headless canvas libraries do not natively handle RTL. Options:
- **Arabic-shaping / bidi algorithm library:** `bidi-js` (npm) for proper bidirectional text
- **Harfbuzz-based:** `harfbuzzjs` for proper Hebrew shaping
- **Simpler fallback:** Pre-render Hebrew text as SVG, flatten to image

### Recommended Stack

| Layer | Tool |
|-------|------|
| Background generation | DALL-E 3 API (`gpt-image-1`) or Imagen 3 (via Vertex AI) |
| Image composition | Python + Pillow, or Node.js + `canvas` |
| Font rendering | Pillow's `ImageDraw` with TTF fonts (better Unicode/RTL than canvas) |
| Output | PNG (lossless), stored to `/thumbnails/{language}/{slug}/` |
| Trigger | Automated on video publish via GitHub Actions or Squad pipeline |

---

## Related Documents

- `docs/youtube-voice-pipeline.md` — voice/audio pipeline (existing)
- `marketing/CONTENT_STRATEGY.md` — content strategy brief
- `VIRAL_MARKETING_INDEX.md` — distribution strategy
- `.squad/decisions.md` — Decision #32: Content Production Rules (MANDATORY)
- `blog-part4-image-prompt.txt` — visual style reference for AI art prompts

## Dependencies

- **Issue #809** (YouTube channel branding) — brand guide finalization
- **Issue #810** (Video template design) — parent video design system

---

*Seven — Research & Docs | TechAI Explained Design System v1.0*
