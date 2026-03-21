"""
hebrew_vowelizer.py
===================
Hebrew vowelization / phonemization utility for the TTS pipeline.

Resolves issue #876: Hebrew text without vowel marks (nikud) causes
incorrect pronunciation in TTS engines.

Strategy (tried in order):
  1. nakdimon  – predicts actual Hebrew nikud diacritics (Unicode U+05B0–U+05BC).
                 Returns Hebrew text with diacritics that any Hebrew TTS can read.
  2. phonikud  – converts Hebrew to IPA phonemes (with stress prediction).
                 Returns IPA string, best used with TTS engines that accept IPA
                 (XTTS, phoneme-SSML in edge-tts, eSpeak-backed engines).
  3. no-op     – returns the original text unchanged (silent fallback).

Public API
----------
    add_nikud(text: str) -> str

Integration snippet for each generate script::

    # At the top of generate_*.py, after the imports:
    from hebrew_vowelizer import add_nikud, BACKEND

    # Then, wherever `text` is passed to TTS, wrap it:
    tts.tts_to_file(text=add_nikud(text), ...)     # generate_xtts_podcast.py
    communicate = edge_tts.Communicate(add_nikud(text), voice, ...)  # generate_openvoice_podcast_v2.py
    # generate_zonos_podcast.py: Zonos-Hebrew already calls phonikud internally;
    #   apply add_nikud() only when BACKEND == "nakdimon" to avoid double-phonemization.
"""

from __future__ import annotations

import logging
import warnings

logger = logging.getLogger(__name__)

# ── Detect available backend ────────────────────────────────────────────────

BACKEND: str = "noop"   # Will be updated below to "nakdimon" or "phonikud"

# 1. Try nakdimon (actual Hebrew nikud diacritics)
try:
    import nakdimon as _nakdimon  # type: ignore

    def _nakdimon_add_nikud(text: str) -> str:
        """Use nakdimon to add actual Hebrew nikud diacritics to the text."""
        return _nakdimon.add_nikud(text)

    BACKEND = "nakdimon"
    logger.info("hebrew_vowelizer: using nakdimon backend (Hebrew nikud diacritics)")

except ImportError:
    _nakdimon_add_nikud = None  # type: ignore
    logger.debug("hebrew_vowelizer: nakdimon not available (install nakdimon to enable true nikud)")

# 2. Try phonikud (IPA phonemization – best available on most setups)
if BACKEND == "noop":
    try:
        import phonikud as _phonikud  # type: ignore

        def _phonikud_add_nikud(text: str) -> str:
            """
            Use phonikud to convert Hebrew text to IPA phonemes.

            The returned string is IPA, not Hebrew with nikud marks.
            It is directly usable by:
              - XTTS (Coqui TTS) – pass as text, the model handles IPA
              - eSpeak-backed engines – they accept IPA directly
              - edge-tts via SSML <phoneme alphabet="ipa" ph="..."> tags
                (see add_nikud_ssml() helper below for edge-tts)
            """
            try:
                return _phonikud.phonemize(text)
            except Exception as exc:
                logger.warning("phonikud.phonemize() failed: %s – returning original text", exc)
                return text

        BACKEND = "phonikud"
        logger.info("hebrew_vowelizer: using phonikud backend (IPA phonemization)")

    except ImportError:
        _phonikud_add_nikud = None  # type: ignore
        logger.debug("hebrew_vowelizer: phonikud not available")

# 3. No-op fallback
if BACKEND == "noop":
    warnings.warn(
        "hebrew_vowelizer: neither nakdimon nor phonikud is installed. "
        "Install phonikud for IPA vowelization:  pip install phonikud",
        ImportWarning,
        stacklevel=2,
    )


# ── Public API ───────────────────────────────────────────────────────────────

def add_nikud(text: str) -> str:
    """
    Add vowelization to Hebrew text before passing it to a TTS engine.

    Tries backends in priority order:
      nakdimon  → returns Hebrew text with actual nikud diacritics (U+05B0–U+05BC)
      phonikud  → returns IPA phoneme string (best for XTTS / eSpeak)
      noop      → returns original text unchanged

    Parameters
    ----------
    text : str
        Hebrew text without (or with partial) nikud marks.

    Returns
    -------
    str
        Vowelized string.  Type of vowelization depends on which backend
        is active (see module-level ``BACKEND`` constant).

    Example
    -------
    >>> from hebrew_vowelizer import add_nikud, BACKEND
    >>> print(BACKEND)          # e.g. "phonikud"
    >>> print(add_nikud("שלום לכולם"))
    ʃˈlm lˈχlm
    """
    if not isinstance(text, str):
        raise TypeError(f"add_nikud expects str, got {type(text).__name__}")
    if not text.strip():
        return text

    if BACKEND == "nakdimon" and _nakdimon_add_nikud is not None:
        return _nakdimon_add_nikud(text)

    if BACKEND == "phonikud" and _phonikud_add_nikud is not None:
        return _phonikud_add_nikud(text)

    # noop
    return text


def add_nikud_ssml(text: str, voice: str = "he-IL-AvriNeural") -> str:
    """
    Wrap IPA-vowelized Hebrew text in edge-tts / Azure TTS SSML.

    Only useful when BACKEND == "phonikud" (IPA output).
    When BACKEND == "nakdimon" the nikud text can be passed directly to edge-tts
    without SSML wrapping – call add_nikud() instead.

    Parameters
    ----------
    text : str
        Hebrew text to vowelize and wrap in SSML.
    voice : str
        The TTS voice name (default: he-IL-AvriNeural).

    Returns
    -------
    str
        SSML string ready for edge-tts or Azure Speech SDK.

    Example usage in generate_openvoice_podcast_v2.py
    --------------------------------------------------
    Replace::
        communicate = edge_tts.Communicate(text, voice, rate=rate)
    With::
        if BACKEND == "nakdimon":
            vowelized = add_nikud(text)
            communicate = edge_tts.Communicate(vowelized, voice, rate=rate)
        else:  # phonikud or noop
            ssml = add_nikud_ssml(text, voice=voice)
            communicate = edge_tts.Communicate(ssml, voice, rate=rate)
    """
    ipa = add_nikud(text)
    return (
        f'<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="he-IL">'
        f'<voice name="{voice}">'
        f'<phoneme alphabet="ipa" ph="{ipa}">{text}</phoneme>'
        f'</voice></speak>'
    )


# ── Quick self-test / demo ──────────────────────────────────────────────────

if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)

    test_sentences = [
        "שלום לכולם וברוכים הבאים לעוד פרק",
        "כל אחד עם תפקיד מוגדר כמו בצוות פיתוח אמיתי",
        "אני חייב להגיד שהנושא של היום ממש סיקרן אותי",
        "מה נשמע אחי",
        "תחשבו על זה ככה",
        "הצוות פתח PRs, כתב דוקומנטציה, עשה code reviews",
    ]

    print(f"Active backend: {BACKEND}\n")
    print(f"{'Input (no nikud)':<55} | {'Output (vowelized)'}")
    print("-" * 100)
    for sentence in test_sentences:
        result = add_nikud(sentence)
        print(f"{sentence:<55} | {result}")
