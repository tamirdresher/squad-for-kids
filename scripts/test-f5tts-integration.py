#!/usr/bin/env python3
"""
F5-TTS Integration Test
Tests the F5-TTS backend in the voice-clone-podcast.py script.
"""

import sys
from pathlib import Path

def test_f5tts_import():
    """Test that F5-TTS can be imported."""
    print("Testing F5-TTS import...")
    try:
        from f5_tts.api import F5TTS
        print("✓ F5-TTS imported successfully")
        return True
    except ImportError as e:
        print(f"✗ F5-TTS import failed: {e}")
        print("  Install with: pip install f5-tts")
        return False

def test_pytorch():
    """Test PyTorch installation and GPU availability."""
    print("\nTesting PyTorch...")
    try:
        import torch
        print(f"✓ PyTorch {torch.__version__} installed")
        
        if torch.cuda.is_available():
            print(f"✓ CUDA available: {torch.cuda.get_device_name(0)}")
            print(f"  VRAM: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.1f} GB")
        elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
            print("✓ Apple Metal (MPS) available")
        else:
            print("⚠ GPU not available, will use CPU (slower)")
        
        return True
    except ImportError as e:
        print(f"✗ PyTorch not installed: {e}")
        print("  Install with: pip install torch torchaudio")
        return False

def test_voice_clone_script():
    """Test that voice-clone-podcast.py exists and has F5-TTS integration."""
    print("\nTesting voice-clone-podcast.py integration...")
    
    script_path = Path(__file__).parent / "voice-clone-podcast.py"
    if not script_path.exists():
        print(f"✗ Script not found: {script_path}")
        return False
    
    content = script_path.read_text(encoding="utf-8")
    
    checks = [
        ("generate_f5tts function", "async def generate_f5tts"),
        ("F5-TTS backend choice", '"f5tts"'),
        ("F5-TTS flag", "--f5tts"),
        ("F5TTS import", "from f5_tts.api import F5TTS"),
    ]
    
    all_ok = True
    for name, pattern in checks:
        if pattern in content:
            print(f"✓ {name} found")
        else:
            print(f"✗ {name} missing")
            all_ok = False
    
    return all_ok

def test_documentation():
    """Test that F5-TTS documentation exists."""
    print("\nTesting documentation...")
    
    docs_path = Path(__file__).parent.parent / "docs" / "F5-TTS-SETUP.md"
    if docs_path.exists():
        size_kb = docs_path.stat().st_size / 1024
        print(f"✓ Documentation found: {docs_path.name} ({size_kb:.1f} KB)")
        return True
    else:
        print(f"✗ Documentation not found: {docs_path}")
        return False

def main():
    """Run all tests."""
    print("="*60)
    print("F5-TTS Integration Test Suite")
    print("="*60)
    
    results = {
        "F5-TTS Import": test_f5tts_import(),
        "PyTorch": test_pytorch(),
        "Script Integration": test_voice_clone_script(),
        "Documentation": test_documentation(),
    }
    
    print("\n" + "="*60)
    print("Test Results Summary")
    print("="*60)
    
    for test_name, passed in results.items():
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"{status} — {test_name}")
    
    all_passed = all(results.values())
    
    print("\n" + "="*60)
    if all_passed:
        print("✅ All tests passed!")
        print("\nYou can now use F5-TTS with:")
        print("  python scripts/voice-clone-podcast.py script.txt --f5tts \\")
        print("    --ref-avri avri.wav --ref-hila hila.wav -o output.mp3")
    else:
        print("⚠️  Some tests failed. See above for details.")
        print("\nTo install missing dependencies:")
        print("  pip install f5-tts torch torchaudio")
    print("="*60)
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())
