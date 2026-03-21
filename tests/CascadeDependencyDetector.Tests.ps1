<#
.SYNOPSIS
    Unit tests for Cascade Dependency Detector (CDD) — Issue #1168
    Tests BFS downstream discovery and sequential mode management.
#>

Describe "Cascade Dependency Detector (CDD)" {

    BeforeAll {
        # Dot-source the rate-limit-manager to get CDD functions
        . "$PSScriptRoot\..\scripts\rate-limit-manager.ps1"

        # Override DAG path to use repo-local file
        $script:AgentDagPath = Join-Path $PSScriptRoot "..\.squad\agent-dag.json"

        # Use temp file for CDD state to avoid polluting real state
        $script:CddStatePath = Join-Path $env:TEMP "cdd-test-state-$(Get-Random).json"
    }

    AfterAll {
        if (Test-Path $script:CddStatePath) {
            Remove-Item $script:CddStatePath -Force -ErrorAction SilentlyContinue
        }
    }

    AfterEach {
        if (Test-Path $script:CddStatePath) {
            Remove-Item $script:CddStatePath -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Get-CascadeDownstream" {

        It "returns correct downstream set for 'picard'" {
            $result = Get-CascadeDownstream -RateLimitedAgent "picard"
            ($result -contains "data")      | Should Be $true
            ($result -contains "seven")     | Should Be $true
            ($result -contains "belanna")   | Should Be $true
            ($result -contains "worf")      | Should Be $true
            ($result -contains "troi")      | Should Be $true
            ($result -contains "neelix")    | Should Be $true
            ($result -contains "podcaster") | Should Be $true
            ($result -contains "picard")    | Should Be $false
        }

        It "returns correct downstream set for 'ralph'" {
            $result = Get-CascadeDownstream -RateLimitedAgent "ralph"
            ($result -contains "scribe") | Should Be $true
            $result.Count | Should Be 1
        }

        It "returns empty set for leaf agent with no downstream" {
            $result = Get-CascadeDownstream -RateLimitedAgent "scribe"
            $result.Count | Should Be 0
        }

        It "returns empty set for unknown agent" {
            $result = Get-CascadeDownstream -RateLimitedAgent "nonexistent"
            $result.Count | Should Be 0
        }

        It "handles circular-ish paths without infinite loop" {
            $result = Get-CascadeDownstream -RateLimitedAgent "seven"
            ($result -contains "troi")      | Should Be $true
            ($result -contains "neelix")    | Should Be $true
            ($result -contains "podcaster") | Should Be $true
            ($result -contains "seven")     | Should Be $false
        }
    }

    Context "Set-AgentSequentialMode and Test-SequentialModeActive" {

        It "sets and detects sequential mode" {
            Set-AgentSequentialMode -AgentId "data" -DurationSecs 60
            $result = Test-SequentialModeActive -AgentId "data"
            $result | Should Be $true
        }

        It "returns false for agent not in sequential mode" {
            $result = Test-SequentialModeActive -AgentId "belanna"
            $result | Should Be $false
        }

        It "auto-expires sequential mode" {
            Set-AgentSequentialMode -AgentId "worf" -DurationSecs 1
            Start-Sleep -Seconds 2
            $result = Test-SequentialModeActive -AgentId "worf"
            $result | Should Be $false
        }
    }

    Context "Invoke-CascadeBackpressure" {

        It "sets sequential mode for all downstream agents on 429" {
            Invoke-CascadeBackpressure -RateLimitedAgent "ralph" -DurationSecs 30
            $result = Test-SequentialModeActive -AgentId "scribe"
            $result | Should Be $true
        }

        It "does not affect upstream agents" {
            Invoke-CascadeBackpressure -RateLimitedAgent "ralph" -DurationSecs 30
            $result = Test-SequentialModeActive -AgentId "picard"
            $result | Should Be $false
        }
    }
}
