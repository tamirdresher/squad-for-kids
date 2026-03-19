#!/usr/bin/env pwsh
# Podcaster — converts markdown/text to audio MP3
# Tries edge-tts (neural quality) first, falls back to Windows System.Speech
# Supports OpenAI TTS engines (tts-1, tts-1-hd) for higher-quality English narration.
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
#   ./scripts/podcaster.ps1 -InputFile RESEARCH_REPORT.md -PodcastMode -Deliver
#   ./scripts/podcaster.ps1 -InputFile RESEARCH_REPORT.md -Deliver -DeliverTo user@example.com
#   ./scripts/podcaster.ps1 -InputFile RESEARCH_REPORT.md -PodcastMode -NaturalSpeech
#   ./scripts/podcaster.ps1 -InputFile RESEARCH_REPORT.md -PodcastMode -NaturalSpeech -BackchannelFrequency 0.4
#   ./scripts/podcaster.ps1 -InputFile RESEARCH_REPORT.md -Engine tts-1-hd
#   ./scripts/podcaster.ps1 -InputFile RESEARCH_REPORT.md -Engine tts-1-hd -Voice nova
#
# TTS Engines:
#   edge-tts  (default) — Microsoft Edge neural voices, free, offline-capable
#   tts-1               — OpenAI TTS standard quality; requires OPENAI_API_KEY
#   tts-1-hd            — OpenAI TTS HD quality; best English narration; requires OPENAI_API_KEY
#   system              — Windows System.Speech fallback (lowest quality)

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
    [string]$Volume = "+0%",
    [switch]$Deliver,
    [string]$DeliverTo,
    [string]$PodcastTitle,
    [switch]$NaturalSpeech,
    [double]$BackchannelFrequency = 0.30,
    [ValidateSet("en", "he")]
    [string]$Language = "en",
    # TTS engine selection. Default: edge-tts (backward compatible).
    # Use tts-1 or tts-1-hd for OpenAI TTS (requires OPENAI_API_KEY env var).
    [ValidateSet("edge-tts", "tts-1", "tts-1-hd", "system")]
    [string]$Engine = "edge-tts"
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

function Invoke-OpenAITTS {
    param(
        [string]$Text,
        [string]$Output,
        [string]$Model = "tts-1-hd",
        # OpenAI voices: alloy, ash, ballad, coral, echo, fable, nova, onyx, sage, shimmer
        [string]$Voice = "alloy"
    )

    $apiKey = $env:OPENAI_API_KEY
    if (-not $apiKey) {
        Write-Host "  OPENAI_API_KEY environment variable not set — cannot use OpenAI TTS" -ForegroundColor Red
        return $false
    }

    $headers = @{
        "Authorization" = "Bearer $apiKey"
        "Content-Type"  = "application/json"
    }

    # OpenAI TTS limit is 4096 chars per request — split into sentence-aware chunks
    $maxChunk = 4000
    $chunks   = [System.Collections.Generic.List[string]]::new()
    $remaining = $Text.Trim()

    while ($remaining.Length -gt 0) {
        if ($remaining.Length -le $maxChunk) {
            $chunks.Add($remaining)
            break
        }
        $slice = $remaining.Substring(0, $maxChunk)
        # Find last sentence boundary within the slice
        $cut = [math]::Max(
            $slice.LastIndexOf('. '),
            [math]::Max($slice.LastIndexOf('! '), $slice.LastIndexOf('? '))
        )
        if ($cut -le 0) {
            # Fall back to last newline, then hard-cut
            $cut = $slice.LastIndexOf("`n")
            if ($cut -le 0) { $cut = $maxChunk }
        } else {
            $cut += 1   # include the trailing space so the boundary char stays in this chunk
        }
        $chunks.Add($remaining.Substring(0, $cut).Trim())
        $remaining = $remaining.Substring($cut).Trim()
    }

    Write-Host "  OpenAI TTS: $($chunks.Count) chunk(s), model=$Model, voice=$Voice" -ForegroundColor Gray

    if ($chunks.Count -eq 1) {
        try {
            $body = @{ model = $Model; input = $chunks[0]; voice = $Voice } | ConvertTo-Json -Compress
            Invoke-WebRequest -Uri "https://api.openai.com/v1/audio/speech" `
                -Method POST -Headers $headers -Body $body -OutFile $Output -ErrorAction Stop | Out-Null
            return $true
        } catch {
            Write-Host "  OpenAI TTS failed: $($_.Exception.Message)" -ForegroundColor Yellow
            return $false
        }
    }

    # Multiple chunks — need ffmpeg to concatenate
    $ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if (-not $ffmpeg) {
        Write-Host "  ffmpeg is required to concatenate multi-chunk OpenAI TTS output. Install ffmpeg and retry." -ForegroundColor Red
        return $false
    }

    $tempDir   = Join-Path $env:TEMP "podcaster_oai_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $tempFiles = [System.Collections.Generic.List[string]]::new()

    try {
        for ($i = 0; $i -lt $chunks.Count; $i++) {
            $chunkFile = Join-Path $tempDir "chunk_$i.mp3"
            $body      = @{ model = $Model; input = $chunks[$i]; voice = $Voice } | ConvertTo-Json -Compress
            Write-Host "  Rendering chunk $($i+1)/$($chunks.Count)..." -ForegroundColor Gray
            Invoke-WebRequest -Uri "https://api.openai.com/v1/audio/speech" `
                -Method POST -Headers $headers -Body $body -OutFile $chunkFile -ErrorAction Stop | Out-Null
            $tempFiles.Add($chunkFile)
        }

        # Build ffmpeg concat list
        $listFile = Join-Path $tempDir "filelist.txt"
        $tempFiles | ForEach-Object { "file '$_'" } | Set-Content $listFile -Encoding UTF8
        & ffmpeg -f concat -safe 0 -i $listFile -c copy $Output -y -loglevel quiet 2>$null
        if ($LASTEXITCODE -ne 0) { throw "ffmpeg concat failed (exit $LASTEXITCODE)" }
        return $true
    } catch {
        Write-Host "  OpenAI TTS failed: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    } finally {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
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
# DELIVERY
# ============================================================================

function Invoke-PodcastDelivery {
    param(
        [Parameter(Mandatory)][string]$AudioPath,
        [string]$Title,
        [string]$Recipient
    )

    if (-not (Test-Path $AudioPath)) {
        Write-Host "`n  Delivery skipped — audio file not found at $AudioPath" -ForegroundColor Yellow
        return
    }

    $deliverScript = Join-Path $PSScriptRoot "deliver-podcast.ps1"
    if (-not (Test-Path $deliverScript)) {
        Write-Host "`n  deliver-podcast.ps1 not found — run delivery manually:" -ForegroundColor Yellow
        Write-Host "    ./scripts/deliver-podcast.ps1 -AudioFile `"$AudioPath`"" -ForegroundColor Gray
        return
    }

    Write-Host "`n--- Delivering podcast ---" -ForegroundColor Cyan
    $deliverParams = @{ AudioFile = $AudioPath }
    if ($Title)     { $deliverParams.Title     = $Title }
    if ($Recipient) { $deliverParams.Recipient = $Recipient }

    & $deliverScript @deliverParams
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
    $suffix = if ($ConversationMode -or $PodcastMode) { "podcast" } else { "audio" }
    $OutputFile = Join-Path (Split-Path $inputPath) "$inputName-$suffix.mp3"
}

Write-Host "Input:  $inputPath"
Write-Host "Output: $OutputFile"
Write-Host "Engine: $Engine" -ForegroundColor Gray

# Conversation mode: delegate to the two-voice Python script
if ($ConversationMode) {
    Write-Host "`nConversation mode enabled — invoking podcaster-conversational.py" -ForegroundColor Cyan
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $convScript = Join-Path $scriptDir "podcaster-conversational.py"

    $env:PYTHONIOENCODING = "utf-8"
    $pyArgs = @("`"$convScript`"", "`"$inputPath`"", "-o", "`"$OutputFile`"", "--rate", $Rate, "--volume", $Volume, "--language", $Language)
    if ($Voice -ne "en-US-JennyNeural") {
        $pyArgs += @("--host-voice", $Voice)
    }

    $proc = Start-Process -FilePath "python" -ArgumentList ($pyArgs -join " ") -NoNewWindow -Wait -PassThru
    if ($proc.ExitCode -ne 0) { exit $proc.ExitCode }

    if ($Deliver -and (Test-Path $OutputFile)) {
        Invoke-PodcastDelivery -AudioPath $OutputFile -Title $PodcastTitle -Recipient $DeliverTo
    }
    exit 0
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

        & python $genScript $inputPath -o $podcastScript --language $Language
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Script generation failed" -ForegroundColor Red
            exit 1
        }

        # Apply natural speech post-processing (issue #464)
        if ($NaturalSpeech -or $BackchannelFrequency -gt 0) {
            $postArgs = @($genScript, $inputPath, "-o", $podcastScript)
            if ($NaturalSpeech) { $postArgs += "--natural-speech" }
            if ($BackchannelFrequency -gt 0) {
                $postArgs += @("--backchannels", "--backchannel-frequency", $BackchannelFrequency)
            }
            & python @postArgs
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  Post-processing failed, using original script" -ForegroundColor Yellow
            }
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

    & python $convScript --script $podcastScript -o $OutputFile --rate $Rate --volume $Volume --language $Language
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Audio rendering failed" -ForegroundColor Red
        exit 1
    }

    if (Test-Path $OutputFile) {
        $size = (Get-Item $OutputFile).Length
        $sizeMB = [math]::Round($size / 1MB, 2)
        Write-Host "`n Podcast generated: $OutputFile ($sizeMB MB)" -ForegroundColor Green

        if ($Deliver) {
            Invoke-PodcastDelivery -AudioPath $OutputFile -Title $PodcastTitle -Recipient $DeliverTo
        }
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
    if ($Engine -in @("tts-1", "tts-1-hd")) {
        # Map edge-tts default voice → OpenAI default; otherwise use caller-supplied value
        $oaiVoice = if ($Voice -eq "en-US-JennyNeural") { "alloy" } else { $Voice }
        Write-Host "`nUsing OpenAI TTS (model: $Engine, voice: $oaiVoice)..." -ForegroundColor Cyan
        $success = Invoke-OpenAITTS -Text $plainText -Output $OutputFile -Model $Engine -Voice $oaiVoice
        if (-not $success) {
            Write-Host "  OpenAI TTS failed — falling back to edge-tts" -ForegroundColor Yellow
        }
    }

    if (-not $success -and $Engine -ne "system") {
        Write-Host "`nTrying edge-tts (neural quality)..." -ForegroundColor Cyan
        $success = Invoke-EdgeTTS -Text $plainText -Output $OutputFile -Voice $Voice -Rate $Rate -Volume $Volume
    }
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

    if ($Deliver) {
        Invoke-PodcastDelivery -AudioPath $OutputFile -Title $PodcastTitle -Recipient $DeliverTo
    }
} else {
    Write-Host "`n Failed to generate audio" -ForegroundColor Red
    exit 1
}
