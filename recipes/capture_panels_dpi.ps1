# DPI-aware 面板截图: 开始菜单 / 控制中心 / 通知中心 (物理分辨率)
# 用法: powershell -File capture_panels_dpi.ps1 [-Tag xxx]
param([string]$Tag = 'p')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace Win32 -Name Dpi -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[DllImport("user32.dll")] public static extern int GetSystemMetrics(int n);
'@
[Win32.Dpi]::SetProcessDPIAware() | Out-Null
$W = [Win32.Dpi]::GetSystemMetrics(0)
$H = [Win32.Dpi]::GetSystemMetrics(1)
$out = Join-Path (Split-Path $PSScriptRoot) 'screenshots'
$b = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($b)
function Cap([string]$name) {
    $g.CopyFromScreen(0, 0, 0, 0, $b.Size)
    $b.Save((Join-Path $out "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "captured $name"
}
Add-Type -Namespace Win32 -Name Mouse -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
[DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, IntPtr dwExtraInfo);
'@
Add-Type -Namespace Win32 -Name KB -MemberDefinition @'
[DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, IntPtr dwExtraInfo);
'@
function Click-At([int]$x, [int]$y) {
    [Win32.Mouse]::SetCursorPos($x, $y) | Out-Null
    Start-Sleep -Milliseconds 250
    [Win32.Mouse]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero)
    [Win32.Mouse]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 300
}
function Esc {
    [Win32.KB]::keybd_event(0x1B, 0x1B, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [Win32.KB]::keybd_event(0x1B, 0x1B, 2, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 700
}
function Win-Combo([byte]$key) {
    [Win32.KB]::keybd_event(0x5B, 0x5B, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 120
    [Win32.KB]::keybd_event($key, 0, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 120
    [Win32.KB]::keybd_event($key, 0, 2, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [Win32.KB]::keybd_event(0x5B, 0x5B, 2, [IntPtr]::Zero)
}

Start-Sleep -Seconds 1
# 任务栏 (含托盘)
Cap "p_tb_$Tag"
# 开始菜单 (Ctrl+Esc)
[System.Windows.Forms.SendKeys]::SendWait('^{ESC}')
Start-Sleep -Seconds 2
Cap "p_sm_$Tag"
Esc
# 控制中心: 点托盘 音量/网络 (时间左侧)。物理 H=1440, 底部约 1371-1440
Click-At ($W - 320) ($H - 35)
Start-Sleep -Seconds 2
Cap "p_cc_$Tag"
Esc
# 通知中心: 点时间区
Click-At ($W - 200) ($H - 35)
Start-Sleep -Seconds 2
Cap "p_nc_$Tag"
Esc
$g.Dispose(); $b.Dispose()
Write-Output 'PANELS-DONE'
