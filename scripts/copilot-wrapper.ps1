#!/usr/bin/env pwsh
# =============================================================================
# copilot-wrapper.ps1 — Copilot API call instrumentation for KEDA metrics
#
# Wraps 'gh copilot' calls to detect rate-limit errors and aggregate metrics
# for Prometheus collection by squad-metrics-exporter.
#
# Usage:
#   Import-Module ./copilot-wrapper.ps1
#   $response = Invoke-CopilotWithMetrics -Prompt "explain this code" -AgentId "data"
#
# Related: Issue #1280 (KEDA Phase 2), #1134 (Phase 1)
# =============================================================================

# Global constants
$script:RATE_POOL_PATH = Join-Path $env:TEMP "squad-rate-pool.json"
$script:COPILOT_METRICS_PATH = Join-Path $env:TEMP "squad-copilot-metrics.json"

# Initialize metrics store if not exists
function Initialize-MetricsStore {
    if (-not (Test-Path $script:COPILOT_METRICS_PATH)) {
        $initialMetrics = @{
            copilot_requests_total = 0
            copilot_rate_limit_hits = 0
            copilot_retry_after_seconds = 0
            last_updated = (Get-Date -Format "o")
            agents = @{}
        }
        $initialMetrics | ConvertTo-Json -Depth 5 | Set-Content $script:COPILOT_METRICS_PATH -Encoding UTF8
    }
}

# Update rate pool with retry-after information
function Update-RatePool {
    param(
        [string]$Api,
        [int]$RetryAfter,
        [string]$AgentId
    )
    
    $ratePool = @{}
    if (Test-Path $script:RATE_POOL_PATH) {
        try {
            $ratePool = Get-Content $script:RATE_POOL_PATH -Raw | ConvertFrom-Json -AsHashtable
        } catch {
            Write-Warning "Failed to parse rate-pool.json, reinitializing: $_"
        }
    }
    
    if (-not $ratePool.ContainsKey($Api)) {
        $ratePool[$Api] = @{}
    }
    
    $ratePool[$Api][$AgentId] = @{
        retry_after = $RetryAfter
        hit_at = (Get-Date -Format "o")
    }
    
    $ratePool | ConvertTo-Json -Depth 5 | Set-Content $script:RATE_POOL_PATH -Encoding UTF8
}

# Update Copilot metrics
function Update-CopilotMetrics {
    param(
        [string]$AgentId,
        [string]$Tier = "unknown",
        [bool]$RateLimitHit = $false,
        [int]$RetryAfter = 0
    )
    
    Initialize-MetricsStore
    
    $metrics = Get-Content $script:COPILOT_METRICS_PATH -Raw | ConvertFrom-Json -AsHashtable
    
    # Increment total requests
    $metrics.copilot_requests_total++
    
    # Track per-agent metrics
    if (-not $metrics.agents.ContainsKey($AgentId)) {
        $metrics.agents[$AgentId] = @{
            requests = 0
            rate_limit_hits = 0
            tier = $Tier
        }
    }
    $metrics.agents[$AgentId].requests++
    $metrics.agents[$AgentId].tier = $Tier
    
    # Handle rate limit hits
    if ($RateLimitHit) {
        $metrics.copilot_rate_limit_hits++
        $metrics.agents[$AgentId].rate_limit_hits++
        
        if ($RetryAfter -gt 0) {
            $metrics.copilot_retry_after_seconds = $RetryAfter
        }
    }
    
    $metrics.last_updated = (Get-Date -Format "o")
    
    $metrics | ConvertTo-Json -Depth 5 | Set-Content $script:COPILOT_METRICS_PATH -Encoding UTF8
}

# Main wrapper function
function Invoke-CopilotWithMetrics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt,
        
        [Parameter(Mandatory=$false)]
        [string]$AgentId = "unknown",
        
        [Parameter(Mandatory=$false)]
        [string]$Tier = "unknown",
        
        [Parameter(Mandatory=$false)]
        [switch]$Explain
    )
    
    $command = if ($Explain) { "explain" } else { "suggest" }
    
    # Execute gh copilot command and capture both stdout and stderr
    $output = $null
    $errorOutput = $null
    
    try {
        if ($Explain) {
            $output = gh copilot explain $Prompt 2>&1
        } else {
            $output = gh copilot suggest $Prompt 2>&1
        }
        
        $exitCode = $LASTEXITCODE
        
        # Check for rate limit errors in output
        $rateLimitHit = $false
        $retryAfter = 0
        
        if ($exitCode -ne 0) {
            $fullOutput = $output -join "`n"
            
            if ($fullOutput -match "rate limit exceeded" -or $fullOutput -match "429") {
                $rateLimitHit = $true
                
                # Try to extract Retry-After header value
                if ($fullOutput -match "Retry-After[:\s]+(\d+)") {
                    $retryAfter = [int]$matches[1]
                } elseif ($fullOutput -match "retry after (\d+) seconds") {
                    $retryAfter = [int]$matches[1]
                }
                
                Write-Warning "[$AgentId] Copilot API rate limit hit. Retry after: $retryAfter seconds"
                Update-RatePool -Api "copilot" -RetryAfter $retryAfter -AgentId $AgentId
            }
        }
        
        # Update metrics
        Update-CopilotMetrics -AgentId $AgentId -Tier $Tier -RateLimitHit $rateLimitHit -RetryAfter $retryAfter
        
        # Return output
        return $output
        
    } catch {
        Write-Error "Failed to execute gh copilot: $_"
        Update-CopilotMetrics -AgentId $AgentId -Tier $Tier -RateLimitHit $false
        throw
    }
}

# Export function
Export-ModuleMember -Function Invoke-CopilotWithMetrics, Update-CopilotMetrics, Initialize-MetricsStore
