#!/usr/bin/env python3
"""Hebrew SSML prosody templates for natural conversation.

Provides SSML template functions for Azure TTS with varied prosody styles,
natural pauses, pitch contours, Hebrew filler words, and emphasis patterns.
Designed for the Hebrew podcast voice cloning pipeline.

Supported styles:
    - conversational: Natural, relaxed speech with fillers and pauses
    - newscast: Professional broadcast tone with measured pacing
    - excited: Energetic delivery with faster rate and higher pitch
    - thoughtful: Slower, reflective speech with longer pauses
    - question: Rising pitch contour for interrogative sentences

Supported speakers:
    - dotan: Maps to he-IL-AvriNeural (male)
    - shahar: Maps to he-IL-HilaNeural (female)

Usage:
    from hebrew_ssml_templates import render_turn

    ssml = render_turn("שלום לכולם", style="conversational", speaker="dotan")

CLI:
    python hebrew_ssml_templates.py --text "שלום" --style conversational --speaker dotan

Reference: HUMAN_QUALITY_RESEARCH.md
"""

import argparse
import random
import re
from typing import Optional

# ---------------------------------------------------------------------------
# Speaker → Azure TTS voice mapping
# ---------------------------------------------------------------------------

SPEAKERS = {
    "dotan": "he-IL-AvriNeural",
    "shahar": "he-IL-HilaNeural",
}

# ---------------------------------------------------------------------------
# Hebrew filler words used for naturalness
# ---------------------------------------------------------------------------

HEBREW_FILLERS = ["אממ", "נו", "אוקיי", "כן", "אז"]

# ---------------------------------------------------------------------------
# Style configurations
# ---------------------------------------------------------------------------

STYLE_CONFIGS = {
    "conversational": {
        "rate_range": (0.95, 1.05),
        "pitch": "default",
        "pitch_shift": "+0%",
        "break_before_ms": (200, 400),
        "break_after_ms": (150, 350),
        "filler_probability": 0.3,
        "emphasis_level": "moderate",
        "contour": None,
    },
    "newscast": {
        "rate_range": (0.92, 1.0),
        "pitch": "default",
        "pitch_shift": "+2%",
        "break_before_ms": (300, 500),
        "break_after_ms": (200, 400),
        "filler_probability": 0.0,
        "emphasis_level": "strong",
        "contour": None,
    },
    "excited": {
        "rate_range": (1.02, 1.10),
        "pitch": "high",
        "pitch_shift": "+8%",
        "break_before_ms": (100, 250),
        "break_after_ms": (100, 200),
        "filler_probability": 0.15,
        "emphasis_level": "strong",
        "contour": None,
    },
    "thoughtful": {
        "rate_range": (0.90, 0.96),
        "pitch": "default",
        "pitch_shift": "-2%",
        "break_before_ms": (400, 700),
        "break_after_ms": (300, 600),
        "filler_probability": 0.25,
        "emphasis_level": "moderate",
        "contour": None,
    },
    "question": {
        "rate_range": (0.95, 1.05),
        "pitch": "default",
        "pitch_shift": "+0%",
        "break_before_ms": (200, 400),
        "break_after_ms": (300, 500),
        "filler_probability": 0.1,
        "emphasis_level": "moderate",
        # Rising pitch contour for interrogative intonation
        "contour": "(80%, +5%) (90%, +15%) (100%, +25%)",
    },
}

# ---------------------------------------------------------------------------
# Core template helpers
# ---------------------------------------------------------------------------


def _pick_rate(rate_range: tuple[float, float], seed: Optional[int] = None) -> str:
    """Return a speaking rate string within the given range.

    Args:
        rate_range: (min_rate, max_rate) as multipliers, e.g. (0.9, 1.1).
        seed: Optional RNG seed for reproducibility.

    Returns:
        Rate percentage string for SSML, e.g. ``"-5%"`` or ``"+3%"``.
    """
    rng = random.Random(seed)
    rate = rng.uniform(*rate_range)
    pct = round((rate - 1.0) * 100)
    return f"{pct:+d}%"


def _pick_break(ms_range: tuple[int, int], seed: Optional[int] = None) -> str:
    """Return an SSML ``<break>`` element with a random duration.

    Args:
        ms_range: (min_ms, max_ms) for the break duration.
        seed: Optional RNG seed for reproducibility.

    Returns:
        SSML break element, e.g. ``<break time="250ms"/>``.
    """
    rng = random.Random(seed)
    ms = rng.randint(*ms_range)
    return f'<break time="{ms}ms"/>'


def _maybe_insert_filler(
    text: str, probability: float, seed: Optional[int] = None
) -> str:
    """Optionally prepend a Hebrew filler word to *text*.

    Fillers (אממ, נו, אוקיי, כן, אז) make synthesised speech sound more
    natural in conversational contexts.

    Args:
        text: The original Hebrew text.
        probability: Chance (0.0–1.0) of inserting a filler.
        seed: Optional RNG seed for reproducibility.

    Returns:
        Text with or without a prepended filler and short pause.
    """
    rng = random.Random(seed)
    if probability > 0 and rng.random() < probability:
        filler = rng.choice(HEBREW_FILLERS)
        return f'{filler}... <break time="200ms"/> {text}'
    return text


def _add_emphasis(text: str, level: str = "moderate") -> str:
    """Wrap the first content word in an SSML ``<emphasis>`` element.

    This draws attention to a key word, improving perceived naturalness.
    Only the first word that is 3+ characters long is emphasised.

    Args:
        text: Input Hebrew text (may already contain SSML fragments).
        level: One of ``"reduced"``, ``"moderate"``, ``"strong"``.

    Returns:
        Text with one ``<emphasis>`` wrapper applied, or unchanged if no
        suitable word is found.
    """
    # Match the first Hebrew word that is at least 3 characters long
    pattern = r"([\u0590-\u05FF]{3,})"
    match = re.search(pattern, text)
    if match:
        word = match.group(1)
        return text.replace(
            word, f'<emphasis level="{level}">{word}</emphasis>', 1
        )
    return text


# ---------------------------------------------------------------------------
# SSML builder
# ---------------------------------------------------------------------------


def build_ssml(
    text: str,
    voice: str,
    rate: str,
    pitch_shift: str,
    contour: Optional[str] = None,
    break_before: str = "",
    break_after: str = "",
) -> str:
    """Assemble a complete SSML document for Azure TTS.

    Args:
        text: The body content (may include inline SSML elements such as
              ``<break>`` or ``<emphasis>``).
        voice: Azure TTS voice name, e.g. ``"he-IL-AvriNeural"``.
        rate: Speaking rate, e.g. ``"+3%"``.
        pitch_shift: Pitch adjustment, e.g. ``"+5%"``.
        contour: Optional prosody contour string for pitch curves.
        break_before: Optional ``<break>`` element placed before the text.
        break_after: Optional ``<break>`` element placed after the text.

    Returns:
        A full SSML ``<speak>`` document string.
    """
    prosody_attrs = f'rate="{rate}" pitch="{pitch_shift}"'
    if contour:
        prosody_attrs += f' contour="{contour}"'

    return (
        '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" '
        'xml:lang="he-IL">'
        f'<voice name="{voice}">'
        f"{break_before}"
        f"<prosody {prosody_attrs}>"
        f"{text}"
        f"</prosody>"
        f"{break_after}"
        f"</voice>"
        f"</speak>"
    )


# ---------------------------------------------------------------------------
# Per-style template functions
# ---------------------------------------------------------------------------


def conversational_template(
    text: str, speaker: str, seed: Optional[int] = None
) -> str:
    """Generate SSML with a natural, conversational prosody.

    Includes occasional Hebrew fillers, moderate emphasis, and relaxed pacing.

    Args:
        text: Hebrew text to synthesise.
        speaker: Speaker key (``"dotan"`` or ``"shahar"``).
        seed: Optional RNG seed for reproducibility.

    Returns:
        Complete SSML document string.
    """
    return _render("conversational", text, speaker, seed)


def newscast_template(
    text: str, speaker: str, seed: Optional[int] = None
) -> str:
    """Generate SSML with a professional newscast prosody.

    Uses measured pacing, strong emphasis, and no fillers.

    Args:
        text: Hebrew text to synthesise.
        speaker: Speaker key.
        seed: Optional RNG seed.

    Returns:
        Complete SSML document string.
    """
    return _render("newscast", text, speaker, seed)


def excited_template(
    text: str, speaker: str, seed: Optional[int] = None
) -> str:
    """Generate SSML with an energetic, excited prosody.

    Faster rate, higher pitch, and short pauses.

    Args:
        text: Hebrew text to synthesise.
        speaker: Speaker key.
        seed: Optional RNG seed.

    Returns:
        Complete SSML document string.
    """
    return _render("excited", text, speaker, seed)


def thoughtful_template(
    text: str, speaker: str, seed: Optional[int] = None
) -> str:
    """Generate SSML with a slow, reflective prosody.

    Slower rate, longer pauses, and occasional fillers for a pondering effect.

    Args:
        text: Hebrew text to synthesise.
        speaker: Speaker key.
        seed: Optional RNG seed.

    Returns:
        Complete SSML document string.
    """
    return _render("thoughtful", text, speaker, seed)


def question_template(
    text: str, speaker: str, seed: Optional[int] = None
) -> str:
    """Generate SSML with a rising pitch contour for questions.

    Applies an interrogative intonation pattern with pitch rising toward
    the end of the utterance.

    Args:
        text: Hebrew text to synthesise.
        speaker: Speaker key.
        seed: Optional RNG seed.

    Returns:
        Complete SSML document string.
    """
    return _render("question", text, speaker, seed)


# ---------------------------------------------------------------------------
# Unified render function
# ---------------------------------------------------------------------------

# Map style names to their dedicated template functions (for discovery)
STYLE_FUNCTIONS = {
    "conversational": conversational_template,
    "newscast": newscast_template,
    "excited": excited_template,
    "thoughtful": thoughtful_template,
    "question": question_template,
}


def _render(
    style: str, text: str, speaker: str, seed: Optional[int] = None
) -> str:
    """Internal renderer shared by all style-specific template functions."""
    cfg = STYLE_CONFIGS[style]
    voice = SPEAKERS[speaker]

    rate = _pick_rate(cfg["rate_range"], seed=seed)
    break_before = _pick_break(cfg["break_before_ms"], seed=seed)
    break_after = _pick_break(cfg["break_after_ms"], seed=seed)

    body = _maybe_insert_filler(text, cfg["filler_probability"], seed=seed)
    body = _add_emphasis(body, cfg["emphasis_level"])

    return build_ssml(
        text=body,
        voice=voice,
        rate=rate,
        pitch_shift=cfg["pitch_shift"],
        contour=cfg.get("contour"),
        break_before=break_before,
        break_after=break_after,
    )


def render_turn(
    text: str,
    style: str = "conversational",
    speaker: str = "dotan",
    seed: Optional[int] = None,
) -> str:
    """Render a single dialogue turn as SSML with the requested prosody style.

    This is the primary public API.  It wraps *text* in an SSML ``<speak>``
    document that includes prosody adjustments, optional fillers, emphasis,
    and natural pauses appropriate for the chosen *style*.

    Args:
        text: Hebrew text to synthesise.
        style: One of ``"conversational"``, ``"newscast"``, ``"excited"``,
               ``"thoughtful"``, or ``"question"``.
        speaker: ``"dotan"`` (he-IL-AvriNeural) or ``"shahar"``
                 (he-IL-HilaNeural).
        seed: Optional integer seed for deterministic output (useful for
              tests and reproducible renders).

    Returns:
        A complete SSML document string ready for Azure TTS.

    Raises:
        ValueError: If *style* or *speaker* is not recognised.

    Example::

        >>> ssml = render_turn("מה קורה?", style="question", speaker="shahar", seed=42)
        >>> assert '<prosody' in ssml
        >>> assert 'contour=' in ssml
    """
    if style not in STYLE_CONFIGS:
        raise ValueError(
            f"Unknown style {style!r}. Choose from: "
            f"{', '.join(sorted(STYLE_CONFIGS))}"
        )
    if speaker not in SPEAKERS:
        raise ValueError(
            f"Unknown speaker {speaker!r}. Choose from: "
            f"{', '.join(sorted(SPEAKERS))}"
        )

    return _render(style, text, speaker, seed)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def main() -> None:
    """CLI entry-point for testing SSML template rendering."""
    parser = argparse.ArgumentParser(
        description="Generate Hebrew SSML prosody templates for Azure TTS."
    )
    parser.add_argument(
        "--text",
        required=True,
        help="Hebrew text to wrap in SSML.",
    )
    parser.add_argument(
        "--style",
        default="conversational",
        choices=sorted(STYLE_CONFIGS),
        help="Prosody style (default: conversational).",
    )
    parser.add_argument(
        "--speaker",
        default="dotan",
        choices=sorted(SPEAKERS),
        help="Speaker voice (default: dotan).",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=None,
        help="RNG seed for reproducible output.",
    )
    parser.add_argument(
        "--all-styles",
        action="store_true",
        help="Render the text in every available style.",
    )

    args = parser.parse_args()

    if args.all_styles:
        for style_name in sorted(STYLE_CONFIGS):
            print(f"\n{'=' * 60}")
            print(f"Style: {style_name}")
            print("=" * 60)
            print(render_turn(args.text, style=style_name, speaker=args.speaker, seed=args.seed))
    else:
        print(render_turn(args.text, style=args.style, speaker=args.speaker, seed=args.seed))


if __name__ == "__main__":
    main()
