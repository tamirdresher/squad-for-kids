<#
.SYNOPSIS
    ADC MCP Helper - Invoke ADC Management API tools via MCP protocol
.DESCRIPTION
    Provides Invoke-AdcMcp function for calling ADC sandbox management tools.
    API key is retrieved from Windows Credential Manager (ADC_API_KEY).
.EXAMPLE
    . .\.squad\skills\adc-sandbox\adc-mcp.ps1
    Invoke-AdcMcp "list_sandboxes" @{}
    Invoke-AdcMcp "execute_command" @{ sandboxId = "d342b3dc-..."; command = "uname -a" }
#>

$script:AdcMcpEndpoint = "https://management.agentdevcompute.io/mcp"
$script:AdcApiKey = $null
$script:AdcInitialized = $false

function Get-AdcApiKey {
    if ($script:AdcApiKey) { return $script:AdcApiKey }
    # Try environment variable first
    if ($env:ADC_API_KEY) { $script:AdcApiKey = $env:ADC_API_KEY; return $script:AdcApiKey }
    # Try Windows Credential Manager
    $cmdkey = cmdkey /list:ADC_API_KEY 2>&1 | Out-String
    if ($cmdkey -match 'ADC_API_KEY') {
        Write-Warning "ADC_API_KEY found in Credential Manager but password extraction requires .NET interop. Set `$env:ADC_API_KEY manually."
    }
    throw "ADC API key not found. Set `$env:ADC_API_KEY or store in Windows Credential Manager as ADC_API_KEY."
}

function Initialize-AdcMcp {
    if ($script:AdcInitialized) { return }
    $key = Get-AdcApiKey
    $h = @{ "x-api-key" = $key; "Content-Type" = "application/json"; "Accept" = "application/json, text/event-stream" }
    $init = @{
        jsonrpc = "2.0"; method = "initialize"; id = 0
        params = @{
            protocolVersion = "2024-11-05"; capabilities = @{}
            clientInfo = @{ name = "squad-adc-skill"; version = "1.0" }
        }
    } | ConvertTo-Json -Depth 4
    $null = Invoke-WebRequest -Uri $script:AdcMcpEndpoint -Headers $h -Method POST -Body $init -ErrorAction Stop
    $script:AdcInitialized = $true
    Write-Host "ADC MCP initialized (adc-mcp-server v1.0.0)" -ForegroundColor Green
}

function Invoke-AdcMcp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ToolName,
        [Parameter(Mandatory)][hashtable]$Arguments,
        [int]$Id = 1
    )
    Initialize-AdcMcp
    $key = Get-AdcApiKey
    $h = @{ "x-api-key" = $key; "Content-Type" = "application/json"; "Accept" = "application/json, text/event-stream" }
    $body = @{
        jsonrpc = "2.0"; method = "tools/call"; id = $Id
        params = @{ name = $ToolName; arguments = $Arguments }
    } | ConvertTo-Json -Depth 10

    $response = Invoke-WebRequest -Uri $script:AdcMcpEndpoint -Headers $h -Method POST -Body $body -ErrorAction Stop
    $dataLine = ($response.Content -split "`n" | Where-Object { $_ -match '^data: ' }) -replace '^data: ','' -join ''
    $parsed = $dataLine | ConvertFrom-Json

    if ($parsed.result.isError) {
        Write-Error "MCP Error ($ToolName): $($parsed.result.content[0].text)"
        return $null
    }

    $text = $parsed.result.content[0].text
    try { return ($text | ConvertFrom-Json) } catch { return $text }
}

# Convenience aliases
function Get-AdcSandboxes { Invoke-AdcMcp "list_sandboxes" @{} }
function Get-AdcSandbox([string]$Id) { Invoke-AdcMcp "get_sandbox" @{ sandboxId = $Id } }
function Invoke-AdcCommand([string]$SandboxId, [string]$Command) {
    Invoke-AdcMcp "execute_command" @{ sandboxId = $SandboxId; command = $Command }
}
function Get-AdcSecrets { Invoke-AdcMcp "list_secrets" @{} }
function Get-AdcConnections { Invoke-AdcMcp "list_connections" @{} }

Write-Host "ADC MCP skill loaded. Use: Invoke-AdcMcp <tool> <params>" -ForegroundColor Cyan
Write-Host "Shortcuts: Get-AdcSandboxes, Get-AdcSandbox, Invoke-AdcCommand, Get-AdcSecrets, Get-AdcConnections" -ForegroundColor DarkCyan
