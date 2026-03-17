#!/usr/bin/env python3
"""DNSMOS P.835 quality scoring for WAV files.

Scores audio using the Deep Noise Suppression MOS (DNSMOS) P.835 ONNX model,
which returns SIG (signal), BAK (background), and OVR (overall) MOS scores
on a 1-5 scale. Implements a configurable quality gate to reject low-quality
audio turns (default threshold: 3.5 OVR).

Usage:
    python score_dnsmos.py input.wav
    python score_dnsmos.py ./wav_directory/
    python score_dnsmos.py input.wav --threshold 3.0 --output results.json
    python score_dnsmos.py ./wavs/ --model-path ./sig_bak_ovr.onnx

Requirements:
    pip install numpy soundfile librosa onnxruntime

DNSMOS P.835 ONNX model:
    Download sig_bak_ovr.onnx from:
    https://github.com/microsoft/DNS-Challenge/tree/master/DNSMOS/DNSMOS
    Place it next to this script or specify with --model-path.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

import numpy as np

DNSMOS_SAMPLE_RATE = 16_000
DNSMOS_CHUNK_SAMPLES = 144_160  # exactly 9.01s at 16kHz
DEFAULT_THRESHOLD = 3.5
MODEL_FILENAME = "sig_bak_ovr.onnx"
MODEL_DOWNLOAD_URL = (
    "https://github.com/microsoft/DNS-Challenge/raw/master/DNSMOS/DNSMOS/sig_bak_ovr.onnx"
)


def find_model(model_path: str | None) -> str:
    """Locate the DNSMOS ONNX model file.

    Search order: explicit path > script directory > current directory.
    """
    candidates = []
    if model_path:
        candidates.append(Path(model_path))
    candidates.append(Path(__file__).parent / MODEL_FILENAME)
    candidates.append(Path.cwd() / MODEL_FILENAME)

    for p in candidates:
        if p.is_file():
            return str(p)

    raise FileNotFoundError(
        f"DNSMOS model '{MODEL_FILENAME}' not found.\n"
        f"Download from: {MODEL_DOWNLOAD_URL}\n"
        f"Place it in {Path(__file__).parent} or specify with --model-path."
    )


def load_audio(filepath: str) -> np.ndarray:
    """Load a WAV file and resample to 16 kHz mono float32."""
    import librosa
    import soundfile as sf

    audio, sr = sf.read(filepath, dtype="float32")

    # Convert to mono if stereo
    if audio.ndim > 1:
        audio = audio.mean(axis=1)

    # Resample to 16 kHz if needed
    if sr != DNSMOS_SAMPLE_RATE:
        audio = librosa.resample(audio, orig_sr=sr, target_sr=DNSMOS_SAMPLE_RATE)

    return audio.astype(np.float32)


def chunk_audio(audio: np.ndarray) -> list[np.ndarray]:
    """Split audio into fixed-size chunks of DNSMOS_CHUNK_SAMPLES.

    The last chunk is zero-padded if shorter than the required length.
    Very short files (< 1s) are padded to a full chunk.
    """
    chunks = []
    total = len(audio)

    if total == 0:
        return []

    for start in range(0, total, DNSMOS_CHUNK_SAMPLES):
        chunk = audio[start : start + DNSMOS_CHUNK_SAMPLES]
        if len(chunk) < DNSMOS_CHUNK_SAMPLES:
            padded = np.zeros(DNSMOS_CHUNK_SAMPLES, dtype=np.float32)
            padded[: len(chunk)] = chunk
            chunk = padded
        chunks.append(chunk)

    return chunks


def score_chunks(session, chunks: list[np.ndarray]) -> dict[str, float]:
    """Run DNSMOS inference on audio chunks and return averaged scores."""
    input_name = session.get_inputs()[0].name
    output_names = [o.name for o in session.get_outputs()]

    sig_scores, bak_scores, ovr_scores = [], [], []

    for chunk in chunks:
        inp = chunk.reshape(1, -1)
        outputs = session.run(output_names, {input_name: inp})
        # Model returns [SIG, BAK, OVR] — each is a scalar or 1-element array
        raw = outputs[0]
        if hasattr(raw, "flatten"):
            raw = raw.flatten()
        sig_scores.append(float(raw[0]))
        bak_scores.append(float(raw[1]))
        ovr_scores.append(float(raw[2]))

    return {
        "SIG": round(float(np.mean(sig_scores)), 3),
        "BAK": round(float(np.mean(bak_scores)), 3),
        "OVR": round(float(np.mean(ovr_scores)), 3),
    }


def score_file(
    filepath: str, session, threshold: float
) -> dict[str, Any]:
    """Score a single WAV file and return results with pass/fail."""
    try:
        audio = load_audio(filepath)
        duration_s = len(audio) / DNSMOS_SAMPLE_RATE
        chunks = chunk_audio(audio)

        if not chunks:
            return {
                "file": filepath,
                "error": "Empty audio file",
                "pass": False,
            }

        scores = score_chunks(session, chunks)
        passed = scores["OVR"] >= threshold

        return {
            "file": filepath,
            "duration_s": round(duration_s, 2),
            "num_chunks": len(chunks),
            "scores": scores,
            "threshold": threshold,
            "pass": passed,
        }
    except Exception as e:
        return {
            "file": filepath,
            "error": str(e),
            "pass": False,
        }


def collect_wav_files(path: str) -> list[str]:
    """Collect WAV file paths from a file or directory."""
    p = Path(path)
    if p.is_file():
        return [str(p)]
    if p.is_dir():
        wavs = sorted(str(f) for f in p.rglob("*.wav"))
        wavs += sorted(str(f) for f in p.rglob("*.WAV") if str(f) not in wavs)
        return wavs
    raise FileNotFoundError(f"Path not found: {path}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="DNSMOS P.835 quality scoring for WAV files.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  python score_dnsmos.py recording.wav\n"
            "  python score_dnsmos.py ./wav_dir/ --threshold 3.0\n"
            "  python score_dnsmos.py *.wav --output scores.json\n"
        ),
    )
    parser.add_argument(
        "input",
        nargs="+",
        help="WAV file(s) or directory containing WAV files to score.",
    )
    parser.add_argument(
        "--model-path",
        default=None,
        help=f"Path to DNSMOS ONNX model (default: auto-detect '{MODEL_FILENAME}').",
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=DEFAULT_THRESHOLD,
        help=f"OVR quality gate threshold (default: {DEFAULT_THRESHOLD}).",
    )
    parser.add_argument(
        "--output",
        "-o",
        default=None,
        help="Write JSON results to file (default: stdout).",
    )
    parser.add_argument(
        "--quiet",
        "-q",
        action="store_true",
        help="Suppress per-file console output; only print summary.",
    )

    args = parser.parse_args()

    # --- Locate model ---
    try:
        model_path = find_model(args.model_path)
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    # --- Load ONNX model ---
    import onnxruntime as ort

    try:
        session = ort.InferenceSession(model_path)
    except Exception as e:
        print(f"ERROR: Failed to load ONNX model: {e}", file=sys.stderr)
        return 1

    if not args.quiet:
        print(f"Model loaded: {model_path}", file=sys.stderr)

    # --- Collect files ---
    wav_files: list[str] = []
    for inp in args.input:
        try:
            wav_files.extend(collect_wav_files(inp))
        except FileNotFoundError as e:
            print(f"WARNING: {e}", file=sys.stderr)

    if not wav_files:
        print("ERROR: No WAV files found.", file=sys.stderr)
        return 1

    if not args.quiet:
        print(f"Scoring {len(wav_files)} file(s) (threshold={args.threshold})...", file=sys.stderr)

    # --- Score files ---
    results: list[dict[str, Any]] = []
    passed_count = 0
    failed_count = 0

    for wav in wav_files:
        result = score_file(wav, session, args.threshold)
        results.append(result)

        if result["pass"]:
            passed_count += 1
        else:
            failed_count += 1

        if not args.quiet:
            status = "PASS" if result["pass"] else "FAIL"
            if "error" in result:
                print(f"  [{status}] {wav}: ERROR - {result['error']}", file=sys.stderr)
            else:
                s = result["scores"]
                print(
                    f"  [{status}] {wav}: OVR={s['OVR']:.2f} SIG={s['SIG']:.2f} BAK={s['BAK']:.2f}",
                    file=sys.stderr,
                )

    # --- Summary ---
    summary = {
        "total_files": len(results),
        "passed": passed_count,
        "failed": failed_count,
        "threshold": args.threshold,
        "all_passed": failed_count == 0,
        "results": results,
    }

    json_output = json.dumps(summary, indent=2, ensure_ascii=False)

    if args.output:
        Path(args.output).write_text(json_output, encoding="utf-8")
        if not args.quiet:
            print(f"\nResults written to {args.output}", file=sys.stderr)
    else:
        print(json_output)

    if not args.quiet:
        print(
            f"\nSummary: {passed_count}/{len(results)} passed (threshold={args.threshold})",
            file=sys.stderr,
        )

    return 0 if failed_count == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
