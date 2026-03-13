# TEAMS UI AUTOMATION - WORKING POWERSHELL EXAMPLES

# =============================================================================
# PART 1: SETUP
# =============================================================================

# Load assemblies
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

# Get Teams window
$proc = Get-Process ms-teams | Where { $_.MainWindowHandle -ne 0 }
$root = [System.Windows.Automation.AutomationElement]::FromHandle($proc.MainWindowHandle)

Write-Host "Teams PID: $($proc.Id)"
Write-Host "Window: $($proc.MainWindowTitle)"

# =============================================================================
# PART 2: HELPER FUNCTIONS
# =============================================================================

function Find-Element {
    param($parent, $name, $id = $null, $controlType = $null)
    
    $conditions = @()
    
    if ($id) {
        $conditions += New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::AutomationIdProperty, $id)
    }
    
    if ($name) {
        $conditions += New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::NameProperty, $name)
    }
    
    if ($controlType) {
        $conditions += New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty, $controlType)
    }
    
    $cond = $conditions[0]
    for ($i = 1; $i -lt $conditions.Count; $i++) {
        $cond = New-Object System.Windows.Automation.AndCondition($cond, $conditions[$i])
    }
    
    $parent.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
}

function Invoke-UIClick {
    param($element)
    
    if ($element) {
        $pattern = $element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
        if ($pattern) {
            $pattern.Invoke()
            Start-Sleep -Milliseconds 500
            return $true
        }
    }
    return $false
}

function Set-UIText {
    param($element, $text)
    
    if ($element) {
        $pattern = $element.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
        if ($pattern) {
            $pattern.SetValue("")
            Start-Sleep -Milliseconds 100
            $pattern.SetValue($text)
            return $true
        }
    }
    return $false
}

function Expand-UIElement {
    param($element, $expand = $true)
    
    if ($element) {
        $pattern = $element.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern)
        if ($pattern) {
            if ($expand) { $pattern.Expand() }
            else { $pattern.Collapse() }
            Start-Sleep -Milliseconds 600
            return $true
        }
    }
    return $false
}

# =============================================================================
# PART 3: EXAMPLES
# =============================================================================

# EXAMPLE 1: Find a button and click it
# Write-Host "EXAMPLE 1: Finding and clicking a button..."
# $btn = Find-Element -parent $root -name "New chat"
# if ($btn) {
#     Write-Host "Found button, clicking..."
#     Invoke-UIClick $btn
# }

# EXAMPLE 2: Find a text box and type text
# Write-Host "EXAMPLE 2: Finding message box and typing..."
# $msgBox = Find-Element -parent $root -name "Message"
# if ($msgBox) {
#     Set-UIText $msgBox "Hello from PowerShell!"
# }

# EXAMPLE 3: Navigate to team/channel
# Write-Host "EXAMPLE 3: Navigating to channel..."
# 
# $team = Find-Element -parent $root -name "Engineering"
# if ($team) {
#     Expand-UIElement $team $true
#     Start-Sleep -Milliseconds 800  # CRITICAL: Wait for channels to load
#     
#     $channel = Find-Element -parent $root -name "general"
#     if ($channel) {
#         Invoke-UIClick $channel
#         Write-Host "Navigated to Engineering > general"
#     }
# }

# EXAMPLE 4: Send a message
# Write-Host "EXAMPLE 4: Sending message..."
#
# $msgBox = Find-Element -parent $root -name "Message"
# if ($msgBox) {
#     Set-UIText $msgBox "Test message from automation"
#     Start-Sleep -Milliseconds 300
#     [System.Windows.Forms.SendKeys]::SendWait("^({ENTER})")  # Ctrl+Enter to send
#     Write-Host "Message sent"
# }

# EXAMPLE 5: Use keyboard shortcut (more reliable)
# Write-Host "EXAMPLE 5: Using keyboard shortcut to open search..."
# [System.Windows.Forms.SendKeys]::SendWait("^k")  # Ctrl+K
# Start-Sleep -Milliseconds 500

# EXAMPLE 6: Display UI element tree
# Write-Host "EXAMPLE 6: Showing UI element tree (limited depth)..."
# 
# function Show-Tree {
#     param($elem, $depth = 2, $curr = 0, $indent = "")
#     
#     if ($curr -ge $depth) { return }
#     
#     try {
#         $type = $elem.Current.ControlType.ProgrammaticName -replace "ControlType\.", ""
#         $id = $elem.Current.AutomationId
#         $name = $elem.Current.Name
#         
#         Write-Host "$indent[$type] ID='$id' Name='$name'" -ForegroundColor Gray
#         
#         $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
#         $child = $walker.GetFirstChild($elem)
#         
#         while ($child -and $curr -lt $depth - 1) {
#             Show-Tree $child $depth ($curr + 1) "$indent  "
#             $child = $walker.GetNextSibling($child)
#         }
#     } catch { }
# }
# 
# Show-Tree $root -depth 2

# EXAMPLE 7: Find all buttons
# Write-Host "EXAMPLE 7: Finding all buttons in Teams..."
# 
# $buttonType = [System.Windows.Automation.ControlType]::Button
# $cond = New-Object System.Windows.Automation.PropertyCondition(
#     [System.Windows.Automation.AutomationElement]::ControlTypeProperty, $buttonType)
# $buttons = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $cond)
# 
# $count = 0
# foreach ($btn in $buttons) {
#     if ($btn.Current.Name -and $count -lt 20) {
#         Write-Host "  $($btn.Current.Name)" -ForegroundColor Yellow
#         $count++
#     }
# }

# =============================================================================
# PART 4: DISCOVERY TOOLS
# =============================================================================

Write-Host "`nDISCOVERY TOOLS:"
Write-Host "1. Inspect.exe: C:\Program Files (x86)\Windows Kits\10\bin\x64\inspect.exe"
Write-Host "   - Run, click 'Inspect Elements', click Teams UI element"
Write-Host "   - Shows exact AutomationID, ControlType, Name"
Write-Host ""
Write-Host "2. AccessibilityInsights (better):"
Write-Host "   - Download: https://microsoft.com/en-us/download/details.aspx?id=49357"
Write-Host "   - Shows complete element tree and supported patterns"
