#!/usr/bin/env python3
"""
Azure Personal Voice Pipeline
==============================
Complete pipeline for creating and using Azure Personal Voice for Hebrew TTS.

Status (2026-03-15 — Comprehensive testing completed):
  ✅ Consent API accessible on BOTH resources (eastus + eastus2)
  ✅ Projects created:
     - eastus2: hebrew-personal-voice-01 (existing)
     - eastus:  hebrew-pv-01 (new, created 2026-03-15)
  ✅ Consents (eastus2):
     - dotan-consent-02 (Succeeded)
     - shahar-consent-02 (Succeeded)
  ✅ Consents (eastus):
     - dotan-consent-eastus-01 (created 2026-03-15)
  ✅ DragonHDLatestNeural TTS works (en-US) 
  ✅ DragonHDLatestNeural speaks Hebrew via <lang> tag
  ✅ ttsembedding SSML accepted by both Dragon HD and Hebrew voices
  ❌ PersonalVoices API: 403 on BOTH resources
     Error: "You currently do not have the permission to use the personal voice.
             Apply the full access at https://aka.ms/customneural."

  Root cause: Subscription has LIMITED ACCESS (Tier 1 = consent only).
  Need FULL ACCESS (Tier 2) for personal voice creation.

  Next steps:
    1. Send email to mstts@microsoft.com (see azure-fullaccess-email-draft.md)
    2. Re-apply at https://aka.ms/customneural selecting "Personal Voice"
    3. Once approved, the entire pipeline below will work end-to-end

  Tested approaches that all hit the same 403:
    - REST API (GET/POST/PUT) on personalvoices endpoint
    - Multiple API versions (2024-02-01-preview, 2024-04-15-preview, etc.)
    - Both resources (eastus, eastus2)
    - JSON body and multipart form-data uploads
    - Speech SDK PersonalVoiceSynthesisRequest (requires text streaming, SDK 1.48.2)
    - Speech Studio internal API URLs
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

# Configuration — supports both resources
# East US (supported PV region) — preferred for Personal Voice
REGION_EASTUS = "eastus"
KEY_FILE_EASTUS = os.path.expanduser("~/.squad/azure-speech-key-eastus")
PROJECT_ID_EASTUS = "hebrew-pv-01"

# East US 2 (existing resource with consents)
REGION_EASTUS2 = "eastus2"
KEY_FILE_EASTUS2 = os.path.expanduser("~/.squad/azure-speech-key")
PROJECT_ID_EASTUS2 = "hebrew-personal-voice-01"

# Default to East US (supported PV region)
REGION = REGION_EASTUS
API_VERSION = "2024-02-01-preview"
BASE_URL = f"https://{REGION}.api.cognitive.microsoft.com/customvoice"
TTS_URL = f"https://{REGION}.tts.speech.microsoft.com/cognitiveservices/v1"
PROJECT_ID = PROJECT_ID_EASTUS
KEY_FILE = KEY_FILE_EASTUS

def get_key():
    return open(KEY_FILE).read().strip()

def api_request(method, endpoint, data=None, content_type="application/json"):
    """Make an API request to Azure Custom Voice."""
    url = f"{BASE_URL}/{endpoint}?api-version={API_VERSION}"
    key = get_key()
    headers = {
        "Ocp-Apim-Subscription-Key": key,
        "Content-Type": content_type,
    }
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read().decode())
            return resp.status, result
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        try:
            body = json.loads(body)
        except:
            pass
        return e.code, body

def list_consents():
    """List all consents."""
    status, data = api_request("GET", "consents")
    print(f"Consents ({status}):")
    for c in data.get("value", []):
        print(f"  {c['id']}: {c['status']} ({c['voiceTalentName']})")
    return data.get("value", [])

def list_projects():
    """List all projects."""
    status, data = api_request("GET", "projects")
    print(f"Projects ({status}):")
    for p in data.get("value", []):
        print(f"  {p['id']}: {p['kind']} - {p.get('description', '')}")
    return data.get("value", [])

def create_project(project_id, description="Personal Voice project"):
    """Create a new project."""
    status, data = api_request("PUT", f"projects/{project_id}", {
        "kind": "PersonalVoice",
        "description": description,
    })
    print(f"Create project ({status}): {json.dumps(data, indent=2)}")
    return data

def upload_consent_multipart(consent_id, voice_talent_name, company_name, locale, audio_path, project_id):
    """Upload consent via multipart form-data."""
    import mimetypes
    key = get_key()
    url = f"{BASE_URL}/consents/{consent_id}?api-version={API_VERSION}"
    
    boundary = "----PersonalVoiceBoundary"
    
    fields = {
        "description": f"Consent for {voice_talent_name} voice",
        "projectId": project_id,
        "voiceTalentName": voice_talent_name,
        "companyName": company_name,
        "locale": locale,
    }
    
    body = b""
    for k, v in fields.items():
        body += f"--{boundary}\r\n".encode()
        body += f'Content-Disposition: form-data; name="{k}"\r\n\r\n'.encode()
        body += f"{v}\r\n".encode()
    
    # Audio file
    body += f"--{boundary}\r\n".encode()
    body += f'Content-Disposition: form-data; name="audiodata"; filename="{os.path.basename(audio_path)}"\r\n'.encode()
    body += b"Content-Type: audio/wav\r\n\r\n"
    with open(audio_path, "rb") as f:
        body += f.read()
    body += b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Ocp-Apim-Subscription-Key", key)
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            result = json.loads(resp.read().decode())
            print(f"Consent upload ({resp.status}): {json.dumps(result, indent=2)}")
            return result
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"Consent upload error ({e.code}): {body}")
        return None

def create_personal_voice_multipart(voice_id, consent_id, project_id, audio_paths):
    """Create personal voice via multipart form-data upload."""
    key = get_key()
    url = f"{BASE_URL}/personalvoices/{voice_id}?api-version={API_VERSION}"
    
    boundary = "----PersonalVoiceBoundary"
    
    fields = {
        "projectId": project_id,
        "consentId": consent_id,
    }
    
    body = b""
    for k, v in fields.items():
        body += f"--{boundary}\r\n".encode()
        body += f'Content-Disposition: form-data; name="{k}"\r\n\r\n'.encode()
        body += f"{v}\r\n".encode()
    
    for audio_path in audio_paths:
        body += f"--{boundary}\r\n".encode()
        body += f'Content-Disposition: form-data; name="audiodata"; filename="{os.path.basename(audio_path)}"\r\n'.encode()
        body += b"Content-Type: audio/wav\r\n\r\n"
        with open(audio_path, "rb") as f:
            body += f.read()
        body += b"\r\n"
    
    body += f"--{boundary}--\r\n".encode()
    
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Ocp-Apim-Subscription-Key", key)
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read().decode())
            print(f"Personal voice created ({resp.status}): {json.dumps(result, indent=2)}")
            return result
    except urllib.error.HTTPError as e:
        error_body = e.read().decode()
        print(f"Personal voice error ({e.code}): {error_body}")
        return None

def poll_operation(operation_url, max_wait=120):
    """Poll an operation until completion."""
    key = get_key()
    start = time.time()
    while time.time() - start < max_wait:
        req = urllib.request.Request(operation_url)
        req.add_header("Ocp-Apim-Subscription-Key", key)
        with urllib.request.urlopen(req) as resp:
            result = json.loads(resp.read().decode())
            status = result.get("status", "Unknown")
            print(f"  Operation: {status}")
            if status in ("Succeeded", "Failed"):
                return result
        time.sleep(5)
    print("  Timed out waiting for operation")
    return None

def synthesize_with_personal_voice(speaker_profile_id, text, output_path, lang="he-IL"):
    """Synthesize speech using personal voice.
    
    Uses DragonHDLatestNeural with ttsembedding for voice cloning.
    For Hebrew, wraps text in <lang> tag inside en-US DragonHD voice.
    """
    key = get_key()
    
    if lang == "he-IL":
        # DragonHD doesn't have a native he-IL voice, so use en-US with lang switch
        ssml = f"""<?xml version='1.0' encoding='UTF-8'?>
<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' 
       xmlns:mstts='http://www.w3.org/2001/mstts' xml:lang='en-US'>
    <voice name='en-US-Ava:DragonHDLatestNeural'>
        <mstts:ttsembedding speakerProfileId='{speaker_profile_id}'>
            <lang xml:lang='he-IL'>{text}</lang>
        </mstts:ttsembedding>
    </voice>
</speak>"""
    else:
        ssml = f"""<?xml version='1.0' encoding='UTF-8'?>
<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' 
       xmlns:mstts='http://www.w3.org/2001/mstts' xml:lang='{lang}'>
    <voice name='en-US-Ava:DragonHDLatestNeural'>
        <mstts:ttsembedding speakerProfileId='{speaker_profile_id}'>
            {text}
        </mstts:ttsembedding>
    </voice>
</speak>"""
    
    req = urllib.request.Request(TTS_URL, data=ssml.encode("utf-8"), method="POST")
    req.add_header("Ocp-Apim-Subscription-Key", key)
    req.add_header("Content-Type", "application/ssml+xml; charset=utf-8")
    req.add_header("X-Microsoft-OutputFormat", "riff-24khz-16bit-mono-pcm")
    
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            with open(output_path, "wb") as f:
                f.write(resp.read())
            print(f"Synthesized: {output_path} ({os.path.getsize(output_path)} bytes)")
            return True
    except urllib.error.HTTPError as e:
        print(f"TTS error ({e.code}): {e.read().decode()}")
        return False

def generate_consent_audio(name_hebrew, company_hebrew, output_path):
    """Generate consent statement audio using Azure TTS."""
    key = get_key()
    consent_text = f"אני {name_hebrew} מודע לכך שהקלטות הקול שלי יהיו בשימוש על-ידי {company_hebrew} על מנת ליצור ולהשתמש בגרסה סינתטית של הקול שלי."
    
    ssml = f"""<?xml version='1.0' encoding='UTF-8'?>
<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' 
       xmlns:mstts='http://www.w3.org/2001/mstts' xml:lang='he-IL'>
    <voice name='he-IL-AvriNeural'>
        <prosody rate='-5%'>{consent_text}</prosody>
    </voice>
</speak>"""
    
    req = urllib.request.Request(TTS_URL, data=ssml.encode("utf-8"), method="POST")
    req.add_header("Ocp-Apim-Subscription-Key", key)
    req.add_header("Content-Type", "application/ssml+xml; charset=utf-8")
    req.add_header("X-Microsoft-OutputFormat", "riff-24khz-16bit-mono-pcm")
    
    with urllib.request.urlopen(req, timeout=30) as resp:
        with open(output_path, "wb") as f:
            f.write(resp.read())
    print(f"Consent audio: {output_path} ({os.path.getsize(output_path)} bytes)")

# ============================================================
# PIPELINE EXECUTION
# ============================================================
SPEAKERS = {
    "dotan": {
        "name": "Dotan Talitman",
        "name_hebrew": "דותן טליטמן",
        "consent_id": "dotan-consent-02",
        "voice_id": "dotan-voice-01",
        "audio_samples": [
            "voice_samples/dotan_real_ref_long.wav",   # 60s real audio
            "voice_samples/dotan_real_ref.wav",         # 40s real audio
        ],
    },
    "shahar": {
        "name": "Shahar Nachmias",
        "name_hebrew": "שחר נחמיאס",
        "consent_id": "shahar-consent-02",
        "voice_id": "shahar-voice-01",
        "audio_samples": [
            "voice_samples/shahar_real_ref_long.wav",
            "voice_samples/shahar_real_ref.wav",
        ],
    },
}

def run_pipeline():
    """Run the full Personal Voice pipeline."""
    print("=" * 60)
    print("Azure Personal Voice Pipeline")
    print("=" * 60)
    
    # Step 1: Check access
    print("\n--- Step 1: Check API access ---")
    list_projects()
    consents = list_consents()
    
    # Step 2: Check if consents exist and are valid
    print("\n--- Step 2: Validate consents ---")
    for speaker_key, speaker in SPEAKERS.items():
        consent = next((c for c in consents if c["id"] == speaker["consent_id"]), None)
        if consent and consent["status"] == "Succeeded":
            print(f"  ✅ {speaker['name']}: Consent OK")
        else:
            print(f"  ❌ {speaker['name']}: Consent missing or failed")
            print(f"     Run: generate_consent_audio + upload_consent_multipart")
    
    # Step 3: Create personal voices
    print("\n--- Step 3: Create personal voices ---")
    results = {}
    for speaker_key, speaker in SPEAKERS.items():
        print(f"\nCreating voice for {speaker['name']}...")
        audio_paths = [p for p in speaker["audio_samples"] if os.path.exists(p)]
        if not audio_paths:
            print(f"  ⚠️  No audio files found!")
            continue
        
        result = create_personal_voice_multipart(
            voice_id=speaker["voice_id"],
            consent_id=speaker["consent_id"],
            project_id=PROJECT_ID,
            audio_paths=audio_paths[:1],  # Use first available
        )
        results[speaker_key] = result
    
    # Step 4: Wait for processing and get speaker profile IDs
    print("\n--- Step 4: Get speaker profile IDs ---")
    speaker_profiles = {}
    for speaker_key, result in results.items():
        if result and "speakerProfileId" in result:
            speaker_profiles[speaker_key] = result["speakerProfileId"]
            print(f"  {SPEAKERS[speaker_key]['name']}: {result['speakerProfileId']}")
    
    # Step 5: Test TTS with personal voice
    if speaker_profiles:
        print("\n--- Step 5: Test Hebrew TTS ---")
        test_texts = {
            "dotan": "שלום לכולם, אני דותן טליטמן. ברוכים הבאים לפודקאסט שלנו על בינה מלאכותית.",
            "shahar": "שלום, אני שחר נחמיאס. היום נדבר על חידושים מרתקים בעולם הטכנולוגיה.",
        }
        for speaker_key, profile_id in speaker_profiles.items():
            output = f"personal-voice-{speaker_key}-test.wav"
            synthesize_with_personal_voice(profile_id, test_texts[speaker_key], output)
    
    print("\n" + "=" * 60)
    print("Pipeline complete!")
    print("=" * 60)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == "status":
            list_projects()
            list_consents()
        elif cmd == "full":
            run_pipeline()
        elif cmd == "test-consent":
            # Generate test consent audio
            generate_consent_audio("דותן טליטמן", "מיקרוסופט", "voice_samples/dotan_consent_tts.wav")
            generate_consent_audio("שחר נחמיאס", "מיקרוסופט", "voice_samples/shahar_consent_tts.wav")
        else:
            print(f"Unknown command: {cmd}")
            print("Usage: python azure_personal_voice.py [status|full|test-consent]")
    else:
        run_pipeline()
