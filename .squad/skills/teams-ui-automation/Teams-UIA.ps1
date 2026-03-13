<#
.SYNOPSIS
    Self-healing UI Automation for Microsoft Teams desktop application.

.DESCRIPTION
    This module provides UI Automation capabilities for Microsoft Teams desktop app
    with automatic element discovery, multi-strategy element finding, and self-healing
    when UI changes occur. Designed for operations not available via Graph API.

.NOTES
    Author: Data (Code Expert)
    Version: 1.0
    Requires: Windows, Teams Desktop App, PowerShell 5.1+
#>

#Requires -Version 5.1

# Module-level variables
$script:TeamsWindow = $null
$script:ElementCache = $null
$script:CachePath = Join-Path $PSScriptRoot "element-cache.json"
$script:DefaultWaitMs = 500
$script:MaxRetries = 2

#region Core Infrastructure

<#
.SYNOPSIS
    Initialize Teams UI Automation module.

.DESCRIPTION
    Loads UI Automation assemblies, finds Teams window, and loads element cache.
    Must be called before using any other functions in this module.

.EXAMPLE
    Initialize-TeamsUIA -Verbose
#>
function Initialize-TeamsUIA {
    [CmdletBinding()]
    param()

    Write-Verbose "Initializing Teams UI Automation..."

    # Load UI Automation assemblies
    try {
        Add-Type -AssemblyName UIAutomationClient
        Add-Type -AssemblyName UIAutomationTypes
        Write-Verbose "UI Automation assemblies loaded"
    }
    catch {
        throw "Failed to load UI Automation assemblies. Ensure you're running on Windows with .NET Framework."
    }

    # Find Teams window
    $script:TeamsWindow = Find-TeamsWindow
    if (-not $script:TeamsWindow) {
        throw "Microsoft Teams window not found. Ensure Teams desktop app is running and signed in."
    }

    Write-Verbose "Teams window found: $($script:TeamsWindow.Current.Name)"

    # Load element cache
    $script:ElementCache = Get-ElementCache
    Write-Verbose "Element cache loaded (version: $($script:ElementCache.version), failures: $($script:ElementCache.failureCount))"

    # Check Teams version and invalidate cache if changed
    $currentVersion = Get-TeamsVersion
    if ($script:ElementCache.teamsVersion -and $script:ElementCache.teamsVersion -ne $currentVersion) {
        Write-Warning "Teams version changed from $($script:ElementCache.teamsVersion) to $currentVersion. Invalidating cache."
        $script:ElementCache.elements = @{}
        $script:ElementCache.teamsVersion = $currentVersion
        $script:ElementCache.failureCount = 0
        Save-ElementCache
    }
    elseif (-not $script:ElementCache.teamsVersion) {
        $script:ElementCache.teamsVersion = $currentVersion
        Save-ElementCache
    }

    Write-Verbose "Initialization complete"
}

<#
.SYNOPSIS
    Find Teams window using UI Automation.

.DESCRIPTION
    Searches for the Microsoft Teams desktop application window.

.OUTPUTS
    AutomationElement representing the Teams window.
#>
function Find-TeamsWindow {
    [CmdletBinding()]
    param()

    # Strategy 1: Find by process handle (most reliable)
    $teamsProc = Get-Process ms-teams -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 } |
        Select-Object -First 1

    if ($teamsProc) {
        try {
            $element = [System.Windows.Automation.AutomationElement]::FromHandle($teamsProc.MainWindowHandle)
            if ($element) {
                Write-Verbose "Found Teams window via process handle (PID $($teamsProc.Id)): $($element.Current.Name)"
                return $element
            }
        }
        catch {
            Write-Verbose "Process handle approach failed: $_"
        }
    }

    # Strategy 2: Walk desktop children looking for Teams by name (fallback)
    $desktop = [System.Windows.Automation.AutomationElement]::RootElement
    $walker = [System.Windows.Automation.TreeWalker]::RawViewWalker
    $child = $walker.GetFirstChild($desktop)

    # Known class names for Teams across versions
    $teamsClassNames = @("TeamsWebView", "Chrome_WidgetWin_1", "MSTeamsMainWindow")

    while ($child) {
        $name = $child.Current.Name
        $className = $child.Current.ClassName

        if ($name -match "Microsoft Teams" -and ($className -in $teamsClassNames -or $name -match "\| Microsoft Teams$")) {
            Write-Verbose "Found Teams window via tree walk: $name (Class: $className)"
            return $child
        }

        $child = $walker.GetNextSibling($child)
    }

    return $null
}

<#
.SYNOPSIS
    Multi-strategy element finder with self-healing.

.DESCRIPTION
    Attempts to find a UI element using multiple strategies in order:
    1. Cached path (if available)
    2. AutomationID match
    3. Name pattern match (regex)
    4. ControlType + hierarchy position
    5. Spatial heuristics

.PARAMETER ElementKey
    Logical name of the element (e.g., "AppStore", "MessageCompose").

.PARAMETER Strategies
    Array of strategies to try. Default: all strategies.

.PARAMETER RetryCount
    Number of retries if element not found. Default: 2.

.EXAMPLE
    $element = Find-TeamsElement -ElementKey "AppStore" -Verbose
#>
function Find-TeamsElement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ElementKey,

        [Parameter(Mandatory = $false)]
        [string[]]$Strategies = @("Cache", "AutomationId", "NamePattern", "Structure", "Spatial"),

        [Parameter(Mandatory = $false)]
        [int]$RetryCount = $script:MaxRetries
    )

    Write-Verbose "Finding element: $ElementKey (strategies: $($Strategies -join ', '))"

    for ($attempt = 0; $attempt -le $RetryCount; $attempt++) {
        if ($attempt -gt 0) {
            Write-Verbose "Retry attempt $attempt for $ElementKey"
            Start-Sleep -Milliseconds $script:DefaultWaitMs
        }

        # Strategy 1: Check cache
        if ($Strategies -contains "Cache") {
            $cachedElement = Get-CachedElement -ElementKey $ElementKey
            if ($cachedElement) {
                if (Test-CacheValidity -ElementKey $ElementKey -Element $cachedElement) {
                    Write-Verbose "Element found via cache: $ElementKey"
                    return $cachedElement
                }
                else {
                    Write-Verbose "Cached element invalid, invalidating cache entry"
                    Invalidate-CacheEntry -ElementKey $ElementKey
                }
            }
        }

        # Strategy 2: AutomationID match
        if ($Strategies -contains "AutomationId") {
            $element = Find-ByAutomationId -ElementKey $ElementKey
            if ($element) {
                Write-Verbose "Element found via AutomationId: $ElementKey"
                Save-ElementToCache -ElementKey $ElementKey -Element $element -Strategy "AutomationId"
                return $element
            }
        }

        # Strategy 3: Name pattern match
        if ($Strategies -contains "NamePattern") {
            $element = Find-ByNamePattern -ElementKey $ElementKey
            if ($element) {
                Write-Verbose "Element found via NamePattern: $ElementKey"
                Save-ElementToCache -ElementKey $ElementKey -Element $element -Strategy "NamePattern"
                return $element
            }
        }

        # Strategy 4: ControlType + structure
        if ($Strategies -contains "Structure") {
            $element = Find-ByStructure -ElementKey $ElementKey
            if ($element) {
                Write-Verbose "Element found via Structure: $ElementKey"
                Save-ElementToCache -ElementKey $ElementKey -Element $element -Strategy "Structure"
                return $element
            }
        }

        # Strategy 5: Spatial heuristics
        if ($Strategies -contains "Spatial") {
            $element = Find-BySpatialHeuristic -ElementKey $ElementKey
            if ($element) {
                Write-Verbose "Element found via Spatial heuristic: $ElementKey"
                Save-ElementToCache -ElementKey $ElementKey -Element $element -Strategy "Spatial"
                return $element
            }
        }
    }

    # All strategies failed
    Write-Warning "Element not found after all strategies: $ElementKey"
    $script:ElementCache.failureCount++
    Save-ElementCache

    # Check if we should auto-calibrate
    if ($script:ElementCache.failureCount -ge $script:ElementCache.maxFailuresBeforeRecalibrate) {
        Write-Warning "Failure threshold reached. Triggering automatic calibration..."
        Calibrate-TeamsUI
        
        # Retry once after calibration
        Write-Verbose "Retrying after calibration..."
        return Find-TeamsElement -ElementKey $ElementKey -Strategies $Strategies -RetryCount 0
    }

    return $null
}

<#
.SYNOPSIS
    Full UI tree scan to rebuild element map.

.DESCRIPTION
    Walks the entire Teams UI tree, identifies key landmarks, and saves
    a versioned mapping. Resets failure counter.

.PARAMETER Force
    Force recalibration even if cache is valid.

.EXAMPLE
    Calibrate-TeamsUI -Force -Verbose
#>
function Calibrate-TeamsUI {
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    if (-not $script:TeamsWindow) {
        throw "Teams UI Automation not initialized. Call Initialize-TeamsUIA first."
    }

    Write-Verbose "Starting Teams UI calibration..."

    # Clear existing cache
    $script:ElementCache.elements = @{}
    $script:ElementCache.failureCount = 0
    $script:ElementCache.calibratedAt = (Get-Date).ToUniversalTime().ToString("o")
    $script:ElementCache.teamsVersion = Get-TeamsVersion

    # Walk the UI tree and discover key elements
    $discoveredElements = @{}

    # Known element patterns to search for
    $elementPatterns = @{
        "AppStore" = @{
            NamePattern = "Apps?|Store|Marketplace"
            ControlType = "Button"
        }
        "ChannelList" = @{
            NamePattern = "Channels?|Channel list"
            ControlType = "List"
        }
        "TeamList" = @{
            NamePattern = "Teams?|Team list"
            ControlType = "List"
        }
        "MessageCompose" = @{
            NamePattern = "Type a message|Compose|Message input"
            ControlType = "Edit"
        }
        "SearchBar" = @{
            NamePattern = "Search|Find"
            ControlType = "Edit"
        }
        "SettingsButton" = @{
            NamePattern = "Settings|Options"
            ControlType = "Button"
        }
    }

    $walker = [System.Windows.Automation.TreeWalker]::RawViewWalker
    $queue = New-Object System.Collections.Generic.Queue[object]
    $queue.Enqueue(@{Element = $script:TeamsWindow; Depth = 0})
    $maxDepth = 15
    $elementCount = 0

    Write-Verbose "Walking UI tree (max depth: $maxDepth)..."

    while ($queue.Count -gt 0 -and $elementCount -lt 1000) {
        $item = $queue.Dequeue()
        $element = $item.Element
        $depth = $item.Depth

        if ($depth -gt $maxDepth) { continue }

        try {
            $elementCount++
            $name = $element.Current.Name
            $automationId = $element.Current.AutomationId
            $controlType = $element.Current.ControlType.ProgrammaticName -replace "ControlType\.", ""
            $className = $element.Current.ClassName

            # Check against known patterns
            foreach ($key in $elementPatterns.Keys) {
                $pattern = $elementPatterns[$key]
                
                if ($controlType -eq $pattern.ControlType -and $name -match $pattern.NamePattern) {
                    if (-not $discoveredElements.ContainsKey($key)) {
                        Write-Verbose "Discovered element: $key (name: $name, id: $automationId, type: $controlType)"
                        
                        $discoveredElements[$key] = @{
                            automationId = $automationId
                            name = $name
                            controlType = $controlType
                            className = $className
                            depth = $depth
                            strategy = "Calibration"
                            timestamp = (Get-Date).ToUniversalTime().ToString("o")
                        }
                    }
                }
            }

            # Add children to queue
            $child = $walker.GetFirstChild($element)
            while ($child) {
                $queue.Enqueue(@{Element = $child; Depth = $depth + 1})
                $child = $walker.GetNextSibling($child)
            }
        }
        catch {
            # Ignore elements that can't be accessed
        }
    }

    Write-Verbose "Calibration complete. Discovered $($discoveredElements.Count) key elements out of $elementCount total elements."

    # Save discovered elements to cache
    $script:ElementCache.elements = $discoveredElements
    Save-ElementCache

    Write-Verbose "Element cache saved with $($discoveredElements.Count) elements"
}

<#
.SYNOPSIS
    Invoke a Teams action with automatic retry and self-healing.

.PARAMETER Action
    ScriptBlock containing the action to perform.

.PARAMETER MaxRetries
    Maximum number of retries on failure. Default: 2.

.EXAMPLE
    Invoke-TeamsAction -Action { Install-TeamsApp "Planner" } -MaxRetries 2
#>
function Invoke-TeamsAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock]$Action,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = $script:MaxRetries
    )

    for ($attempt = 0; $attempt -le $MaxRetries; $attempt++) {
        try {
            if ($attempt -gt 0) {
                Write-Verbose "Retry attempt $attempt"
            }

            & $Action
            return $true
        }
        catch {
            Write-Warning "Action failed: $_"
            
            if ($attempt -eq $MaxRetries) {
                Write-Error "Action failed after $MaxRetries retries"
                return $false
            }

            Start-Sleep -Milliseconds ($script:DefaultWaitMs * 2)
        }
    }
}

#endregion

#region Element Cache Management

<#
.SYNOPSIS
    Load element cache from JSON file.

.OUTPUTS
    Hashtable containing cache data.
#>
function Get-ElementCache {
    [CmdletBinding()]
    param()

    if (Test-Path $script:CachePath) {
        try {
            $json = Get-Content $script:CachePath -Raw | ConvertFrom-Json
            return @{
                version = $json.version
                teamsVersion = $json.teamsVersion
                calibratedAt = $json.calibratedAt
                failureCount = $json.failureCount
                maxFailuresBeforeRecalibrate = $json.maxFailuresBeforeRecalibrate
                elements = @{}
            } + ($json.elements | Get-Member -MemberType NoteProperty | ForEach-Object {
                @{$_.Name = $json.elements.($_.Name)}
            })
        }
        catch {
            Write-Warning "Failed to load cache, creating new one: $_"
        }
    }

    # Return default cache structure
    return @{
        version = "1.0"
        teamsVersion = $null
        calibratedAt = $null
        failureCount = 0
        maxFailuresBeforeRecalibrate = 3
        elements = @{}
    }
}

<#
.SYNOPSIS
    Save element cache to JSON file.
#>
function Save-ElementCache {
    [CmdletBinding()]
    param()

    try {
        $script:ElementCache | ConvertTo-Json -Depth 10 | Set-Content $script:CachePath -Encoding UTF8
        Write-Verbose "Element cache saved to $script:CachePath"
    }
    catch {
        Write-Warning "Failed to save element cache: $_"
    }
}

<#
.SYNOPSIS
    Remove cached path for a specific element.

.PARAMETER ElementKey
    Key of the element to invalidate.
#>
function Invalidate-CacheEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ElementKey
    )

    if ($script:ElementCache.elements.ContainsKey($ElementKey)) {
        $script:ElementCache.elements.Remove($ElementKey)
        Save-ElementCache
        Write-Verbose "Invalidated cache entry: $ElementKey"
    }
}

<#
.SYNOPSIS
    Check if cached element still exists at expected location.

.PARAMETER ElementKey
    Key of the element to validate.

.PARAMETER Element
    The AutomationElement to validate.

.OUTPUTS
    Boolean indicating whether the cache entry is valid.
#>
function Test-CacheValidity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ElementKey,

        [Parameter(Mandatory = $true)]
        $Element
    )

    try {
        # Try to access a property to verify element is still valid
        $name = $Element.Current.Name
        return $true
    }
    catch {
        Write-Verbose "Cached element no longer valid: $ElementKey"
        return $false
    }
}

<#
.SYNOPSIS
    Get cached element by key.

.PARAMETER ElementKey
    Key of the element to retrieve.

.OUTPUTS
    AutomationElement if found in cache and still valid, otherwise $null.
#>
function Get-CachedElement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ElementKey
    )

    if (-not $script:ElementCache.elements.ContainsKey($ElementKey)) {
        return $null
    }

    $cached = $script:ElementCache.elements[$ElementKey]
    
    # Try to find element by AutomationId if we have it
    if ($cached.automationId) {
        try {
            $condition = New-Object System.Windows.Automation.PropertyCondition(
                [System.Windows.Automation.AutomationElement]::AutomationIdProperty,
                $cached.automationId
            )
            $element = $script:TeamsWindow.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
            
            if ($element) {
                return $element
            }
        }
        catch {
            Write-Verbose "Failed to retrieve cached element: $_"
        }
    }

    return $null
}

<#
.SYNOPSIS
    Save discovered element to cache.

.PARAMETER ElementKey
    Logical key for the element.

.PARAMETER Element
    The AutomationElement to cache.

.PARAMETER Strategy
    Strategy used to discover the element.
#>
function Save-ElementToCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ElementKey,

        [Parameter(Mandatory = $true)]
        $Element,

        [Parameter(Mandatory = $true)]
        [string]$Strategy
    )

    $script:ElementCache.elements[$ElementKey] = @{
        automationId = $Element.Current.AutomationId
        name = $Element.Current.Name
        controlType = $Element.Current.ControlType.ProgrammaticName -replace "ControlType\.", ""
        className = $Element.Current.ClassName
        strategy = $Strategy
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
    }

    Save-ElementCache
}

#endregion

#region Element Discovery Strategies

<#
.SYNOPSIS
    Find element by AutomationId.
#>
function Find-ByAutomationId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ElementKey
    )

    # AutomationId patterns for known elements
    $idPatterns = @{
        "AppStore" = "app-bar-.*apps"
        "SearchBar" = "search"
        "SettingsButton" = "settings"
    }

    if (-not $idPatterns.ContainsKey($ElementKey)) {
        return $null
    }

    $pattern = $idPatterns[$ElementKey]
    $walker = [System.Windows.Automation.TreeWalker]::RawViewWalker
    
    try {
        $queue = New-Object System.Collections.Generic.Queue[object]
        $queue.Enqueue(@{Element = $script:TeamsWindow; Depth = 0})
        
        while ($queue.Count -gt 0) {
            $item = $queue.Dequeue()
            $element = $item.Element
            
            if ($item.Depth -gt 10) { continue }
            
            $automationId = $element.Current.AutomationId
            if ($automationId -match $pattern) {
                return $element
            }
            
            $child = $walker.GetFirstChild($element)
            while ($child) {
                $queue.Enqueue(@{Element = $child; Depth = $item.Depth + 1})
                $child = $walker.GetNextSibling($child)
            }
        }
    }
    catch {
        Write-Verbose "AutomationId search failed: $_"
    }

    return $null
}

<#
.SYNOPSIS
    Find element by name pattern matching.
#>
function Find-ByNamePattern {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ElementKey
    )

    # Name patterns for known elements
    $namePatterns = @{
        "AppStore" = "Apps?|Store"
        "ChannelList" = "Channels?"
        "TeamList" = "Teams?"
        "MessageCompose" = "Type a message|Compose"
        "SearchBar" = "Search"
        "SettingsButton" = "Settings|Options"
    }

    if (-not $namePatterns.ContainsKey($ElementKey)) {
        return $null
    }

    $pattern = $namePatterns[$ElementKey]
    $walker = [System.Windows.Automation.TreeWalker]::RawViewWalker
    
    try {
        $queue = New-Object System.Collections.Generic.Queue[object]
        $queue.Enqueue(@{Element = $script:TeamsWindow; Depth = 0})
        
        while ($queue.Count -gt 0) {
            $item = $queue.Dequeue()
            $element = $item.Element
            
            if ($item.Depth -gt 10) { continue }
            
            $name = $element.Current.Name
            if ($name -match $pattern) {
                return $element
            }
            
            $child = $walker.GetFirstChild($element)
            while ($child) {
                $queue.Enqueue(@{Element = $child; Depth = $item.Depth + 1})
                $child = $walker.GetNextSibling($child)
            }
        }
    }
    catch {
        Write-Verbose "Name pattern search failed: $_"
    }

    return $null
}

<#
.SYNOPSIS
    Find element by structural position.
#>
function Find-ByStructure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ElementKey
    )

    # Structural hints for known elements
    # This would need to be more sophisticated in production
    Write-Verbose "Structural search not yet implemented for $ElementKey"
    return $null
}

<#
.SYNOPSIS
    Find element using spatial heuristics.
#>
function Find-BySpatialHeuristic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ElementKey
    )

    # Spatial hints for known elements
    # This would need to be more sophisticated in production
    Write-Verbose "Spatial search not yet implemented for $ElementKey"
    return $null
}

#endregion

#region Teams Actions

<#
.SYNOPSIS
    Install a Teams app to a specific team.

.PARAMETER AppName
    Name of the app to install (e.g., "Planner", "Wiki").

.PARAMETER TeamName
    Name of the team to install the app to.

.EXAMPLE
    Install-TeamsApp -AppName "Planner" -TeamName "Engineering" -Verbose
#>
function Install-TeamsApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [Parameter(Mandatory = $true)]
        [string]$TeamName
    )

    Write-Verbose "Installing app '$AppName' to team '$TeamName'"

    # Find and click app store button
    $appStoreButton = Find-TeamsElement -ElementKey "AppStore"
    if (-not $appStoreButton) {
        throw "Could not find App Store button"
    }

    Click-Element -Element $appStoreButton
    Start-Sleep -Milliseconds ($script:DefaultWaitMs * 2)

    # Find search box and search for app
    $searchBox = Find-TeamsElement -ElementKey "SearchBar"
    if (-not $searchBox) {
        throw "Could not find search box in app store"
    }

    Type-InElement -Element $searchBox -Text $AppName -ClearFirst $true
    Start-Sleep -Milliseconds $script:DefaultWaitMs

    # TODO: Complete implementation with app selection and installation
    Write-Warning "Install-TeamsApp is a prototype. Full implementation pending."
}

<#
.SYNOPSIS
    Add a tab to a Teams channel.

.PARAMETER TeamName
    Name of the team.

.PARAMETER ChannelName
    Name of the channel.

.PARAMETER TabType
    Type of tab (e.g., "Wiki", "Planner", "Website").

.PARAMETER TabName
    Display name for the tab.

.EXAMPLE
    Add-TeamsTab -TeamName "Engineering" -ChannelName "General" -TabType "Wiki" -TabName "Team Wiki"
#>
function Add-TeamsTab {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TeamName,

        [Parameter(Mandatory = $true)]
        [string]$ChannelName,

        [Parameter(Mandatory = $true)]
        [string]$TabType,

        [Parameter(Mandatory = $true)]
        [string]$TabName
    )

    Write-Verbose "Adding tab '$TabName' ($TabType) to $TeamName/$ChannelName"

    Navigate-ToTeam -TeamName $TeamName
    Navigate-ToChannel -ChannelName $ChannelName

    # TODO: Complete implementation
    Write-Warning "Add-TeamsTab is a prototype. Full implementation pending."
}

<#
.SYNOPSIS
    Navigate to a specific team.

.PARAMETER TeamName
    Name of the team to navigate to.
#>
function Navigate-ToTeam {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TeamName
    )

    Write-Verbose "Navigating to team: $TeamName"

    # Find team list
    $teamList = Find-TeamsElement -ElementKey "TeamList"
    if (-not $teamList) {
        throw "Could not find team list"
    }

    # TODO: Find specific team and click it
    Write-Warning "Navigate-ToTeam is a prototype. Full implementation pending."
}

<#
.SYNOPSIS
    Navigate to a specific channel within current team.

.PARAMETER ChannelName
    Name of the channel to navigate to.
#>
function Navigate-ToChannel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ChannelName
    )

    Write-Verbose "Navigating to channel: $ChannelName"

    # Find channel list
    $channelList = Find-TeamsElement -ElementKey "ChannelList"
    if (-not $channelList) {
        throw "Could not find channel list"
    }

    # TODO: Find specific channel and click it
    Write-Warning "Navigate-ToChannel is a prototype. Full implementation pending."
}

<#
.SYNOPSIS
    Open Teams settings dialog.
#>
function Open-TeamsSettings {
    [CmdletBinding()]
    param()

    Write-Verbose "Opening Teams settings"

    $settingsButton = Find-TeamsElement -ElementKey "SettingsButton"
    if (-not $settingsButton) {
        throw "Could not find Settings button"
    }

    Click-Element -Element $settingsButton
    Start-Sleep -Milliseconds $script:DefaultWaitMs
}

<#
.SYNOPSIS
    Open Teams app store/marketplace.
#>
function Open-TeamsAppStore {
    [CmdletBinding()]
    param()

    Write-Verbose "Opening Teams app store"

    $appStoreButton = Find-TeamsElement -ElementKey "AppStore"
    if (-not $appStoreButton) {
        throw "Could not find App Store button"
    }

    Click-Element -Element $appStoreButton
    Start-Sleep -Milliseconds ($script:DefaultWaitMs * 2)
}

<#
.SYNOPSIS
    Dump current UI tree to JSON file for debugging.

.PARAMETER OutputPath
    Path to save the UI snapshot JSON file.

.EXAMPLE
    Get-TeamsUISnapshot -OutputPath "C:\temp\teams-ui-debug.json"
#>
function Get-TeamsUISnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    if (-not $script:TeamsWindow) {
        throw "Teams UI Automation not initialized. Call Initialize-TeamsUIA first."
    }

    Write-Verbose "Capturing UI snapshot..."

    $snapshot = @{
        capturedAt = (Get-Date).ToUniversalTime().ToString("o")
        teamsVersion = Get-TeamsVersion
        windowName = $script:TeamsWindow.Current.Name
        elements = @()
    }

    $walker = [System.Windows.Automation.TreeWalker]::RawViewWalker
    $queue = New-Object System.Collections.Generic.Queue[object]
    $queue.Enqueue(@{Element = $script:TeamsWindow; Depth = 0; Path = "Root"})
    $maxDepth = 10
    $maxElements = 500

    while ($queue.Count -gt 0 -and $snapshot.elements.Count -lt $maxElements) {
        $item = $queue.Dequeue()
        $element = $item.Element
        $depth = $item.Depth

        if ($depth -gt $maxDepth) { continue }

        try {
            $elementInfo = @{
                path = $item.Path
                depth = $depth
                name = $element.Current.Name
                automationId = $element.Current.AutomationId
                className = $element.Current.ClassName
                controlType = $element.Current.ControlType.ProgrammaticName -replace "ControlType\.", ""
                isEnabled = $element.Current.IsEnabled
                isOffscreen = $element.Current.IsOffscreen
            }

            $snapshot.elements += $elementInfo

            # Add children
            $childIndex = 0
            $child = $walker.GetFirstChild($element)
            while ($child) {
                $childPath = "$($item.Path)[$childIndex]"
                $queue.Enqueue(@{Element = $child; Depth = $depth + 1; Path = $childPath})
                $child = $walker.GetNextSibling($child)
                $childIndex++
            }
        }
        catch {
            # Ignore inaccessible elements
        }
    }

    Write-Verbose "Captured $($snapshot.elements.Count) elements"

    $snapshot | ConvertTo-Json -Depth 10 | Set-Content $OutputPath -Encoding UTF8
    Write-Host "UI snapshot saved to: $OutputPath"
}

#endregion

#region Utilities

<#
.SYNOPSIS
    Wait for element to appear with timeout.

.PARAMETER Element
    Element to wait for (or condition to check).

.PARAMETER TimeoutSeconds
    Maximum time to wait in seconds. Default: 10.

.OUTPUTS
    Boolean indicating whether element appeared.
#>
function Wait-ForElement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Element,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 10
    )

    $startTime = Get-Date
    
    while (((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
        try {
            # Try to access element property to verify it exists
            $name = $Element.Current.Name
            return $true
        }
        catch {
            Start-Sleep -Milliseconds 200
        }
    }

    return $false
}

<#
.SYNOPSIS
    Click an element with retry logic.

.PARAMETER Element
    AutomationElement to click.

.PARAMETER VerifyClickable
    Verify element is enabled before clicking. Default: $true.

.EXAMPLE
    Click-Element -Element $button -Verbose
#>
function Click-Element {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Element,

        [Parameter(Mandatory = $false)]
        [bool]$VerifyClickable = $true
    )

    if ($VerifyClickable -and -not $Element.Current.IsEnabled) {
        throw "Element is not enabled for clicking"
    }

    try {
        $invokePattern = $Element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
        $invokePattern.Invoke()
        Write-Verbose "Element clicked successfully"
    }
    catch {
        Write-Warning "Failed to click element: $_"
        throw
    }
}

<#
.SYNOPSIS
    Type text into an element.

.PARAMETER Element
    AutomationElement to type into (must support ValuePattern).

.PARAMETER Text
    Text to type.

.PARAMETER ClearFirst
    Clear existing text before typing. Default: $false.

.EXAMPLE
    Type-InElement -Element $textBox -Text "Hello" -ClearFirst $true
#>
function Type-InElement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Element,

        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $false)]
        [bool]$ClearFirst = $false
    )

    try {
        $valuePattern = $Element.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
        
        if ($ClearFirst) {
            $valuePattern.SetValue("")
        }
        
        $valuePattern.SetValue($Text)
        Write-Verbose "Typed text successfully: $Text"
    }
    catch {
        Write-Warning "Failed to type into element: $_"
        throw
    }
}

<#
.SYNOPSIS
    Get current Teams version.

.OUTPUTS
    String containing Teams version number.
#>
function Get-TeamsVersion {
    [CmdletBinding()]
    param()

    try {
        # Try to get Teams version from process
        $teamsProcess = Get-Process -Name "ms-teams" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($teamsProcess) {
            $version = $teamsProcess.MainModule.FileVersionInfo.FileVersion
            Write-Verbose "Teams version: $version"
            return $version
        }
    }
    catch {
        Write-Verbose "Could not determine Teams version: $_"
    }

    return "unknown"
}

#endregion

Write-Verbose "Teams UI Automation module loaded. Dot-source to use: . $PSCommandPath"
