#!/usr/bin/env pwsh
# Podcaster — converts markdown/text to audio MP3
# Tries edge-tts (neural quality) first, falls back to Windows System.Speech
#
# Usage:
#   ./scripts/podcaster.ps1 -InputFile RESEARCH_REPORT.md
#   ./scripts/podcaster.ps1 -InputFile RESEARCH_REPORT.md -OutputFile briefing.mp3
#   ./scripts/podcaster.ps1 -InputFile RESEARCH_REPORT.md -Voice en-US-GuyNeural
#   ./scripts/podcaster.ps1 -InputFile RESEARCH_REPORT.md -ForceFallback
#   ./scripts/podcaster.ps1 -InputFile RESEARCH_REPORT.md -ConversationMode
#   ./scripts/podcaster.ps1 -InputFile RESEARCH_REPORT.md -PodcastMode
#   ./scripts/podcaster.ps1 -InputFile RESEARCH_REPORT.md -PodcastMode -ScriptFile my-script.txt
#   ./scripts/podcaster.ps1 -InputFile RESEARCH_REPORT.md -Rate "+10%" -Volume "+50%"

param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,
    [string]$OutputFile,
    [string]$Voice = "en-US-JennyNeural",
    [switch]$ForceFallback,
    [switch]$ConversationMode,
    [switch]$PodcastMode,
    [string]$ScriptFile,
    [string]$Rate = "+0%",
    [string]$Volume = "+0%"
)

$ErrorActionPreference = "Stop"

# ============================================================================
# MARKDOWN STRIPPING
# ============================================================================

function ConvertFrom-Markdown {
    param([string]$Text)
    $t = $Text
    # YAML frontmatter
    $t = $t -replace '(?s)^---\n.*?\n---\n', ''
    # HTML comments
    $t = $t -replace '(?s)<!--.*?-->', ''
    # Code blocks
    $t = $t -replace '(?s)```.*?```', ''
    $t = $t -replace '`[^`]+`', ''
    # Images
    $t = $t -replace '!\[([^\]]*)\]\([^)]+\)', '$1'
    # Links (keep text)
    $t = $t -replace '\[([^\]]+)\]\([^)]+\)', '$1'
    # Headers (keep text)
    $t = $t -replace '(?m)^#{1,6}\s+', ''
    # Bold/italic
    $t = $t -replace '\*\*([^*]+)\*\*', '$1'
    $t = $t -replace '\*([^*]+)\*', '$1'
    $t = $t -replace '__([^_]+)__', '$1'
    # Horizontal rules
    $t = $t -replace '(?m)^[-*_]{3,}\s*$', ''
    # Blockquotes
    $t = $t -replace '(?m)^>\s+', ''
    # List markers
    $t = $t -replace '(?m)^[\*\-\+]\s+', ''
    $t = $t -replace '(?m)^\d+\.\s+', ''
    # Tables (remove pipe formatting)
    $t = $t -replace '\|', ' '
    $t = $t -replace '(?m)^[-:]+\s*$', ''
    # Multiple newlines
    $t = $t -replace '\n{3,}', "`n`n"
    return $t.Trim()
}

# ============================================================================
# TTS ENGINES
# ============================================================================

function Invoke-EdgeTTS {
    param([string]$Text, [string]$Output, [string]$Voice, [string]$Rate = "+0%", [string]$Volume = "+0%")

    $tempText = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tempText, $Text, [System.Text.Encoding]::UTF8)

    try {
        $args = "--file `"$tempText`" --write-media `"$Output`" --voice $Voice --rate=$Rate --volume=$Volume"
        $proc = Start-Process -FilePath "edge-tts" -ArgumentList $args -NoNewWindow -Wait -PassThru -ErrorAction Stop
        if ($proc.ExitCode -ne 0) { throw "edge-tts exited with code $($proc.ExitCode)" }
        return $true
    } catch {
        Write-Host "  edge-tts failed: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    } finally {
        Remove-Item $tempText -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-SystemSpeech {
    param([string]$Text, [string]$Output)

    Add-Type -AssemblyName System.Speech
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer

    # Use best available voice
    $voices = $synth.GetInstalledVoices() | Where-Object { $_.Enabled }
    $preferred = $voices | Where-Object { $_.VoiceInfo.Name -match "Zira|David|Jenny|Eva" } | Select-Object -First 1
    if ($preferred) {
        $synth.SelectVoice($preferred.VoiceInfo.Name)
        Write-Host "  Using voice: $($preferred.VoiceInfo.Name)"
    }

    # Save as WAV first (System.Speech only does WAV)
    $wavFile = [System.IO.Path]::ChangeExtension($Output, ".wav")
    $synth.SetOutputToWaveFile($wavFile)
    $synth.Speak($Text)
    $synth.Dispose()

    # Convert WAV to MP3 if ffmpeg is available
    $ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($ffmpeg) {
        & ffmpeg -i $wavFile -codec:a libmp3lame -qscale:a 4 $Output -y -loglevel quiet 2>$null
        Remove-Item $wavFile -Force -ErrorAction SilentlyContinue
        Write-Host "  Converted to MP3 via ffmpeg"
    } else {
        # No ffmpeg — rename WAV to the output path (change extension)
        $Output = [System.IO.Path]::ChangeExtension($Output, ".wav")
        Move-Item $wavFile $Output -Force
        Write-Host "  Saved as WAV (install ffmpeg for MP3 conversion)"
    }

    return $Output
}

# ============================================================================
# MAIN
# ============================================================================

Write-Host ""
Write-Host "=== Podcaster ===" -ForegroundColor Cyan

# Resolve paths
$inputPath = Resolve-Path $InputFile -ErrorAction Stop
$inputName = [System.IO.Path]::GetFileNameWithoutExtension($inputPath)
if (-not $OutputFile) {
    $OutputFile = Join-Path (Split-Path $inputPath) "$inputName-audio.mp3"
}

Write-Host "Input:  $inputPath"
Write-Host "Output: $OutputFile"

# Conversation mode: delegate to the two-voice Python script
if ($ConversationMode) {
    Write-Host "`nConversation mode enabled — invoking podcaster-conversational.py" -ForegroundColor Cyan
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $convScript = Join-Path $scriptDir "podcaster-conversational.py"

    $env:PYTHONIOENCODING = "utf-8"
    $pyArgs = @("`"$convScript`"", "`"$inputPath`"", "--rate", $Rate, "--volume", $Volume)
    if ($Voice -ne "en-US-JennyNeural") {
        $pyArgs += @("--host-voice", $Voice)
    }

    $proc = Start-Process -FilePath "python" -ArgumentList ($pyArgs -join " ") -NoNewWindow -Wait -PassThru
    exit $proc.ExitCode
}

# ============================================================================
# PODCAST MODE — Full pipeline: generate conversation script → render audio
# ============================================================================

if ($PodcastMode) {
    Write-Host "`n=== Podcast Mode (full pipeline) ===" -ForegroundColor Magenta
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $env:PYTHONIOENCODING = "utf-8"

    # Step 1: Generate or use existing conversation script
    $podcastScript = $ScriptFile
    if (-not $podcastScript) {
        Write-Host "`nPhase 1: Generating conversation script..." -ForegroundColor Cyan
        $genScript = Join-Path $scriptDir "generate-podcast-script.py"
        $podcastScript = [System.IO.Path]::ChangeExtension($inputPath, ".podcast-script.txt")

        & python $genScript $inputPath -o $podcastScript
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Script generation failed" -ForegroundColor Red
            exit 1
        }
        if (-not (Test-Path $podcastScript)) {
            Write-Host "  Script file not created" -ForegroundColor Red
            exit 1
        }
        Write-Host "  Script: $podcastScript" -ForegroundColor Green
    } else {
        Write-Host "`nPhase 1: Using provided script: $podcastScript" -ForegroundColor Cyan
    }

    # Step 2: Render multi-voice audio
    Write-Host "`nPhase 2: Rendering multi-voice audio..." -ForegroundColor Cyan
    $convScript = Join-Path $scriptDir "podcaster-conversational.py"
    if (-not $OutputFile) {
        $OutputFile = Join-Path (Split-Path $inputPath) "$inputName-podcast.mp3"
    }

    & python $convScript --script $podcastScript -o $OutputFile --rate $Rate --volume $Volume
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Audio rendering failed" -ForegroundColor Red
        exit 1
    }

    if (Test-Path $OutputFile) {
        $size = (Get-Item $OutputFile).Length
        $sizeMB = [math]::Round($size / 1MB, 2)
        Write-Host "`n Podcast generated: $OutputFile ($sizeMB MB)" -ForegroundColor Green
    } else {
        Write-Host "`n Failed to generate podcast" -ForegroundColor Red
        exit 1
    }
    exit 0
}

# Read and strip markdown
$raw = Get-Content $inputPath -Raw -Encoding utf8
$plainText = ConvertFrom-Markdown -Text $raw
$wordCount = ($plainText -split '\s+').Count
$estMinutes = [math]::Round($wordCount / 150, 1)

Write-Host "Words:  $wordCount (~${estMinutes} min audio)" -ForegroundColor Gray

# Truncate if very long (TTS services have limits)
if ($plainText.Length -gt 100000) {
    Write-Host "Truncating to 100K chars for TTS..." -ForegroundColor Yellow
    $plainText = $plainText.Substring(0, 100000)
}

# Try edge-tts first (neural quality), fall back to System.Speech
$success = $false

if (-not $ForceFallback) {
    Write-Host "`nTrying edge-tts (neural quality)..." -ForegroundColor Cyan
    $success = Invoke-EdgeTTS -Text $plainText -Output $OutputFile -Voice $Voice -Rate $Rate -Volume $Volume
}

if (-not $success) {
    Write-Host "`nFalling back to Windows System.Speech..." -ForegroundColor Yellow
    $OutputFile = Invoke-SystemSpeech -Text $plainText -Output $OutputFile
}

# Report results
if (Test-Path $OutputFile) {
    $size = (Get-Item $OutputFile).Length
    $sizeMB = [math]::Round($size / 1MB, 2)
    Write-Host "`n Audio generated: $OutputFile ($sizeMB MB)" -ForegroundColor Green
} else {
    Write-Host "`n Failed to generate audio" -ForegroundColor Red
    exit 1
}
