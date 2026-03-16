# Dev Box Keep-Alive — prevents auto-stop due to inactivity
# Runs every 4 minutes, sends a harmless keystroke to prevent idle detection
# Deploy: Start-Process pwsh -ArgumentList "-NoProfile -File keep-devbox-alive.ps1" -WindowStyle Hidden

$Host.UI.RawUI.WindowTitle = "DevBox Keep-Alive"
Write-Host "DevBox Keep-Alive started at $(Get-Date). Pinging every 4 minutes..."

while ($true) {
    Start-Sleep -Seconds 240  # 4 minutes
    
    # Method 1: Move mouse 1 pixel and back (prevents idle detection)
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class MouseKeepAlive {
        [DllImport("user32.dll")]
        public static extern bool SetCursorPos(int X, int Y);
        [DllImport("user32.dll")]
        public static extern bool GetCursorPos(out POINT lpPoint);
        [StructLayout(LayoutKind.Sequential)]
        public struct POINT { public int X; public int Y; }
        
        public static void Jiggle() {
            POINT p;
            GetCursorPos(out p);
            SetCursorPos(p.X + 1, p.Y);
            System.Threading.Thread.Sleep(50);
            SetCursorPos(p.X, p.Y);
        }
    }
"@ -ErrorAction SilentlyContinue
    
    try { [MouseKeepAlive]::Jiggle() } catch {}
    
    # Method 2: Touch a temp file (some monitoring checks file activity)
    $heartbeat = Join-Path $env:USERPROFILE ".devbox-keepalive"
    Get-Date -Format "yyyy-MM-ddTHH:mm:ss" | Out-File $heartbeat -Force
    
    # Log quietly
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] keepalive ping" -ForegroundColor DarkGray
}
