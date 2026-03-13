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


def build_user_prompt(article_text: str, title: str) -> str:
    # Truncate very long articles to stay within token limits
    if len(article_text) > 12000:
        article_text = article_text[:12000] + "\n\n[Article truncated for length]"

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


def generate_template_script(markdown: str, title: str) -> str:
    """Produce a decent conversation script without any LLM, using templates."""
    sections = extract_sections(markdown)
    lines: list[str] = []

    # ── Intro ──
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
                lines.append(f'[ALEX] {_pick(_ALEX_REACTIONS, i)}')
        lines.append('[ALEX] That\'s a great rundown. Thanks for walking us through all of that.')
    else:
        for idx, section in enumerate(content_sections):
            topic = section['title']
            content = strip_markdown('\n'.join(section['content']))
            if not content:
                continue

            # Alex introduces the section
            if idx == 0:
                lines.append(f'[SAM] So the big picture with {topic} is pretty compelling. Let me walk you through it.')
            else:
                lines.append(f'[ALEX] {_pick(_ALEX_INTROS, idx).format(topic=topic)}')

            # Split content into natural chunks
            sentences = re.split(r'(?<=[.!?])\s+', content)
            chunks = _sentences_to_chunks(sentences, 80)

            # Cap chunks per section to keep it conversational
            chunks = chunks[:5]

            for ci, chunk in enumerate(chunks):
                lines.append(f'[SAM] {chunk}')
                if ci < len(chunks) - 1:
                    if len(chunks) > 2 and ci % 2 == 1:
                        lines.append(f'[ALEX] {_pick(_ALEX_REACTIONS, idx * 10 + ci)}')
                    elif len(chunks) > 4 and ci == len(chunks) // 2:
                        lines.append(f'[ALEX] {_pick(_ALEX_FOLLOWUPS, idx)}')

            if idx < len(content_sections) - 1:
                lines.append(f'[ALEX] {_pick(_ALEX_REACTIONS, idx + 5)}')

    # ── Outro ──
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
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Generate a natural podcast conversation script from an article"
    )
    parser.add_argument("input_file", help="Path to markdown/text file")
    parser.add_argument("-o", "--output", help="Output script file (default: <input>-podcast-script.txt)")
    parser.add_argument("--prompt-only", action="store_true",
                        help="Print the LLM prompt to stdout and exit (for manual use)")
    parser.add_argument("--template-only", action="store_true",
                        help="Force template engine even if LLM keys are set")
    args = parser.parse_args()

    input_path = Path(args.input_file).resolve()
    if not input_path.exists():
        print(f"❌ File not found: {input_path}")
        sys.exit(1)

    output_path = Path(args.output) if args.output else input_path.with_suffix('.podcast-script.txt')

    print("🎙️  Podcast Script Generator")
    print(f"📄 Input:  {input_path}")
    print(f"📝 Output: {output_path}\n")

    # Read and process input
    markdown = input_path.read_text(encoding='utf-8')
    title = extract_title(markdown, input_path.stem)
    plain = strip_markdown(markdown)
    word_count = len(plain.split())
    print(f"📊 Article: \"{title}\" ({word_count} words)\n")

    # Build prompt
    user_prompt = build_user_prompt(plain, title)

    if args.prompt_only:
        print("=" * 60)
        print("SYSTEM PROMPT:")
        print("=" * 60)
        print(SYSTEM_PROMPT)
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
        script = call_azure_openai(SYSTEM_PROMPT, user_prompt)

        # 2. OpenAI
        if script is None:
            script = call_openai(SYSTEM_PROMPT, user_prompt)

        if script:
            print("  ✅ LLM-generated conversation script received")
            script = validate_script(script)
        else:
            print("  ℹ️  No LLM API available — using built-in template engine")

    # 3. Template fallback
    if not script:
        print("🔧 Generating conversation with template engine...")
        script = generate_template_script(markdown, title)

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
