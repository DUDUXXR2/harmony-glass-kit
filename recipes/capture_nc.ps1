# 捕获通知中心 (Win+N) 和媒体卡片 - 通过 keybd_event
param([string]$Tag = 'v5')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace Win32 -Name KB -MemberDefinition @'
[DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, IntPtr dwExtraInfo);
'@
$out = Join-Path (Split-Path $PSScriptRoot) 'screenshots'
$ws = [System.Windows.Forms.SystemInformation]::VirtualScreen
$b = New-Object System.Drawing.Bitmap($ws.Width, $ws.Height)
$g = [System.Drawing.Graphics]::FromImage($b)
function Cap([string]$name) {
    $g.CopyFromScreen($ws.Left, $ws.Top, 0, 0, $b.Size)
    $b.Save((Join-Path $out "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "captured $name"
}
function Win-Combo([byte]$key) {
    [Win32.KB]::keybd_event(0x5B, 0x5B, 0, [IntPtr]::Zero)   # Win down
    Start-Sleep -Milliseconds 120
    [Win32.KB]::keybd_event($key, 0, 0, [IntPtr]::Zero)      # key down
    Start-Sleep -Milliseconds 120
    [Win32.KB]::keybd_event($key, 0, 2, [IntPtr]::Zero)      # key up
    Start-Sleep -Milliseconds 60
    [Win32.KB]::keybd_event(0x5B, 0x5B, 2, [IntPtr]::Zero)   # Win up
}
function Esc { [Win32.KB]::keybd_event(0x1B, 0x1B, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 60; [Win32.KB]::keybd_event(0x1B, 0x1B, 2, [IntPtr]::Zero); Start-Sleep -Milliseconds 700 }

Start-Sleep -Seconds 1
# 通知中心 Win+N
Win-Combo 0x4E
Start-Sleep -Seconds 2
Cap "nc2_$Tag"
Esc
# 日历/时间面板: 点击时钟 (最右下角)
Add-Type -Namespace Win32 -Name Mouse -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
[DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, IntPtr dwExtraInfo);
'@
[Win32.Mouse]::SetCursorPos(($ws.Width - 30), ($ws.Height - 26)) | Out-Null
Start-Sleep -Milliseconds 250
[Win32.Mouse]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero)
[Win32.Mouse]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero)
Start-Sleep -Seconds 2
Cap "cal_$Tag"
Esc
$g.Dispose(); $b.Dispose()
Write-Output 'DONE'
