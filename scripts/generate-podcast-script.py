#!/usr/bin/env python3

"""
Podcast Script Generator — Converts articles into natural two-host conversations.
Produces dialogue scripts that sound like .NET Rocks or NotebookLM podcasts.

Backends (tried in order):
  1. Azure OpenAI (AZURE_OPENAI_ENDPOINT + AZURE_OPENAI_KEY)
  2. OpenAI (OPENAI_API_KEY)
  3. Built-in template engine (no API required, decent quality)

Usage:
  python generate-podcast-script.py article.md
  python generate-podcast-script.py article.md -o script.txt
  python generate-podcast-script.py article.md --prompt-only  # just print the prompt
"""

import argparse
import io
import json
import os
import random
import re
import sys
import textwrap
from pathlib import Path

# Ensure UTF-8 output even when stdout is redirected
if sys.stdout.encoding != 'utf-8':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
if sys.stderr.encoding != 'utf-8':
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# ---------------------------------------------------------------------------
# Markdown stripping (shared logic)
# ---------------------------------------------------------------------------

def strip_markdown(text: str) -> str:
    t = text
    t = re.sub(r'(?s)^---\n.*?\n---\n', '', t)
    t = re.sub(r'(?s)<!--.*?-->', '', t)
    t = re.sub(r'(?s)```.*?```', '', t)
    t = re.sub(r'`[^`]+`', '', t)
    t = re.sub(r'!\[([^\]]*)\]\([^)]+\)', r'\1', t)
    t = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', t)
    t = re.sub(r'(?m)^#{1,6}\s+', '', t)
    t = re.sub(r'\*\*([^*]+)\*\*', r'\1', t)
    t = re.sub(r'\*([^*]+)\*', r'\1', t)
    t = re.sub(r'__([^_]+)__', r'\1', t)
    t = re.sub(r'(?m)^[-*_]{3,}\s*$', '', t)
    t = re.sub(r'(?m)^>\s+', '', t)
    t = re.sub(r'(?m)^[\*\-\+]\s+', '', t)
    t = re.sub(r'(?m)^\d+\.\s+', '', t)
    # Remove table rows (pipes, separator lines)
    t = re.sub(r'(?m)^[\s|]*[-:]+[\s|]*[-:|]+[\s|]*$', '', t)  # --- | --- rows
    t = re.sub(r'\|', ' ', t)
    # Remove emoji/checkmarks used as status markers
    t = re.sub(r'[✅❌⚠️🔴🟡🟢✨🎯📊💡🔧📝🎤🎙️📄🔊💬🔗📖🔍]', '', t)
    # Collapse multiple spaces
    t = re.sub(r'  +', ' ', t)
    t = re.sub(r'\n{3,}', '\n\n', t)
    return t.strip()


def extract_title(markdown: str, filename: str) -> str:
    m = re.search(r'^#\s+(.+)$', markdown, re.MULTILINE)
    return m.group(1).strip() if m else filename.replace('-', ' ').replace('_', ' ').title()


def extract_sections(markdown: str) -> list[dict]:
    """Pull out header→content sections for the template engine."""
    sections = []
    lines = markdown.split('\n')
    cur = {'title': '', 'content': []}
    for line in lines:
        hm = re.match(r'^(#{1,3})\s+(.+)$', line)
        if hm:
            if cur['title'] or cur['content']:
                sections.append(cur)
            cur = {'title': hm.group(2).strip(), 'level': len(hm.group(1)), 'content': []}
        else:
            cur['content'].append(line)
    if cur['title'] or cur['content']:
        sections.append(cur)
    return sections


# ---------------------------------------------------------------------------
# LLM prompt
# ---------------------------------------------------------------------------

SYSTEM_PROMPT = textwrap.dedent("""\
You are a podcast script writer for tech podcasts like .NET Rocks, Syntax.fm, and
Google NotebookLM's Audio Overview. You convert technical articles into engaging
two-person podcast conversations between hosts named Alex and Sam.

HOST PERSONALITIES:
- Alex: Curious, asks clarifying questions, represents the audience's perspective.
  Sometimes interrupts with "Wait, hold on..." or "So you're saying..."
  Uses more filler words ("hmm", "uh", "you know").
- Sam: More technical/expert, explains concepts clearly, adds real-world context.
  Sometimes skeptical or offers alternative viewpoints. Uses phrases like
  "Actually, here's the thing..." or "Right, but..."

CONVERSATIONAL STYLE — Make it sound like TWO PEOPLE TALKING, not reading:
- Natural interruptions and overlaps (Alex cuts in mid-thought)
- Disagreements and debates ("I'm not sure about that..." "Really? I'd argue...")
- Filler words at natural points: "um", "uh", "hmm", "you know", "like", "so", "I mean"
- Thinking-out-loud moments ("Let me think about that..." "Hold on, how does...")
- Back-and-forth questions and answers, not monologues
- Emotional shifts: excitement, skepticism, agreement, surprise ("Whoa!" "No way!" "Exactly!")
- Jokes and banter (casual humor, not forced)
- References to shared experiences ("Remember when we talked about..." "Yeah, I've seen that too...")

NATURAL TRANSITIONS:
- Move between topics like real people do, not like chapters
- "So that reminds me..." "Speaking of..." "Oh, and another thing..."
- Sometimes circle back: "Wait, going back to what you said earlier..."

STRUCTURE:
- Opening: Casual intro with banter about the topic (not stiff)
- Body: Conversational exploration of content with natural digressions
- Outro: Key takeaways, final thoughts, casual sign-off
- Total: ~2000-4000 words for 15-20 minute episode

FORMAT:
- Write ONLY dialogue lines prefixed with [ALEX] or [SAM]
- Vary turn lengths — short reactions AND longer explanations
- No stage directions, sound effects, or anything besides dialogue
- Keep technical accuracy but explain jargon naturally
""")

SYSTEM_PROMPT_HE = textwrap.dedent("""\
אתה כותב תסריטים לפודקאסטים טכנולוגיים בעברית. אתה ממיר מאמרים טכניים לשיחות
פודקאסט מרתקות בין שני מגישים בשמות אלכס וסם.

אישיות המגישים:
- אלכס (Alex): סקרן, שואל שאלות הבהרה, מייצג את נקודת המבט של הקהל.
  לפעמים קוטע עם "רגע, רגע..." או "אז מה שאתה אומר זה..."
  משתמש במילות מילוי ("אממ", "אה", "אתה יודע", "כאילו").
- סם (Sam): יותר טכני/מומחה, מסביר מושגים בבהירות, מוסיף הקשר מעשי.
  לפעמים סקפטי או מציע נקודות מבט חלופיות. משתמש בביטויים כמו
  "בעצם, הנה העניין..." או "נכון, אבל..."

סגנון שיחה — לגרום לזה להישמע כמו שני אנשים מדברים, לא קוראים:
- הפסקות טבעיות (אלכס קוטע באמצע מחשבה)
- חילוקי דעות ודיונים ("אני לא בטוח לגבי זה..." "באמת? אני דווקא חושב...")
- מילות מילוי בנקודות טבעיות: "אממ", "אה", "נו", "יאללה", "כאילו", "בקיצור", "תשמע"
- רגעי חשיבה בקול רם ("תן לי לחשוב על זה..." "רגע, איך זה עובד...")
- שאלות ותשובות הלוך ושוב, לא מונולוגים
- שינויי רגש: התלהבות, ספקנות, הסכמה, הפתעה ("וואו!" "לא ייאמן!" "בדיוק!")
- בדיחות וקלילות (הומור טבעי, לא מאולץ)
- התייחסויות לחוויות משותפות ("זוכר כשדיברנו על..." "כן, גם אני ראיתי את זה...")

מעברים טבעיים:
- לעבור בין נושאים כמו אנשים אמיתיים, לא כמו פרקים
- "אז זה מזכיר לי..." "אגב על..." "אה, ועוד משהו..."
- לפעמים לחזור: "רגע, חזרה למה שאמרת קודם..."

מבנה:
- פתיחה: הקדמה קלילה עם שיחת חולין על הנושא
- גוף: חקירה שיחתית של התוכן עם סטיות טבעיות
- סיום: נקודות מפתח, מחשבות אחרונות, סגירה קלילה
- סה"כ: ~2000-4000 מילים לפרק של 15-20 דקות

פורמט:
- כתוב רק שורות דיאלוג עם הקידומת [ALEX] או [SAM]
- שנה אורכי תור — תגובות קצרות וגם הסברים ארוכים
- בלי הוראות בימוי, אפקטים קוליים, או כל דבר מלבד דיאלוג
- שמור על דיוק טכני אבל הסבר מונחים באופן טבעי
- כתוב בעברית טבעית ומדוברת, לא עברית ספרותית
""")


def build_user_prompt(article_text: str, title: str, language: str = "en") -> str:
    # Truncate very long articles to stay within token limits
    if len(article_text) > 12000:
        article_text = article_text[:12000] + "\n\n[Article truncated for length]"

    if language == "he":
        return textwrap.dedent(f"""\
המר את המאמר הבא לשיחת פודקאסט טבעית ומרתקת בעברית בין אלכס וסם.
כותרת המאמר: "{title}".

חשוב — לגרום לזה להישמע כמו פודקאסט טכנולוגי אמיתי בעברית:
- להתחיל עם שיחת חולין קלילה, לא הקדמה פורמלית
- אלכס צריך לקטוע את סם 3-5 פעמים עם "רגע..." או "חכה, אז..."
- לכלול לפחות נקודת מחלוקת או דיון אחת
- להשתמש במילות מילוי באופן אסטרטגי: "אממ", "כאילו", "נו", "תשמע", "בקיצור"
- להוסיף בדיחות או אנלוגיות שמרגישות טבעיות
- לשנות את הקצב — קצת הלוך ושוב מהיר, קצת הסברים ארוכים יותר
- לסיים עם סגירה קלילה, לא סיכום פורמלי
- מונחים טכניים באנגלית אפשר להשאיר באנגלית (כמו API, cloud, deployment)

פורמט:
[ALEX] טקסט דיאלוג כאן
[SAM] טקסט דיאלוג כאן

תוכן המאמר:
---
{article_text}
---

צור את תסריט הפודקאסט המלא עכשיו. זכור: שיחתי, לא מתוסרט!
""")

    return textwrap.dedent(f"""\
Convert this article into a natural, engaging podcast conversation between
Alex and Sam. The article is titled "{title}".

IMPORTANT — Make this sound like a REAL tech podcast:
- Start with casual banter, not a formal introduction
- Alex should interrupt Sam 3-5 times with "Wait..." or "Hold on, so..."
- Include at least one disagreement or debate point
- Use filler words strategically (not every line, but sprinkled throughout)
- Add jokes or analogies that feel natural, not forced
- Vary the pacing — some quick back-and-forth, some longer explanations
- End with a casual sign-off, not a formal summary

Format:
[ALEX] dialogue text here
[SAM] dialogue text here

Article content:
---
{article_text}
---

Generate the full podcast script now. Remember: conversational, not scripted!
""")


# ---------------------------------------------------------------------------
# LLM backends
# ---------------------------------------------------------------------------

def call_azure_openai(system: str, user: str) -> str | None:
    endpoint = os.environ.get('AZURE_OPENAI_ENDPOINT', '').rstrip('/')
    key = os.environ.get('AZURE_OPENAI_KEY', '')
    deployment = os.environ.get('AZURE_OPENAI_DEPLOYMENT', 'gpt-4o')
    api_version = os.environ.get('AZURE_OPENAI_API_VERSION', '2024-12-01-preview')

    if not endpoint or not key:
        return None

    import requests
    url = f"{endpoint}/openai/deployments/{deployment}/chat/completions?api-version={api_version}"
    headers = {"Content-Type": "application/json", "api-key": key}
    body = {
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": 0.9,
        "max_tokens": 8000,
    }

    print("  🌐 Calling Azure OpenAI...")
    try:
        r = requests.post(url, headers=headers, json=body, timeout=120)
        r.raise_for_status()
        return r.json()["choices"][0]["message"]["content"]
    except Exception as e:
        print(f"  ⚠️  Azure OpenAI failed: {e}")
        return None


def call_openai(system: str, user: str) -> str | None:
    key = os.environ.get('OPENAI_API_KEY', '')
    model = os.environ.get('OPENAI_MODEL', 'gpt-4o')

    if not key:
        return None

    import requests
    url = "https://api.openai.com/v1/chat/completions"
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {key}"}
    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": 0.9,
        "max_tokens": 8000,
    }

    print("  🌐 Calling OpenAI...")
    try:
        r = requests.post(url, headers=headers, json=body, timeout=120)
        r.raise_for_status()
        return r.json()["choices"][0]["message"]["content"]
    except Exception as e:
        print(f"  ⚠️  OpenAI failed: {e}")
        return None


# ---------------------------------------------------------------------------
# Template-based fallback (no LLM needed)
# ---------------------------------------------------------------------------

# Transition phrases to make the template output less robotic
_ALEX_INTROS = [
    "So let's jump into {topic}. What's the deal here?",
    "Okay, {topic} — break this down for me.",
    "Now here's the part I've been curious about: {topic}.",
    "Alright, let's shift gears to {topic}. What should people know?",
    "Oh, {topic}! I've heard a lot about this. What's the real story?",
    "Moving on — {topic}. This one's interesting, right?",
    "So {topic}. I feel like this is where things get really practical.",
    "Wait, before we move on — tell me about {topic}.",
]

_ALEX_REACTIONS = [
    "Hmm, that's a really good point.",
    "Oh wow, I didn't think about it that way.",
    "Right, right. That makes total sense.",
    "Wait, really? That's more impactful than I expected.",
    "You know, that reminds me of how other teams handle this too.",
    "Okay so basically what you're saying is — it's a bigger deal than it sounds.",
    "That's fascinating. Keep going.",
    "Ha, yeah. I've seen that pattern before.",
    "So the takeaway there is pretty clear then.",
    "Interesting. And I bet that has some downstream effects too.",
]

_ALEX_FOLLOWUPS = [
    "Can you give an example of that?",
    "How does that work in practice though?",
    "What's the biggest gotcha people run into here?",
    "Is that something most teams are doing, or is this more cutting-edge?",
    "What would you tell someone who's just getting started with this?",
]

# Hebrew template phrases
_ALEX_INTROS_HE = [
    "אז בוא נדבר על {topic}. מה הסיפור פה?",
    "טוב, {topic} — תפרק לי את זה.",
    "הנה החלק שהייתי סקרן לגביו: {topic}.",
    "יאללה, בוא נעבור ל-{topic}. מה אנשים צריכים לדעת?",
    "אה, {topic}! שמעתי הרבה על זה. מה הסיפור האמיתי?",
    "נמשיך הלאה — {topic}. זה מעניין, נכון?",
    "אז {topic}. אני מרגיש שפה זה נהיה ממש מעשי.",
    "רגע, לפני שנמשיך — ספר לי על {topic}.",
]

_ALEX_REACTIONS_HE = [
    "אממ, זו נקודה ממש טובה.",
    "וואו, לא חשבתי על זה ככה.",
    "נכון, נכון. זה הגיוני לגמרי.",
    "רגע, באמת? זה יותר משמעותי ממה שציפיתי.",
    "אתה יודע, זה מזכיר לי איך צוותים אחרים מטפלים בזה.",
    "אז בעצם מה שאתה אומר זה — שזה עניין יותר גדול ממה שנשמע.",
    "מרתק. תמשיך.",
    "הא, כן. ראיתי את הדפוס הזה בעבר.",
    "אז המסקנה פה די ברורה.",
    "מעניין. ואני מניח שיש לזה גם השפעות נוספות.",
]

_ALEX_FOLLOWUPS_HE = [
    "אתה יכול לתת דוגמה לזה?",
    "איך זה עובד בפועל?",
    "מה המלכודת הכי גדולה שאנשים נתקלים בה פה?",
    "זה משהו שרוב הצוותים עושים, או שזה יותר חדשני?",
    "מה היית אומר למישהו שרק מתחיל עם זה?",
]


def _pick(options: list[str], index: int) -> str:
    return options[index % len(options)]


def _sentences_to_chunks(sentences: list[str], max_words: int = 80) -> list[str]:
    """Group sentences into spoken-word chunks of ~max_words."""
    chunks = []
    cur, wc = [], 0
    for s in sentences:
        s = s.strip()
        if not s:
            continue
        sw = len(s.split())
        if wc + sw > max_words and cur:
            chunks.append(' '.join(cur))
            cur, wc = [s], sw
        else:
            cur.append(s)
            wc += sw
    if cur:
        chunks.append(' '.join(cur))
    return chunks


def generate_template_script(markdown: str, title: str, language: str = "en") -> str:
    """Produce a decent conversation script without any LLM, using templates."""
    sections = extract_sections(markdown)
    lines: list[str] = []

    # Select language-appropriate templates
    if language == "he":
        intros = _ALEX_INTROS_HE
        reactions = _ALEX_REACTIONS_HE
        followups = _ALEX_FOLLOWUPS_HE
    else:
        intros = _ALEX_INTROS
        reactions = _ALEX_REACTIONS
        followups = _ALEX_FOLLOWUPS

    # ── Intro ──
    if language == "he":
        lines.append(f'[ALEX] היי לכולם, ברוכים הבאים בחזרה לתוכנית! היום אנחנו צוללים למשהו ממש מעניין — "{title}". חיכיתי לזה.')
        lines.append(f'[SAM] כן, גם אני. יש פה הרבה מה לפרק, ואני חושב שהמאזינים שלנו ימצאו את זה סופר רלוונטי למה שהם עובדים עליו.')
        lines.append('[ALEX] יאללה, בוא נתחיל. תן לנו קודם את התמונה הגדולה — על מה בעצם מדובר?')
    else:
        lines.append(f'[ALEX] Hey everyone, welcome back to the show! Today we\'re diving into something really interesting — "{title}". I\'ve been looking forward to this one.')
        lines.append(f'[SAM] Yeah, me too. There\'s a lot to unpack here, and I think our listeners are going to find this super relevant to what they\'re working on.')
        lines.append('[ALEX] Alright, let\'s get into it. Give us the high-level overview first — what are we actually looking at?')

    # Filter to sections with real content, skip table-heavy and tiny sections
    content_sections = []
    for s in sections:
        if not s.get('title'):
            continue
        raw = '\n'.join(s['content']).strip()
        if not raw:
            continue
        # Skip sections that are mostly table formatting
        pipe_ratio = raw.count('|') / max(len(raw), 1)
        if pipe_ratio > 0.05:
            continue
        plain = strip_markdown(raw)
        if len(plain.split()) < 10:
            continue
        content_sections.append(s)

    # Cap at ~15 top-level sections to keep podcast focused
    if len(content_sections) > 15:
        content_sections = content_sections[:15]

    if not content_sections:
        plain = strip_markdown(markdown)
        sentences = re.split(r'(?<=[.!?])\s+', plain)
        chunks = _sentences_to_chunks(sentences, 80)

        for i, chunk in enumerate(chunks[:20]):
            lines.append(f'[SAM] {chunk}')
            if i < len(chunks) - 1 and (i % 3 == 1):
                lines.append(f'[ALEX] {_pick(reactions, i)}')
        if language == "he":
            lines.append('[ALEX] זה סיכום מצוין. תודה שהעברת אותנו דרך כל זה.')
        else:
            lines.append('[ALEX] That\'s a great rundown. Thanks for walking us through all of that.')
    else:
        for idx, section in enumerate(content_sections):
            topic = section['title']
            content = strip_markdown('\n'.join(section['content']))
            if not content:
                continue

            # Alex introduces the section
            if idx == 0:
                if language == "he":
                    lines.append(f'[SAM] אז התמונה הגדולה עם {topic} די משכנעת. תן לי להעביר אותך דרך זה.')
                else:
                    lines.append(f'[SAM] So the big picture with {topic} is pretty compelling. Let me walk you through it.')
            else:
                lines.append(f'[ALEX] {_pick(intros, idx).format(topic=topic)}')

            # Split content into natural chunks
            sentences = re.split(r'(?<=[.!?])\s+', content)
            chunks = _sentences_to_chunks(sentences, 80)

            # Cap chunks per section to keep it conversational
            chunks = chunks[:5]

            for ci, chunk in enumerate(chunks):
                lines.append(f'[SAM] {chunk}')
                if ci < len(chunks) - 1:
                    if len(chunks) > 2 and ci % 2 == 1:
                        lines.append(f'[ALEX] {_pick(reactions, idx * 10 + ci)}')
                    elif len(chunks) > 4 and ci == len(chunks) // 2:
                        lines.append(f'[ALEX] {_pick(followups, idx)}')

            if idx < len(content_sections) - 1:
                lines.append(f'[ALEX] {_pick(reactions, idx + 5)}')

    # ── Outro ──
    if language == "he":
        lines.append('[ALEX] טוב, אז בוא נסכם עם הנקודות המרכזיות. אם המאזינים שלנו זוכרים דבר אחד או שניים מהפרק הזה, מה זה צריך להיות?')
        lines.append(f'[SAM] הייתי אומר שהדבר הכי גדול הוא ש-{title} מייצג שינוי אמיתי באיך שאנחנו ניגשים לבעיה הזו. הפרטים שכיסינו היום מראים שיש פה הרבה עומק, אבל המסר המרכזי די ישים.')
        lines.append('[ALEX] אהבתי. ובאמת, אני חושב שהזווית המעשית פה היא מה שהופך את זה לכל כך משכנע. זה לא רק תיאוריה — יש פה דברים אמיתיים שאפשר ללכת וליישם.')
        lines.append('[SAM] בדיוק. ולכל מי שרוצה להעמיק, בהחלט תבדקו את הכתבה המלאה. רק גרדנו את פני השטח היום.')
        lines.append('[ALEX] מעולה. תודה שהאזנתם! אם נהניתם מהפרק, שתפו אותו עם הצוות שלכם. נתפוס אתכם בפרק הבא.')
        lines.append('[SAM] להתראות בפעם הבאה!')
    else:
        lines.append('[ALEX] Alright, so let\'s wrap up with the key takeaways. If our listeners remember one or two things from this, what should it be?')
        lines.append(f'[SAM] I\'d say the biggest thing is that {title.lower()} represents a real shift in how we approach this problem. The details we covered today show there\'s a lot of depth here, but the core message is pretty actionable.')
        lines.append('[ALEX] Love it. And honestly, I think the practical angle here is what makes it so compelling. It\'s not just theory — there\'s real stuff you can go implement.')
        lines.append('[SAM] Exactly. And for anyone who wants to dig deeper, definitely check out the full writeup. We only scratched the surface today.')
        lines.append('[ALEX] Awesome. Thanks for listening everyone! If you enjoyed this episode, share it with your team. We\'ll catch you in the next one.')
        lines.append('[SAM] See you next time!')

    return '\n'.join(lines)


# ---------------------------------------------------------------------------
# Script validation / cleanup
# ---------------------------------------------------------------------------

def validate_script(raw: str) -> str:
    """Ensure every line is [ALEX] or [SAM] prefixed. Strip junk."""
    out = []
    for line in raw.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        # Accept [ALEX], [SAM], [HOST_A], [HOST_B] — normalise to ALEX/SAM
        line = re.sub(r'^\[HOST_A\]', '[ALEX]', line)
        line = re.sub(r'^\[HOST_B\]', '[SAM]', line)
        if re.match(r'^\[(ALEX|SAM)\]\s', line):
            out.append(line)
    return '\n'.join(out)


# ---------------------------------------------------------------------------
# Post-processing: rewrite for natural speech (Improvement #1, issue #464)
# ---------------------------------------------------------------------------

# Formal → contraction mappings for spoken naturalness
_CONTRACTIONS = [
    (r'\bdo not\b', "don't"), (r'\bDo not\b', "Don't"),
    (r'\bcannot\b', "can't"), (r'\bCannot\b', "Can't"),
    (r'\bwill not\b', "won't"), (r'\bWill not\b', "Won't"),
    (r'\bshould not\b', "shouldn't"), (r'\bShould not\b', "Shouldn't"),
    (r'\bwould not\b', "wouldn't"), (r'\bWould not\b', "Wouldn't"),
    (r'\bcould not\b', "couldn't"), (r'\bCould not\b', "Couldn't"),
    (r'\bis not\b', "isn't"), (r'\bIs not\b', "Isn't"),
    (r'\bare not\b', "aren't"), (r'\bAre not\b', "Aren't"),
    (r'\bwas not\b', "wasn't"), (r'\bWas not\b', "Wasn't"),
    (r'\bwere not\b', "weren't"), (r'\bWere not\b', "Weren't"),
    (r'\bhas not\b', "hasn't"), (r'\bHas not\b', "Hasn't"),
    (r'\bhave not\b', "haven't"), (r'\bHave not\b', "Haven't"),
    (r'\bhad not\b', "hadn't"), (r'\bHad not\b', "Hadn't"),
    (r'\bdoes not\b', "doesn't"), (r'\bDoes not\b', "Doesn't"),
    (r'\bdid not\b', "didn't"), (r'\bDid not\b', "Didn't"),
    (r'\bit is\b', "it's"), (r'\bIt is\b', "It's"),
    (r'\bthat is\b', "that's"), (r'\bThat is\b', "That's"),
    (r'\bthere is\b', "there's"), (r'\bThere is\b', "There's"),
    (r'\bwhat is\b', "what's"), (r'\bWhat is\b', "What's"),
    (r'\bhere is\b', "here's"), (r'\bHere is\b', "Here's"),
    (r'\blet us\b', "let's"), (r'\bLet us\b', "Let's"),
    (r'\bI am\b', "I'm"),
    (r'\bI will\b', "I'll"),
    (r'\bI have\b', "I've"),
    (r'\bI would\b', "I'd"),
    (r'\bwe are\b', "we're"), (r'\bWe are\b', "We're"),
    (r'\bwe will\b', "we'll"), (r'\bWe will\b', "We'll"),
    (r'\bwe have\b', "we've"), (r'\bWe have\b', "We've"),
    (r'\bthey are\b', "they're"), (r'\bThey are\b', "They're"),
    (r'\bthey will\b', "they'll"), (r'\bThey will\b', "They'll"),
    (r'\byou are\b', "you're"), (r'\bYou are\b', "You're"),
    (r'\byou will\b', "you'll"), (r'\bYou will\b', "You'll"),
    (r'\byou have\b', "you've"), (r'\bYou have\b', "You've"),
    (r'\bgoing to\b', "gonna"),
    (r'\bwant to\b', "wanna"),
    (r'\bgot to\b', "gotta"),
]

# Filler words/phrases to sprinkle at sentence boundaries
_FILLERS_START = [
    "You know, ", "I mean, ", "Like, ", "So, ", "Well, ",
    "Honestly, ", "Look, ", "Okay so, ", "Yeah, ",
]

# Mid-sentence disfluencies (inserted before a clause)
_DISFLUENCIES = [
    ", you know,", ", like,", ", I mean,", ", right,",
]

# Conversational transitions to replace formal connectors
_TRANSITION_REWRITES = [
    (r'\bHowever,\b', "But hey,"),
    (r'\bFurthermore,\b', "And also,"),
    (r'\bAdditionally,\b', "Plus,"),
    (r'\bMoreover,\b', "On top of that,"),
    (r'\bIn conclusion,\b', "So bottom line,"),
    (r'\bConsequently,\b', "So basically,"),
    (r'\bNevertheless,\b', "But still,"),
    (r'\bTherefore,\b', "So,"),
    (r'\bIn other words,\b', "Basically,"),
    (r'\bIt is important to note that\b', "Here's the thing —"),
    (r'\bIt should be noted that\b', "Worth mentioning —"),
    (r'\bFor example,\b', "Like for instance,"),
    (r'\bAs a result,\b', "So what happens is,"),
]


def _apply_contractions(text: str) -> str:
    for pattern, replacement in _CONTRACTIONS:
        text = re.sub(pattern, replacement, text)
    return text


def _add_fillers(text: str, filler_rate: float = 0.15) -> str:
    """Add filler words at the start of ~filler_rate fraction of sentences."""
    sentences = re.split(r'(?<=[.!?])\s+', text)
    result = []
    for i, s in enumerate(sentences):
        # Skip first sentence (keep the opening clean) and short sentences
        if i > 0 and len(s.split()) > 5 and random.random() < filler_rate:
            filler = random.choice(_FILLERS_START)
            # Lowercase the first char of the sentence after adding filler
            if s and s[0].isupper():
                s = s[0].lower() + s[1:]
            s = filler + s
        result.append(s)
    return ' '.join(result)


def _add_disfluencies(text: str, disfluency_rate: float = 0.08) -> str:
    """Insert mid-sentence disfluencies before random commas/clauses."""
    # Find clause boundaries (comma followed by space and a word)
    parts = re.split(r'(,\s+)', text)
    result = []
    for i, part in enumerate(parts):
        result.append(part)
        # Randomly insert a disfluency after a comma-space separator
        if re.match(r',\s+$', part) and random.random() < disfluency_rate:
            disf = random.choice(_DISFLUENCIES).strip(', ')
            result.append(disf + ', ')
    return ''.join(result)


def _apply_transitions(text: str) -> str:
    for pattern, replacement in _TRANSITION_REWRITES:
        text = re.sub(pattern, replacement, text)
    return text


def rewrite_for_speech(script: str) -> str:
    """Rewrite a podcast script for natural spoken delivery.

    Transforms formal written text into conversational speech patterns by:
    - Applying contractions (do not → don't)
    - Replacing formal transitions with casual ones
    - Adding filler words and disfluencies
    """
    lines = script.strip().splitlines()
    rewritten = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        m = re.match(r'^(\[(ALEX|SAM)\])\s+(.+)$', line)
        if not m:
            rewritten.append(line)
            continue
        prefix = m.group(1)
        text = m.group(3)
        text = _apply_contractions(text)
        text = _apply_transitions(text)
        text = _add_fillers(text)
        text = _add_disfluencies(text)
        rewritten.append(f'{prefix} {text}')
    return '\n'.join(rewritten)


# ---------------------------------------------------------------------------
# Post-processing: back-channeling & interjections (Improvement #2, #464)
# ---------------------------------------------------------------------------

# Short listener responses that signal engagement
_BACKCHANNELS = [
    "Mmhm.", "Right.", "Exactly.", "Interesting.", "Oh wow.",
    "Yeah.", "Sure.", "Got it.", "Makes sense.", "Totally.",
    "Oh, nice.", "Huh.", "For real?", "Wow.", "True.",
    "Yeah, yeah.", "Okay.", "Absolutely.", "Fair enough.", "Oh, cool.",
]


def insert_backchannels(script: str, frequency: float = 0.30) -> str:
    """Insert short listener back-channel responses between speaker turns.

    Inserts a brief interjection from the *other* speaker between turns
    at the given frequency (0.0–1.0). Avoids inserting back-to-back, at the
    very start/end, or when the previous turn is already very short.
    """
    lines = [l.strip() for l in script.strip().splitlines() if l.strip()]
    if len(lines) < 4:
        return script

    result = [lines[0]]  # keep first line as-is
    prev_was_backchannel = False

    for i in range(1, len(lines)):
        curr_line = lines[i]
        prev_line = lines[i - 1]

        # Parse speakers
        prev_m = re.match(r'^\[(ALEX|SAM)\]\s+(.+)$', prev_line)
        curr_m = re.match(r'^\[(ALEX|SAM)\]\s+(.+)$', curr_line)

        if (prev_m and curr_m
                and prev_m.group(1) != curr_m.group(1)
                and not prev_was_backchannel
                and i < len(lines) - 1  # not before the last line
                and len(prev_m.group(2).split()) > 8  # previous turn long enough
                and random.random() < frequency):
            # Insert a backchannel from the current speaker
            listener = curr_m.group(1)
            bc = random.choice(_BACKCHANNELS)
            result.append(f'[{listener}] {bc}')
            prev_was_backchannel = True
        else:
            prev_was_backchannel = False

        result.append(curr_line)

    return '\n'.join(result)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Generate a natural podcast conversation script from an article"
    )
    parser.add_argument("input_file", help="Path to markdown/text file")
    parser.add_argument("-o", "--output", help="Output script file (default: <input>-podcast-script.txt)")
    parser.add_argument("--language", default="en", choices=["en", "he"],
                        help="Language for the generated script (default: en)")
    parser.add_argument("--prompt-only", action="store_true",
                        help="Print the LLM prompt to stdout and exit (for manual use)")
    parser.add_argument("--template-only", action="store_true",
                        help="Force template engine even if LLM keys are set")
    parser.add_argument("--natural-speech", action="store_true",
                        help="Rewrite script for natural spoken delivery (contractions, fillers, disfluencies)")
    parser.add_argument("--backchannels", action="store_true",
                        help="Insert listener back-channel responses between turns")
    parser.add_argument("--backchannel-frequency", type=float, default=0.30,
                        help="Probability of inserting a backchannel per turn transition (0.0-1.0, default: 0.30)")
    args = parser.parse_args()

    lang = args.language

    input_path = Path(args.input_file).resolve()
    if not input_path.exists():
        print(f"❌ File not found: {input_path}")
        sys.exit(1)

    output_path = Path(args.output) if args.output else input_path.with_suffix('.podcast-script.txt')

    print("🎙️  Podcast Script Generator")
    print(f"📄 Input:  {input_path}")
    print(f"📝 Output: {output_path}")
    print(f"🌐 Language: {lang}\n")

    # Read and process input
    markdown = input_path.read_text(encoding='utf-8')
    title = extract_title(markdown, input_path.stem)
    plain = strip_markdown(markdown)
    word_count = len(plain.split())
    print(f"📊 Article: \"{title}\" ({word_count} words)\n")

    # Select system prompt based on language
    system_prompt = SYSTEM_PROMPT_HE if lang == "he" else SYSTEM_PROMPT

    # Build prompt
    user_prompt = build_user_prompt(plain, title, language=lang)

    if args.prompt_only:
        print("=" * 60)
        print("SYSTEM PROMPT:")
        print("=" * 60)
        print(system_prompt)
        print("=" * 60)
        print("USER PROMPT:")
        print("=" * 60)
        print(user_prompt)
        sys.exit(0)

    # Try LLM backends
    script = None

    if not args.template_only:
        print("🔍 Checking for LLM API keys...")

        # 1. Azure OpenAI
        script = call_azure_openai(system_prompt, user_prompt)

        # 2. OpenAI
        if script is None:
            script = call_openai(system_prompt, user_prompt)

        if script:
            print("  ✅ LLM-generated conversation script received")
            script = validate_script(script)
        else:
            print("  ℹ️  No LLM API available — using built-in template engine")

    # 3. Template fallback
    if not script:
        print("🔧 Generating conversation with template engine...")
        script = generate_template_script(markdown, title, language=lang)

    # Post-processing passes (issue #464)
    # Skip English-specific natural speech rewriting for Hebrew
    if args.natural_speech and lang == "en":
        print("🗣️  Rewriting script for natural speech...")
        script = rewrite_for_speech(script)

    if args.backchannels:
        freq = max(0.0, min(1.0, args.backchannel_frequency))
        print(f"💬 Inserting back-channel responses ({int(freq*100)}% frequency)...")
        script = insert_backchannels(script, frequency=freq)

    # Count turns
    turns = len([l for l in script.splitlines() if l.strip()])
    script_words = len(script.split())
    est_min = round(script_words / 150)

    print(f"\n✅ Script generated: {turns} dialogue turns, ~{script_words} words (~{est_min} min)")

    # Write output
    output_path.write_text(script, encoding='utf-8')
    print(f"💾 Saved to: {output_path}")

    return str(output_path)


if __name__ == "__main__":
    main()
