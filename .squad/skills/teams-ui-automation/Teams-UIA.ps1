# Teams-UIA.ps1 - Hybrid Teams Automation (Window Management + Keyboard Shortcuts)
# Version: 2.0
# Description: Provides window management and keyboard shortcuts for Teams automation.
#              For DOM-level operations, use Playwright MCP tools (see SKILL.md).
#
# Architecture:
#   - Layer 1 (Primary): Playwright MCP on teams.microsoft.com (documented in SKILL.md)
#   - Layer 2 (This file): Keyboard shortcuts via SendInput
#   - Layer 3 (This file): UIA for window management only (process/window state)

#Requires -Version 5.1

# Module-level variables
$script:TeamsWindow = $null
$script:ElementCache = $null
$script:CachePath = Join-Path $PSScriptRoot "element-cache.json"
$script:InputSenderLoaded = $false

#region Win32 API P/Invoke for SendInput and Window Management

Add-Type @"
using System;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential)]
public struct INPUT {
    public uint type;
    public INPUTUNION u;
}

[StructLayout(LayoutKind.Explicit)]
public struct INPUTUNION {
    [FieldOffset(0)] public KEYBDINPUT ki;
}

[StructLayout(LayoutKind.Sequential)]
public struct KEYBDINPUT {
    public ushort wVk;
    public ushort wScan;
    public uint dwFlags;
    public uint time;
    public IntPtr dwExtraInfo;
}

public class InputSender {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
    
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    
    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    
    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();
    
    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern bool IsZoomed(IntPtr hWnd);
    
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    // Constants
    public const uint INPUT_KEYBOARD = 1;
    public const uint KEYEVENTF_KEYUP = 0x0002;
    public const int SW_RESTORE = 9;
    
    // Virtual key codes
    public const ushort VK_CONTROL = 0x11;
    public const ushort VK_SHIFT = 0x10;
    public const ushort VK_ALT = 0x12;
    public const ushort VK_E = 0x45;
    public const ushort VK_N = 0x4E;
    public const ushort VK_OEM_COMMA = 0xBC;
    public const ushort VK_O = 0x4F;
    public const ushort VK_1 = 0x31;
    public const ushort VK_2 = 0x32;
    public const ushort VK_3 = 0x33;
    public const ushort VK_4 = 0x34;
    public const ushort VK_5 = 0x35;
    public const ushort VK_6 = 0x36;
}
"@

$script:InputSenderLoaded = $true

#endregion

#region Layer 3: UIA Window Management Functions

<#
.SYNOPSIS
    Get the Teams window handle and process information.
    
.DESCRIPTION
    Finds the running Teams process and returns window handle, process info.
    This is the only UIA function needed for window-level operations.
    
.EXAMPLE
    $teams = Get-TeamsWindow
    if ($teams) {
        Write-Host "Teams window found: $($teams.MainWindowTitle)"
    }
#>
function Get-TeamsWindow {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Searching for Teams window..."
    
    # New Teams runs as ms-teams.exe
    $teamsProcesses = Get-Process -Name "ms-teams" -ErrorAction SilentlyContinue
    
    if (-not $teamsProcesses) {
        Write-Warning "Teams process not found. Ensure Microsoft Teams is running."
        return $null
    }
    
    # Find the main Teams window (filter out hidden/system windows)
    foreach ($proc in $teamsProcesses) {
        if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
            $windowTitle = $proc.MainWindowTitle
            
            # New Teams typically has "Microsoft Teams" or just "Teams" in the title
            if ($windowTitle -match "Teams") {
                Write-Verbose "Found Teams window: $windowTitle (PID: $($proc.Id))"
                
                $script:TeamsWindow = @{
                    Handle = $proc.MainWindowHandle
                    Process = $proc
                    Title = $windowTitle
                    ProcessId = $proc.Id
                }
                
                return $script:TeamsWindow
            }
        }
    }
    
    Write-Warning "Teams process found but no valid window. Teams may be in system tray."
    return $null
}

<#
.SYNOPSIS
    Get the Teams application version.
    
.DESCRIPTION
    Retrieves Teams version from process file information.
    Used for cache validation.
    
.EXAMPLE
    $version = Get-TeamsVersion
    Write-Host "Teams version: $version"
#>
function Get-TeamsVersion {
    [CmdletBinding()]
    param()
    
    $teams = Get-TeamsWindow
    
    if (-not $teams) {
        Write-Warning "Cannot get version: Teams not running"
        return $null
    }
    
    try {
        $versionInfo = $teams.Process.FileVersionInfo
        $version = $versionInfo.FileVersion
        Write-Verbose "Teams version: $version"
        return $version
    }
    catch {
        Write-Warning "Failed to get Teams version: $_"
        return $null
    }
}

<#
.SYNOPSIS
    Test if Teams is running.
    
.DESCRIPTION
    Quick check for Teams process existence.
    
.EXAMPLE
    if (Test-TeamsRunning) {
        Write-Host "Teams is running"
    }
#>
function Test-TeamsRunning {
    [CmdletBinding()]
    param()
    
    $process = Get-Process -Name "ms-teams" -ErrorAction SilentlyContinue
    return ($null -ne $process)
}

<#
.SYNOPSIS
    Bring Teams window to foreground.
    
.DESCRIPTION
    Uses Win32 AttachThreadInput + SetForegroundWindow workaround
    to reliably bring Teams to the foreground. This is required
    before sending keyboard shortcuts.
    
.EXAMPLE
    Focus-TeamsWindow -Verbose
#>
function Focus-TeamsWindow {
    [CmdletBinding()]
    param()
    
    $teams = Get-TeamsWindow
    
    if (-not $teams) {
        Write-Error "Cannot focus: Teams window not found"
        return $false
    }
    
    $hWnd = $teams.Handle
    
    try {
        # Restore window if minimized
        if ([InputSender]::IsIconic($hWnd)) {
            Write-Verbose "Restoring minimized Teams window..."
            [InputSender]::ShowWindow($hWnd, [InputSender]::SW_RESTORE) | Out-Null
            Start-Sleep -Milliseconds 300
        }
        
        # Get current foreground window
        $foregroundHwnd = [InputSender]::GetForegroundWindow()
        
        if ($foregroundHwnd -eq $hWnd) {
            Write-Verbose "Teams window already in foreground"
            return $true
        }
        
        # Get thread IDs
        $currentThreadId = [InputSender]::GetCurrentThreadId()
        $targetProcessId = 0
        $targetThreadId = [InputSender]::GetWindowThreadProcessId($hWnd, [ref]$targetProcessId)
        
        # Attach input threads to allow SetForegroundWindow
        $attached = $false
        if ($currentThreadId -ne $targetThreadId) {
            Write-Verbose "Attaching input threads..."
            [InputSender]::AttachThreadInput($currentThreadId, $targetThreadId, $true) | Out-Null
            $attached = $true
        }
        
        # Set foreground window
        $result = [InputSender]::SetForegroundWindow($hWnd)
        Write-Verbose "SetForegroundWindow result: $result"
        
        # Detach input threads
        if ($attached) {
            Start-Sleep -Milliseconds 100
            [InputSender]::AttachThreadInput($currentThreadId, $targetThreadId, $false) | Out-Null
        }
        
        # Verify window is now foreground
        Start-Sleep -Milliseconds 200
        $newForeground = [InputSender]::GetForegroundWindow()
        
        if ($newForeground -eq $hWnd) {
            Write-Verbose "Teams window successfully focused"
            return $true
        }
        else {
            Write-Warning "Teams window focus verification failed"
            return $false
        }
    }
    catch {
        Write-Error "Failed to focus Teams window: $_"
        return $false
    }
}

#endregion

#region Layer 2: Keyboard Shortcut Functions

<#
.SYNOPSIS
    Send a keyboard shortcut to Teams window.
    
.DESCRIPTION
    Sends keyboard input using SendInput API. Teams window must be focused.
    Supports Ctrl, Shift, Alt modifiers and any virtual key code.
    
.PARAMETER VirtualKeyCodes
    Array of virtual key codes to press (in order). Use [InputSender]::VK_* constants.
    
.PARAMETER PressCtrl
    Hold Ctrl while pressing keys.
    
.PARAMETER PressShift
    Hold Shift while pressing keys.
    
.PARAMETER PressAlt
    Hold Alt while pressing keys.
    
.EXAMPLE
    # Send Ctrl+2 (Chat)
    Send-TeamsShortcut -VirtualKeyCodes @([InputSender]::VK_2) -PressCtrl
    
.EXAMPLE
    # Send Ctrl+Shift+6 (Apps)
    Send-TeamsShortcut -VirtualKeyCodes @([InputSender]::VK_6) -PressCtrl -PressShift
#>
function Send-TeamsShortcut {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [uint16[]]$VirtualKeyCodes,
        
        [switch]$PressCtrl,
        [switch]$PressShift,
        [switch]$PressAlt
    )
    
    # Ensure Teams is focused
    $focused = Focus-TeamsWindow
    if (-not $focused) {
        Write-Error "Cannot send shortcut: Failed to focus Teams window"
        return $false
    }
    
    Start-Sleep -Milliseconds 100
    
    $inputs = New-Object System.Collections.ArrayList
    
    try {
        # Press modifiers
        if ($PressCtrl) {
            $ctrlDown = New-Object INPUT
            $ctrlDown.type = [InputSender]::INPUT_KEYBOARD
            $ctrlDown.u.ki.wVk = [InputSender]::VK_CONTROL
            $ctrlDown.u.ki.dwFlags = 0
            [void]$inputs.Add($ctrlDown)
        }
        
        if ($PressShift) {
            $shiftDown = New-Object INPUT
            $shiftDown.type = [InputSender]::INPUT_KEYBOARD
            $shiftDown.u.ki.wVk = [InputSender]::VK_SHIFT
            $shiftDown.u.ki.dwFlags = 0
            [void]$inputs.Add($shiftDown)
        }
        
        if ($PressAlt) {
            $altDown = New-Object INPUT
            $altDown.type = [InputSender]::INPUT_KEYBOARD
            $altDown.u.ki.wVk = [InputSender]::VK_ALT
            $altDown.u.ki.dwFlags = 0
            [void]$inputs.Add($altDown)
        }
        
        # Press main keys
        foreach ($vk in $VirtualKeyCodes) {
            $keyDown = New-Object INPUT
            $keyDown.type = [InputSender]::INPUT_KEYBOARD
            $keyDown.u.ki.wVk = $vk
            $keyDown.u.ki.dwFlags = 0
            [void]$inputs.Add($keyDown)
        }
        
        # Release main keys (in reverse order)
        for ($i = $VirtualKeyCodes.Count - 1; $i -ge 0; $i--) {
            $keyUp = New-Object INPUT
            $keyUp.type = [InputSender]::INPUT_KEYBOARD
            $keyUp.u.ki.wVk = $VirtualKeyCodes[$i]
            $keyUp.u.ki.dwFlags = [InputSender]::KEYEVENTF_KEYUP
            [void]$inputs.Add($keyUp)
        }
        
        # Release modifiers
        if ($PressAlt) {
            $altUp = New-Object INPUT
            $altUp.type = [InputSender]::INPUT_KEYBOARD
            $altUp.u.ki.wVk = [InputSender]::VK_ALT
            $altUp.u.ki.dwFlags = [InputSender]::KEYEVENTF_KEYUP
            [void]$inputs.Add($altUp)
        }
        
        if ($PressShift) {
            $shiftUp = New-Object INPUT
            $shiftUp.type = [InputSender]::INPUT_KEYBOARD
            $shiftUp.u.ki.wVk = [InputSender]::VK_SHIFT
            $shiftUp.u.ki.dwFlags = [InputSender]::KEYEVENTF_KEYUP
            [void]$inputs.Add($shiftUp)
        }
        
        if ($PressCtrl) {
            $ctrlUp = New-Object INPUT
            $ctrlUp.type = [InputSender]::INPUT_KEYBOARD
            $ctrlUp.u.ki.wVk = [InputSender]::VK_CONTROL
            $ctrlUp.u.ki.dwFlags = [InputSender]::KEYEVENTF_KEYUP
            [void]$inputs.Add($ctrlUp)
        }
        
        # Send all inputs
        $inputArray = $inputs.ToArray([INPUT])
        $sent = [InputSender]::SendInput($inputArray.Count, $inputArray, [System.Runtime.InteropServices.Marshal]::SizeOf([type][INPUT]))
        
        if ($sent -eq $inputArray.Count) {
            Write-Verbose "Shortcut sent successfully ($sent inputs)"
            return $true
        }
        else {
            Write-Warning "Partial shortcut sent ($sent of $($inputArray.Count) inputs)"
            return $false
        }
    }
    catch {
        Write-Error "Failed to send shortcut: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Open Teams Apps view (Ctrl+Shift+6).
#>
function Open-TeamsApps {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Opening Teams Apps..."
    $result = Send-TeamsShortcut -VirtualKeyCodes @([InputSender]::VK_6) -PressCtrl -PressShift
    
    if ($result) {
        Update-ShortcutCache -Action "OpenApps" -Shortcut "Ctrl+Shift+6" -Success $true
    }
    
    return $result
}

<#
.SYNOPSIS
    Open Teams Chat view (Ctrl+2).
#>
function Open-TeamsChat {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Opening Teams Chat..."
    $result = Send-TeamsShortcut -VirtualKeyCodes @([InputSender]::VK_2) -PressCtrl
    
    if ($result) {
        Update-ShortcutCache -Action "OpenChat" -Shortcut "Ctrl+2" -Success $true
    }
    
    return $result
}

<#
.SYNOPSIS
    Open Teams view (Ctrl+3).
#>
function Open-TeamsTeams {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Opening Teams view..."
    $result = Send-TeamsShortcut -VirtualKeyCodes @([InputSender]::VK_3) -PressCtrl
    
    if ($result) {
        Update-ShortcutCache -Action "OpenTeams" -Shortcut "Ctrl+3" -Success $true
    }
    
    return $result
}

<#
.SYNOPSIS
    Open Teams Calendar view (Ctrl+4).
#>
function Open-TeamsCalendar {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Opening Teams Calendar..."
    $result = Send-TeamsShortcut -VirtualKeyCodes @([InputSender]::VK_4) -PressCtrl
    
    if ($result) {
        Update-ShortcutCache -Action "OpenCalendar" -Shortcut "Ctrl+4" -Success $true
    }
    
    return $result
}

<#
.SYNOPSIS
    Open Teams Search (Ctrl+E).
#>
function Open-TeamsSearch {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Opening Teams Search..."
    $result = Send-TeamsShortcut -VirtualKeyCodes @([InputSender]::VK_E) -PressCtrl
    
    if ($result) {
        Update-ShortcutCache -Action "OpenSearch" -Shortcut "Ctrl+E" -Success $true
    }
    
    return $result
}

<#
.SYNOPSIS
    Open Teams Settings (Ctrl+,).
#>
function Open-TeamsSettings {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Opening Teams Settings..."
    $result = Send-TeamsShortcut -VirtualKeyCodes @([InputSender]::VK_OEM_COMMA) -PressCtrl
    
    if ($result) {
        Update-ShortcutCache -Action "OpenSettings" -Shortcut "Ctrl+," -Success $true
    }
    
    return $result
}

<#
.SYNOPSIS
    Start a new Teams chat (Ctrl+N).
#>
function Start-TeamsNewChat {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Starting new Teams chat..."
    $result = Send-TeamsShortcut -VirtualKeyCodes @([InputSender]::VK_N) -PressCtrl
    
    if ($result) {
        Update-ShortcutCache -Action "NewChat" -Shortcut "Ctrl+N" -Success $true
    }
    
    return $result
}

<#
.SYNOPSIS
    Open Activity feed (Ctrl+1).
#>
function Open-TeamsActivity {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Opening Teams Activity feed..."
    $result = Send-TeamsShortcut -VirtualKeyCodes @([InputSender]::VK_1) -PressCtrl
    
    if ($result) {
        Update-ShortcutCache -Action "OpenActivity" -Shortcut "Ctrl+1" -Success $true
    }
    
    return $result
}

<#
.SYNOPSIS
    Open notification panel (Ctrl+Shift+O).
#>
function Open-TeamsNotifications {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Opening Teams notification panel..."
    $result = Send-TeamsShortcut -VirtualKeyCodes @([InputSender]::VK_O) -PressCtrl -PressShift
    
    if ($result) {
        Update-ShortcutCache -Action "OpenNotifications" -Shortcut "Ctrl+Shift+O" -Success $true
    }
    
    return $result
}

#endregion

#region Cache Management

<#
.SYNOPSIS
    Load element cache from disk.
#>
function Get-ElementCache {
    [CmdletBinding()]
    param()
    
    if (Test-Path $script:CachePath) {
        try {
            $content = Get-Content $script:CachePath -Raw | ConvertFrom-Json
            $script:ElementCache = $content
            Write-Verbose "Cache loaded from $script:CachePath"
            return $content
        }
        catch {
            Write-Warning "Failed to load cache: $_"
        }
    }
    
    # Initialize default cache structure
    $script:ElementCache = @{
        version = "2.0"
        teamsVersion = $null
        approach = "hybrid"
        layers = @{
            playwright = @{
                baseUrl = "https://teams.microsoft.com"
                selectors = @{}
            }
            keyboard = @{
                shortcuts = @{}
            }
            uia = @{
                windowClass = "TeamsWebView"
                processName = "ms-teams"
            }
        }
        recipes = @{}
        failureLog = @()
    }
    
    return $script:ElementCache
}

<#
.SYNOPSIS
    Save element cache to disk.
#>
function Save-ElementCache {
    [CmdletBinding()]
    param()
    
    if (-not $script:ElementCache) {
        Write-Warning "No cache to save"
        return
    }
    
    try {
        # Update Teams version
        $version = Get-TeamsVersion
        if ($version) {
            $script:ElementCache.teamsVersion = $version
        }
        
        $json = $script:ElementCache | ConvertTo-Json -Depth 10
        $json | Set-Content $script:CachePath -Encoding UTF8
        Write-Verbose "Cache saved to $script:CachePath"
    }
    catch {
        Write-Warning "Failed to save cache: $_"
    }
}

<#
.SYNOPSIS
    Update keyboard shortcut cache with success/failure tracking.
#>
function Update-ShortcutCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Action,
        
        [Parameter(Mandatory = $true)]
        [string]$Shortcut,
        
        [Parameter(Mandatory = $true)]
        [bool]$Success
    )
    
    if (-not $script:ElementCache) {
        Get-ElementCache | Out-Null
    }
    
    if (-not $script:ElementCache.layers.keyboard.shortcuts.ContainsKey($Action)) {
        $script:ElementCache.layers.keyboard.shortcuts[$Action] = @{
            shortcut = $Shortcut
            successCount = 0
            failureCount = 0
            lastUsed = Get-Date -Format "o"
        }
    }
    
    if ($Success) {
        $script:ElementCache.layers.keyboard.shortcuts[$Action].successCount++
    }
    else {
        $script:ElementCache.layers.keyboard.shortcuts[$Action].failureCount++
    }
    
    $script:ElementCache.layers.keyboard.shortcuts[$Action].lastUsed = Get-Date -Format "o"
    
    Save-ElementCache
}

<#
.SYNOPSIS
    Initialize the Teams automation module.
    
.DESCRIPTION
    Loads cache, verifies Teams is running, and prepares for automation.
    Call this before using any other functions.
    
.EXAMPLE
    Initialize-TeamsAutomation -Verbose
#>
function Initialize-TeamsAutomation {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Initializing Teams Automation (Hybrid Mode)..."
    
    # Load cache
    Get-ElementCache | Out-Null
    
    # Verify Teams is running
    if (-not (Test-TeamsRunning)) {
        Write-Warning "Teams is not running. Please start Microsoft Teams."
        return $false
    }
    
    # Get Teams window
    $teams = Get-TeamsWindow
    if (-not $teams) {
        Write-Warning "Could not find Teams window. Ensure Teams is not minimized to system tray."
        return $false
    }
    
    Write-Verbose "Teams Automation initialized successfully"
    Write-Verbose "Teams Version: $(Get-TeamsVersion)"
    Write-Verbose "Window Title: $($teams.Title)"
    Write-Verbose ""
    Write-Verbose "Available functions:"
    Write-Verbose "  Layer 3 (UIA): Get-TeamsWindow, Get-TeamsVersion, Test-TeamsRunning, Focus-TeamsWindow"
    Write-Verbose "  Layer 2 (Keyboard): Open-TeamsApps, Open-TeamsChat, Open-TeamsTeams, Open-TeamsCalendar,"
    Write-Verbose "                      Open-TeamsSearch, Open-TeamsSettings, Start-TeamsNewChat,"
    Write-Verbose "                      Open-TeamsActivity, Open-TeamsNotifications"
    Write-Verbose ""
    Write-Verbose "For Layer 1 (Playwright) operations, see SKILL.md for MCP tool call recipes."
    
    return $true
}

#endregion

# Auto-initialize on module load
Write-Host "Teams-UIA.ps1 v2.0 loaded. Call Initialize-TeamsAutomation to begin." -ForegroundColor Cyan

# Export functions
Export-ModuleMember -Function @(
    'Get-TeamsWindow',
    'Get-TeamsVersion',
    'Test-TeamsRunning',
    'Focus-TeamsWindow',
    'Send-TeamsShortcut',
    'Open-TeamsApps',
    'Open-TeamsChat',
    'Open-TeamsTeams',
    'Open-TeamsCalendar',
    'Open-TeamsSearch',
    'Open-TeamsSettings',
    'Start-TeamsNewChat',
    'Open-TeamsActivity',
    'Open-TeamsNotifications',
    'Get-ElementCache',
    'Save-ElementCache',
    'Initialize-TeamsAutomation'
)
