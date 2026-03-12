$decPath = ".squad/decisions.md"
$belannaPath = ".squad/decisions/inbox/belanna-powerautomate-347.md"
$picardPath = ".squad/decisions/inbox/picard-multi-ralph-triage.md"

$dec = Get-Content $decPath -Raw
$bel = Get-Content $belannaPath -Raw
$pic = Get-Content $picardPath -Raw

$merged = $dec + "`n`n---`n`n# DECISIONS MERGED FROM INBOX (2026-03-12T06:25:00Z)`n`n## [inbox] Issue #347: Power Automate Flow Investigation — B'Elanna`n`n" + $bel + "`n`n---`n`n## [inbox] Multi-Machine Ralph Phase 1 MVP — Picard Triage`n`n" + $pic

$merged | Set-Content -Path $decPath -Encoding UTF8
Write-Host "✅ Merged 2 inbox files to decisions.md"
