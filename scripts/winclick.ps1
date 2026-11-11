# Activate a window, then click at an absolute screen position - in one process.
#
# Why this exists: the DSH host window steals the foreground between tool calls,
# so an "activate" and a "click" issued as two separate calls can land the click
# on the wrong window. Doing both here keeps the window focused at click time.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File winclick.ps1 -X 628 -Y 903
#   powershell ... -File winclick.ps1 -X 628 -Y 903 -Hwnd 1379132
#   powershell ... -File winclick.ps1 -X 628 -Y 903 -Clicks 2
#   powershell ... -File winclick.ps1 -X 628 -Y 903 -NoActivate   # just click
#
# Find -Hwnd with: Get-Process DingTalk | Select-Object MainWindowHandle

param(
    [Parameter(Mandatory = $true)][int]$X,
    [Parameter(Mandatory = $true)][int]$Y,
    [int]$Hwnd = 0,
    [int]$Clicks = 1,
    [switch]$NoActivate
)

$sig = @'
using System;
using System.Runtime.InteropServices;
public class WClick {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
}
'@
if (-not ("WClick" -as [type])) { Add-Type -TypeDefinition $sig }

if (-not $NoActivate -and $Hwnd -ne 0) {
    $h = [IntPtr]$Hwnd
    $null = [WClick]::ShowWindow($h, 9)   # SW_RESTORE
    $t2 = [WClick]::GetWindowThreadProcessId($h, [ref]([uint32]0))
    $cur = [WClick]::GetCurrentThreadId()
    [WClick]::AttachThreadInput($cur, $t2, $true) | Out-Null
    [WClick]::BringWindowToTop($h) | Out-Null
    $null = [WClick]::SetForegroundWindow($h)
    [WClick]::AttachThreadInput($cur, $t2, $false) | Out-Null
    Start-Sleep -Milliseconds 250
}

[WClick]::SetCursorPos($X, $Y) | Out-Null
Start-Sleep -Milliseconds 80
for ($i = 0; $i -lt $Clicks; $i++) {
    [WClick]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)   # LEFT DOWN
    Start-Sleep -Milliseconds 40
    [WClick]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)   # LEFT UP
    Start-Sleep -Milliseconds 120
}

"clicked $X,$Y fg=$([WClick]::GetForegroundWindow())"
