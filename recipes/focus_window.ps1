# Bring a window to front: focus_window.ps1 <hwnd-hex-or-decimal>
param([string]$Hwnd)
# PS 5.1: [IntPtr] cast rejects UInt64 - go through [Int64] (ToInt64 accepts 0x-prefixed hex too)
$h = [IntPtr][Int64]$Hwnd
Add-Type -Namespace W -Name F -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
'@
[W.F]::ShowWindow($h, 9) | Out-Null     # SW_RESTORE
Start-Sleep -Milliseconds 400
[W.F]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 600
"visible=$([W.F]::IsWindowVisible($h)) hwnd=$h"
