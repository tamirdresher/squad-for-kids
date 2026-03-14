# Generate News Image via Google Gemini API
# Used by Neelix news broadcasts to create themed images for Teams messages.
# Returns base64-encoded image data URI suitable for Adaptive Card embedding.
#
# Requires: $env:GOOGLE_API_KEY (Gemini API key)
# Output: Saves image to disk and returns base64 data URI string
#
# Usage:
#   $dataUri = & .\scripts\generate-news-image.ps1 -Prompt "A bold news banner about CI pipeline success"
#   $dataUri = & .\scripts\generate-news-image.ps1 -Prompt "Funny meme about code reviews" -Style "meme"
#   $dataUri = & .\scripts\generate-news-image.ps1 -Headline "Sprint Velocity Up 20%" -Style "banner"

param(
    [Parameter(Mandatory=$false)]
    [string]$Prompt,

    [Parameter(Mandatory=$false)]
    [string]$Headline,

    [Parameter(Mandatory=$false)]
    [ValidateSet("banner", "meme", "status", "custom")]
    [string]$Style = "banner",

    [string]$OutputDir = "$env:USERPROFILE\Documents\nano-banana-images\neelix",

    [int]$MaxWidthPx = 800,

    [switch]$ReturnPath
)

$ErrorActionPreference = "Stop"

# ==================== API KEY CHECK ====================

$apiKey = $env:GOOGLE_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    Write-Warning "GOOGLE_API_KEY not set — skipping image generation"
    return $null
}

# ==================== PROMPT CONSTRUCTION ====================

# Build the prompt based on style if no custom prompt provided
if ([string]::IsNullOrWhiteSpace($Prompt)) {
    switch ($Style) {
        "banner" {
            if ([string]::IsNullOrWhiteSpace($Headline)) {
                Write-Warning "Banner style requires -Headline parameter"
                return $null
            }
            $Prompt = @"
A bold, modern news broadcast banner image. Theme: '$Headline'.
Clean flat design, blue and gold color scheme, 16:9 aspect ratio.
Professional tech news style with clean typography. No text overlay.
Suitable for a daily tech team status briefing.
"@
        }
        "meme" {
            if ([string]::IsNullOrWhiteSpace($Headline)) {
                Write-Warning "Meme style requires -Headline parameter"
                return $null
            }
            $Prompt = @"
A funny, lighthearted illustration about: '$Headline'.
Office humor style, bright colors, exaggerated cartoon expressions.
Suitable for a tech team chat. Fun and professional, not offensive.
No text in the image.
"@
        }
        "status" {
            if ([string]::IsNullOrWhiteSpace($Headline)) {
                Write-Warning "Status style requires -Headline parameter"
                return $null
            }
            $Prompt = @"
A clean, minimal infographic-style illustration representing: '$Headline'.
Data visualization aesthetic, dark background with green/blue accent colors.
Modern dashboard feel. No text in the image.
"@
        }
        "custom" {
            if ([string]::IsNullOrWhiteSpace($Prompt)) {
                Write-Warning "Custom style requires -Prompt parameter"
                return $null
            }
        }
    }
}

# ==================== GENERATE IMAGE ====================

Write-Host "  🎨 Generating news image ($Style)..." -ForegroundColor Magenta

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFile = Join-Path $OutputDir "neelix-$Style-$timestamp.png"

# Call Gemini API (gemini-2.0-flash model with image generation)
$uri = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$apiKey"

$requestBody = @{
    contents = @(
        @{
            parts = @(
                @{
                    text = $Prompt
                }
            )
        }
    )
    generationConfig = @{
        responseModalities = @("TEXT", "IMAGE")
    }
} | ConvertTo-Json -Depth 10

try {
    $response = Invoke-RestMethod -Uri $uri -Method Post -Body $requestBody -ContentType "application/json" -TimeoutSec 60

    # Extract image data from response
    $imageData = $null
    $mimeType = "image/png"

    foreach ($candidate in $response.candidates) {
        foreach ($part in $candidate.content.parts) {
            if ($part.inlineData) {
                $imageData = $part.inlineData.data
                $mimeType = $part.inlineData.mimeType
                break
            }
        }
        if ($imageData) { break }
    }

    if (-not $imageData) {
        Write-Warning "Gemini returned no image data — broadcast will continue without image"
        return $null
    }

    # Save to disk
    $imageBytes = [Convert]::FromBase64String($imageData)
    [System.IO.File]::WriteAllBytes($outputFile, $imageBytes)
    Write-Host "  ✅ Image saved: $outputFile" -ForegroundColor Green

    if ($ReturnPath) {
        return $outputFile
    }

    # Return data URI for Adaptive Card embedding
    $dataUri = "data:$mimeType;base64,$imageData"

    # Check size — Adaptive Cards have ~1MB limit for inline images
    $sizeKB = [math]::Round($imageData.Length / 1024)
    if ($sizeKB -gt 900) {
        Write-Warning "Image is ${sizeKB}KB — may be too large for inline embedding. Consider using blob storage."
    } else {
        Write-Host "  📦 Image size: ${sizeKB}KB (OK for inline)" -ForegroundColor Gray
    }

    return $dataUri

} catch {
    Write-Warning "Image generation failed: $($_.Exception.Message) — broadcast will continue without image"
    return $null
}
