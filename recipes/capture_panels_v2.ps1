# DPI-aware panel capture v2: Win+A (control center) / Win+N (notification center).
# Keyboard shortcuts are far more reliable than clicking tray icons.
# Usage: powershell -File capture_panels_v2.ps1 [-Tag xxx]
param([string]$Tag = 'p')
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace Win32 -Name Dpi -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[DllImport("user32.dll")] public static extern int GetSystemMetrics(int n);
'@
[Win32.Dpi]::SetProcessDPIAware() | Out-Null
$W = [Win32.Dpi]::GetSystemMetrics(0)
$H = [Win32.Dpi]::GetSystemMetrics(1)
Write-Output "physical: $W x $H"
$out = Join-Path (Split-Path $PSScriptRoot) 'screenshots'
$b = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($b)
function Cap([string]$name) {
    $g.CopyFromScreen(0, 0, 0, 0, $b.Size)
    $b.Save((Join-Path $out "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "captured $name"
}
Add-Type -Namespace Win32 -Name KB -MemberDefinition @'
[DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, IntPtr dwExtraInfo);
'@
function Esc {
    [Win32.KB]::keybd_event(0x1B, 0x1B, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [Win32.KB]::keybd_event(0x1B, 0x1B, 2, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 700
}
function Win-Combo([byte]$key) {
    [Win32.KB]::keybd_event(0x5B, 0x5B, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 150
    [Win32.KB]::keybd_event($key, 0, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 150
    [Win32.KB]::keybd_event($key, 0, 2, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 100
    [Win32.KB]::keybd_event(0x5B, 0x5B, 2, [IntPtr]::Zero)
}
Start-Sleep -Seconds 1
Cap "p_tb_$Tag"
Win-Combo 0x41   # Win+A -> control center (respawns ShellExperienceHost if killed)
Start-Sleep -Seconds 4
Cap "p_cc_$Tag"
Esc
Win-Combo 0x4E   # Win+N -> notification center + calendar
Start-Sleep -Seconds 4
Cap "p_nc_$Tag"
Esc
$g.Dispose(); $b.Dispose()
Write-Output 'PANELS-DONE'
