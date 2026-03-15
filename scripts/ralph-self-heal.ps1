#Requires -Version 7
<#
.SYNOPSIS
    Ralph Self-Healing: Automated gh auth refresh via Playwright MCP browser automation.

.DESCRIPTION
    Detects missing GitHub CLI scopes from `gh auth status` output, runs `gh auth refresh -s <scope>`
    to trigger device flow, captures the one-time code, then uses Playwright browser automation
    to navigate to https://github.com/login/device, enter the code, and approve.

    Designed for unattended DevBox environments where Ralph needs to fix its own auth.

.PARAMETER RequiredScopes
    Array of OAuth scopes that must be present. Defaults to common scopes Ralph needs.

.PARAMETER DryRun
    If set, logs what would happen but doesn't actually run the refresh flow.

.EXAMPLE
    .\scripts\ralph-self-heal.ps1
    .\scripts\ralph-self-heal.ps1 -RequiredScopes @('read:org','project')
#>
param(
    [string[]]$RequiredScopes = @(),
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$script:LogPrefix = "[ralph-self-heal]"
$script:LogFile = Join-Path $env:USERPROFILE ".squad\ralph-self-heal.log"

function Write-HealLog {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    $entry = "$ts | $Level | $Message"
    Write-Host "$script:LogPrefix $entry" -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARN"  { "Yellow" }
            "OK"    { "Green" }
            default { "Cyan" }
        }
    )
    # Append to log file
    $logDir = Split-Path $script:LogFile -Parent
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    Add-Content -Path $script:LogFile -Value $entry -Encoding utf8 -ErrorAction SilentlyContinue
}

function Get-GhAuthStatus {
    <#
    .SYNOPSIS
        Runs gh auth status and parses the output for token scopes.
    .OUTPUTS
        Hashtable with keys: Authenticated (bool), Scopes (string[]), RawOutput (string)
    #>
    $result = @{
        Authenticated = $false
        Scopes = @()
        RawOutput = ""
        Account = ""
    }

    try {
        # gh auth status writes to stderr, capture both streams
        $output = & gh auth status 2>&1 | Out-String
        $result.RawOutput = $output

        if ($output -match "Logged in to github\.com") {
            $result.Authenticated = $true
        }

        # Parse scopes: line like "- Token scopes: 'repo', 'read:org', 'project'"
        if ($output -match "Token scopes:\s*(.+)") {
            $scopesStr = $Matches[1].Trim()
            # Scopes are comma-separated, possibly quoted
            $result.Scopes = $scopesStr -split "[,\s]+" | ForEach-Object { $_.Trim().Trim("'", '"', ' ') } | Where-Object { $_ -ne "" }
        }

        # Parse account
        if ($output -match "account\s+(\S+)") {
            $result.Account = $Matches[1]
        }
    }
    catch {
        Write-HealLog "Failed to run gh auth status: $_" "ERROR"
    }

    return $result
}

function Get-MissingScopes {
    param(
        [string[]]$CurrentScopes,
        [string[]]$RequiredScopes
    )
    $missing = @()
    foreach ($scope in $RequiredScopes) {
        if ($scope -notin $CurrentScopes) {
            $missing += $scope
        }
    }
    return $missing
}

function Invoke-GhAuthRefresh {
    <#
    .SYNOPSIS
        Runs gh auth refresh for a missing scope and captures the device code.
    .OUTPUTS
        Hashtable with DeviceCode (string) and Success (bool)
    #>
    param([string]$Scope)

    $result = @{
        DeviceCode = ""
        Success = $false
    }

    Write-HealLog "Running: gh auth refresh -s $Scope" "INFO"

    # gh auth refresh -s <scope> outputs to stderr:
    # ! First copy your one-time code: XXXX-XXXX
    # Then press Enter to open github.com in your browser...
    # We need to capture the code and NOT press enter (we'll use Playwright instead)

    $tempFile = Join-Path $env:TEMP "ralph-gh-auth-refresh-$(Get-Random).txt"

    try {
        # Start the process and capture output, pipe 'n' to skip the browser open prompt
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "gh"
        $psi.Arguments = "auth refresh -s $Scope"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.RedirectStandardInput = $true
        $psi.CreateNoWindow = $true

        $process = [System.Diagnostics.Process]::Start($psi)

        # Read stderr in background (that's where the code appears)
        $stderrTask = $process.StandardError.ReadToEndAsync()

        # Wait a moment for the code to appear, then press Enter to proceed
        Start-Sleep -Seconds 3

        # Send Enter to proceed with the flow (gh will wait for browser auth)
        $process.StandardInput.WriteLine("")
        $process.StandardInput.Close()

        # Wait for process with timeout (120 seconds for browser auth)
        $completed = $process.WaitForExit(120000)

        $stderr = $stderrTask.Result
        $stdout = $process.StandardOutput.ReadToEnd()
        $allOutput = "$stdout`n$stderr"

        Write-HealLog "gh auth refresh output: $($allOutput.Substring(0, [Math]::Min(300, $allOutput.Length)))" "INFO"

        # Parse the one-time code
        if ($allOutput -match "one-time code:\s*([A-Z0-9]{4}-[A-Z0-9]{4})") {
            $result.DeviceCode = $Matches[1]
            $result.Success = $true
            Write-HealLog "Captured device code: $($result.DeviceCode)" "OK"
        }
        elseif ($allOutput -match "([A-Z0-9]{4}-[A-Z0-9]{4})") {
            $result.DeviceCode = $Matches[1]
            $result.Success = $true
            Write-HealLog "Captured device code (fallback regex): $($result.DeviceCode)" "OK"
        }
        else {
            Write-HealLog "Could not parse device code from gh auth refresh output" "ERROR"
        }

        if (-not $completed) {
            Write-HealLog "gh auth refresh timed out — will attempt Playwright flow anyway" "WARN"
        }
    }
    catch {
        Write-HealLog "Error running gh auth refresh: $_" "ERROR"
    }
    finally {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }

    return $result
}

function Invoke-PlaywrightDeviceAuth {
    <#
    .SYNOPSIS
        Uses Playwright MCP browser automation to enter a device code on github.com/login/device.
    .DESCRIPTION
        This function is designed to be called from within a Copilot CLI session where Playwright
        MCP tools are available. When running standalone, it generates a Copilot prompt that
        can be executed to perform the browser automation.
    .PARAMETER DeviceCode
        The XXXX-XXXX format device code from gh auth refresh.
    #>
    param([string]$DeviceCode)

    Write-HealLog "Starting Playwright device auth flow for code: $DeviceCode" "INFO"

    # Generate the automation script as a Copilot prompt
    # This will be fed to agency copilot to execute with Playwright MCP tools
    $playwrightPrompt = @"
URGENT SELF-HEALING TASK — complete this NOW before doing anything else:

1. Navigate to https://github.com/login/device using playwright-browser_navigate
2. Take a snapshot with playwright-browser_snapshot to see the page state
3. The page has input field(s) for a device code. The code is: $DeviceCode
4. If there's a single input field, type the full code "$DeviceCode" into it
5. If there are two input fields (split code), type the first 4 chars "${DeviceCode.Substring(0,4)}" in the first field and the last 4 chars "${DeviceCode.Substring(5,4)}" in the second field
6. Use playwright-browser_type or playwright-browser_fill_form to enter the code
7. Click the Continue/Submit button using playwright-browser_click
8. Take another snapshot to verify the page state
9. If you see an "Authorize" button, click it
10. If you see a login page instead, that means we need to log in first — take a snapshot and report what you see
11. Wait for confirmation that authorization was successful
12. Report SUCCESS or FAILURE

Do NOT do any other work. Complete this device code entry flow and report the result.
"@

    # Write the prompt to a temp file for agency copilot to consume
    $promptFile = Join-Path $env:TEMP "ralph-playwright-auth-prompt.txt"
    $playwrightPrompt | Out-File -FilePath $promptFile -Encoding utf8 -Force

    Write-HealLog "Playwright prompt written to: $promptFile" "INFO"

    # Try to run via agency copilot if available
    try {
        $agencyAvailable = Get-Command agency -ErrorAction SilentlyContinue
        if ($agencyAvailable) {
            Write-HealLog "Running Playwright auth flow via agency copilot..." "INFO"
            $sessionId = [guid]::NewGuid().ToString()
            $authResult = agency copilot --yolo --autopilot -p $playwrightPrompt "--resume=$sessionId" 2>&1 | Out-String
            Write-HealLog "Playwright auth result: $($authResult.Substring(0, [Math]::Min(500, $authResult.Length)))" "INFO"

            if ($authResult -match "SUCCESS|authorized|successfully") {
                Write-HealLog "Playwright device auth completed successfully" "OK"
                return $true
            }
            else {
                Write-HealLog "Playwright device auth may not have succeeded — check output" "WARN"
                return $false
            }
        }
        else {
            Write-HealLog "agency CLI not available — prompt saved to $promptFile for manual execution" "WARN"
            return $false
        }
    }
    catch {
        Write-HealLog "Error during Playwright auth flow: $_" "ERROR"
        return $false
    }
    finally {
        # Clean up temp file
        Remove-Item $promptFile -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-SelfHeal {
    <#
    .SYNOPSIS
        Main self-healing entry point. Checks auth, detects missing scopes, runs refresh + Playwright.
    .OUTPUTS
        Hashtable: Healed (bool), Action (string), Details (string)
    #>
    param(
        [string[]]$RequiredScopes = @()
    )

    $result = @{
        Healed = $false
        Action = "none"
        Details = ""
    }

    Write-HealLog "=== Self-healing check started ===" "INFO"

    # Step 1: Check current auth status
    $authStatus = Get-GhAuthStatus
    if (-not $authStatus.Authenticated) {
        Write-HealLog "gh is NOT authenticated — this requires manual intervention" "ERROR"
        $result.Action = "manual_auth_required"
        $result.Details = "gh CLI is not authenticated. Run 'gh auth login' manually."
        return $result
    }

    Write-HealLog "Authenticated as: $($authStatus.Account)" "OK"
    Write-HealLog "Current scopes: $($authStatus.Scopes -join ', ')" "INFO"

    # Step 2: Check for missing scopes
    if ($RequiredScopes.Count -eq 0) {
        Write-HealLog "No required scopes specified — auth check passed" "OK"
        $result.Action = "no_action"
        $result.Details = "Auth is valid, no specific scopes required."
        $result.Healed = $true
        return $result
    }

    $missingScopes = Get-MissingScopes -CurrentScopes $authStatus.Scopes -RequiredScopes $RequiredScopes
    if ($missingScopes.Count -eq 0) {
        Write-HealLog "All required scopes present — no healing needed" "OK"
        $result.Action = "no_action"
        $result.Details = "All required scopes are present."
        $result.Healed = $true
        return $result
    }

    Write-HealLog "Missing scopes detected: $($missingScopes -join ', ')" "WARN"

    # Step 3: Attempt to refresh auth for each missing scope
    foreach ($scope in $missingScopes) {
        Write-HealLog "Attempting to add scope: $scope" "INFO"

        if ($DryRun) {
            Write-HealLog "[DRY RUN] Would run: gh auth refresh -s $scope" "INFO"
            continue
        }

        $refreshResult = Invoke-GhAuthRefresh -Scope $scope
        if (-not $refreshResult.Success) {
            Write-HealLog "Failed to initiate auth refresh for scope: $scope" "ERROR"
            $result.Action = "refresh_failed"
            $result.Details = "Could not start auth refresh for scope '$scope'."
            return $result
        }

        # Step 4: Use Playwright to complete the device flow
        $playwrightSuccess = Invoke-PlaywrightDeviceAuth -DeviceCode $refreshResult.DeviceCode
        if (-not $playwrightSuccess) {
            Write-HealLog "Playwright device auth flow did not confirm success for scope: $scope" "WARN"
            # Don't return yet — verify with gh auth status below
        }

        # Brief pause for GitHub to process the authorization
        Start-Sleep -Seconds 5
    }

    # Step 5: Verify the fix
    Write-HealLog "Verifying auth status after healing..." "INFO"
    $postAuthStatus = Get-GhAuthStatus
    $stillMissing = Get-MissingScopes -CurrentScopes $postAuthStatus.Scopes -RequiredScopes $RequiredScopes

    if ($stillMissing.Count -eq 0) {
        Write-HealLog "All scopes successfully added!" "OK"
        $result.Healed = $true
        $result.Action = "scopes_added"
        $result.Details = "Successfully added scopes: $($missingScopes -join ', ')"
    }
    else {
        Write-HealLog "Some scopes still missing after healing: $($stillMissing -join ', ')" "ERROR"
        $result.Action = "partial_heal"
        $result.Details = "Added some scopes but still missing: $($stillMissing -join ', ')"
    }

    Write-HealLog "=== Self-healing check completed ===" "INFO"
    return $result
}

function Test-GhCliHealth {
    <#
    .SYNOPSIS
        Quick health check for gh CLI — can it run basic commands without errors?
    .OUTPUTS
        Hashtable: Healthy (bool), Error (string)
    #>
    $result = @{
        Healthy = $false
        Error = ""
    }

    try {
        $testOutput = & gh api user 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            $result.Healthy = $true
        }
        else {
            $result.Error = $testOutput.Trim()
            # Check for specific scope errors
            if ($testOutput -match "missing.*scope|insufficient.*scope|403|insufficient_scope") {
                Write-HealLog "Detected scope-related error: $($result.Error.Substring(0, [Math]::Min(200, $result.Error.Length)))" "WARN"
            }
        }
    }
    catch {
        $result.Error = $_.Exception.Message
    }

    return $result
}

# --- Main execution ---
if ($MyInvocation.InvocationName -ne '.') {
    # Script is being run directly (not dot-sourced)
    $healResult = Invoke-SelfHeal -RequiredScopes $RequiredScopes
    Write-HealLog "Result: Action=$($healResult.Action), Healed=$($healResult.Healed), Details=$($healResult.Details)" "INFO"

    # Return result for callers
    return $healResult
}
