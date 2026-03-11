#!/usr/bin/env python3

"""
Blog Podcast Generator — Issue #41
Generates a NotebookLM-style two-person conversational podcast from
the AI Squad blog post using edge-tts with distinct voices.

Unlike the generic podcaster-conversational.py, this generates a
hand-crafted natural conversation rather than mechanically reading sections.
"""

import asyncio
import sys
import os
import time
from pathlib import Path

try:
    import edge_tts
except ImportError:
    print("❌ edge-tts not installed. Run: pip install edge-tts")
    sys.exit(1)

# Two distinct voices for natural conversation feel
VOICE_ALEX = "en-US-GuyNeural"       # Male host — curious, asks questions
VOICE_JAMIE = "en-US-JennyNeural"    # Female expert — knowledgeable, explains

CONVERSATION_SCRIPT = [
    # ── INTRO ──
    ("ALEX", "Hey everyone, welcome back. Today we're diving into something really cool — an engineer who basically built an entire AI team to run his projects while he sleeps. I'm not exaggerating."),
    ("JAMIE", "Yeah, this is Tamir Dresher's blog post about building what he calls an AI Squad. And the results are pretty wild — fourteen PRs merged, six security findings, three infrastructure improvements — all in forty-eight hours, with zero manual prompts from him."),
    ("ALEX", "Okay, let's back up though. Because the setup is really interesting. He starts by saying he's tried every productivity system — Notion, Planner, Outlook tasks — and none of them stuck past two weeks."),
    ("JAMIE", "Right, and his insight was that the problem wasn't the tools — it was him. Every system required willpower and memory. You have to remember to check it, remember to update it. And a busy day just destroys that."),
    ("ALEX", "So what did he do differently?"),

    # ── THE SQUAD STRUCTURE ──
    ("JAMIE", "He built specialized AI agents. Not one general-purpose assistant — a team of seven specialists plus two background workers. Each one has a specific domain and a charter that prevents scope creep."),
    ("ALEX", "Walk me through the roster. Who does what?"),
    ("JAMIE", "Okay, so there's Picard who's the lead — handles architecture and decisions. B'Elanna does infrastructure — Kubernetes, CI/CD, DevBox provisioning. Worf is security and compliance. Data does deep code review, especially C-sharp and Go."),
    ("ALEX", "And these are Star Trek names, which I love."),
    ("JAMIE", "Ha, yeah. Then there's Seven — that's Research and Docs. Podcaster makes audio summaries. And Neelix watches for external patterns and news."),
    ("ALEX", "But the real magic is the background workers, right?"),
    ("JAMIE", "Exactly. Ralph is the game-changer. He watches the GitHub issue queue every five minutes. No polling needed from the human. He merges PRs when tests pass, opens new issues when he discovers work, handles comments — all autonomously."),
    ("ALEX", "So Ralph is basically that colleague who never sleeps and never forgets."),
    ("JAMIE", "Precisely. And then Scribe silently logs every decision to a decisions file for institutional memory. When team members change, knowledge doesn't evaporate."),

    # ── WORKFLOW ──
    ("ALEX", "Now, the workflow part really stood out to me. He doesn't use Slack or email for technical decisions. Everything goes through GitHub issues."),
    ("JAMIE", "And the reasoning is solid. An issue is permanent. Full context. Every comment shows the reasoning, not just the conclusion. You can link to it later. New team members can read it and understand why something was decided, not just what was decided."),
    ("ALEX", "He actually uses this blog post as an example — Issue forty-one. He wrote a brief spec, Seven posted an outline, he gave feedback, she wrote the draft. All in one GitHub thread."),
    ("JAMIE", "No status meetings. No email chains. The result is a refined blog post with a full reasoning trail that anyone can review later."),

    # ── WHAT THEY BUILT ──
    ("ALEX", "Let's talk about what they actually shipped in forty-eight hours, because the list is impressive."),
    ("JAMIE", "So there's the Podcaster agent that converts research documents into two-voice audio summaries. There's Teams and email integration for automatic message triage. A standalone monitoring dashboard for real-time agent observability."),
    ("ALEX", "DevBox infrastructure as code, cross-squad orchestration protocols..."),
    ("JAMIE", "Provider-agnostic scheduling, comprehensive FedRAMP security assessment with six findings. And all of this documented with full decision traces in GitHub issues."),
    ("ALEX", "That's a lot of output for two days."),

    # ── WHY IT WORKS ──
    ("JAMIE", "And I think the key insight is why it works. It's five things. Specialization prevents decision paralysis — each agent owns a domain. Async-first removes meeting overhead. Documented reasoning, not just decisions. Continuous autonomous observation through Ralph. And institutional memory that survives team changes."),
    ("ALEX", "The one that resonates with me most is the continuous observation part. Because with a todo list, you have to remember to check it. With Ralph, you just... don't."),
    ("JAMIE", "Right. That's the difference between a system that requires willpower and a system that doesn't. And he makes this great point — for twenty years he tried to optimize himself with more discipline and better tools. The breakthrough was realizing he should stop asking himself to remember, and instead build systems that don't require remembering."),

    # ── TAKEAWAYS ──
    ("ALEX", "So for someone listening who wants to try this, what's the practical advice?"),
    ("JAMIE", "Five steps. Define roles with clear domain boundaries. Use GitHub issues for all decisions. Automate observation — whatever your Ralph is. Document decisions in one file. And let async work happen instead of waiting for meetings."),
    ("ALEX", "And he makes the point that this isn't really about AI specifically. A team of humans could do the same thing with the same structure. AI just doesn't need vacation or willpower."),
    ("JAMIE", "Exactly. The system design — specialization, async workflows, documented decisions, continuous observation — that works for any team. The AI just makes it easier to sustain."),

    # ── OUTRO ──
    ("ALEX", "I love it. The line that stuck with me is: this isn't magic, it's systems design. And honestly, it makes me rethink how I approach my own work."),
    ("JAMIE", "Same. The idea that the best productivity system is one you don't have to remember to use — that's a powerful reframe."),
    ("ALEX", "Alright, that's our deep dive on Tamir's AI Squad blog post. If you want to read the full thing, check the link in the description. Thanks for listening, and we'll catch you next time!"),
    ("JAMIE", "See you next time!"),
]


def format_bytes(size):
    if size < 1024:
        return f"{size} B"
    elif size < 1024 * 1024:
        return f"{size / 1024:.1f} KB"
    return f"{size / (1024 * 1024):.1f} MB"


async def generate_segment(text, voice, path, retries=3):
    for attempt in range(retries):
        try:
            comm = edge_tts.Communicate(text, voice)
            await comm.save(str(path))
            return True
        except Exception as e:
            if attempt < retries - 1:
                await asyncio.sleep(2 ** attempt)
            else:
                print(f"  ⚠️ Failed after {retries} attempts: {e}")
                return False


async def main():
    output_path = Path(__file__).parent.parent / "blog-draft-ai-squad-productivity-podcast.mp3"

    print("🎙️  Blog Podcast Generator — Issue #41")
    print(f"📄 Source: blog-draft-ai-squad-productivity.md")
    print(f"🔊 Output: {output_path}")
    print(f"💬 Dialogue turns: {len(CONVERSATION_SCRIPT)}")
    total_words = sum(len(text.split()) for _, text in CONVERSATION_SCRIPT)
    est_minutes = total_words / 150
    print(f"📊 ~{total_words} words, estimated ~{est_minutes:.0f} min\n")

    voices = {
        "ALEX": VOICE_ALEX,
        "JAMIE": VOICE_JAMIE,
    }

    import tempfile
    start = time.time()

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        segments = []

        for i, (speaker, text) in enumerate(CONVERSATION_SCRIPT):
            seg_path = tmp / f"seg_{i:03d}_{speaker}.mp3"
            voice = voices[speaker]
            preview = text[:60] + ("..." if len(text) > 60 else "")
            print(f"  [{i+1}/{len(CONVERSATION_SCRIPT)}] {speaker}: {preview}")
            ok = await generate_segment(text, voice, seg_path)
            if ok:
                segments.append(seg_path)
            else:
                print(f"  ❌ Skipping segment {i+1}")

        print(f"\n🔗 Concatenating {len(segments)} segments...")

        # Try pydub first, fallback to binary concat
        concatenated = False
        try:
            from pydub import AudioSegment
            combined = AudioSegment.empty()
            pause = AudioSegment.silent(duration=350)  # brief pause between speakers

            for seg in segments:
                audio = AudioSegment.from_mp3(str(seg))
                combined += audio + pause

            combined.export(str(output_path), format="mp3")
            concatenated = True
            print("  ✅ High-quality concatenation (pydub)")
        except Exception as e:
            print(f"  ⚠️ pydub failed ({e}), using binary concat")

        if not concatenated:
            with open(output_path, 'wb') as out:
                for seg in segments:
                    with open(seg, 'rb') as inp:
                        out.write(inp.read())
            print("  ✅ Binary concatenation complete")

    elapsed = time.time() - start
    size = output_path.stat().st_size

    print(f"\n✨ Done in {elapsed:.1f}s")
    print(f"📁 {output_path.name} — {format_bytes(size)}")
    print(f"🎧 Voices: Alex (en-US-GuyNeural) + Jamie (en-US-JennyNeural)")
    print(f"💬 {len(CONVERSATION_SCRIPT)} dialogue turns, ~{est_minutes:.0f} min estimated")


if __name__ == "__main__":
    asyncio.run(main())
