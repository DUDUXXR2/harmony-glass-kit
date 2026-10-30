# HarmonyGlass - 验证截图 v2: SendKeys + 鼠标点击 (非提权)
# 开始菜单: Ctrl+Esc | 控制中心: 点击托盘 音量/网络 图标 | 通知中心: 点击时间区
param([string]$Tag = 'v5')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$out = Join-Path (Split-Path $PSScriptRoot) 'screenshots'
New-Item -ItemType Directory -Path $out -Force | Out-Null

$ws = [System.Windows.Forms.SystemInformation]::VirtualScreen
$W, $H = $ws.Width, $ws.Height
$b = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($b)

Add-Type -Namespace Win32 -Name Mouse -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
[DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, IntPtr dwExtraInfo);
'@

function Cap([string]$name) {
    $g.CopyFromScreen($ws.Left, $ws.Top, 0, 0, $b.Size)
    $b.Save((Join-Path $out "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "captured $name"
}
function Click-At([int]$x, [int]$y) {
    [Win32.Mouse]::SetCursorPos($x, $y) | Out-Null
    Start-Sleep -Milliseconds 220
    [Win32.Mouse]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero)   # LEFTDOWN
    [Win32.Mouse]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero)   # LEFTUP
}
function Press-Esc {
    [System.Windows.Forms.SendKeys]::SendWait('{ESC}')
    Start-Sleep -Milliseconds 700
}

Start-Sleep -Seconds 1
Cap "tb_$Tag"
# 开始菜单 (Ctrl+Esc)
[System.Windows.Forms.SendKeys]::SendWait('^{ESC}')
Start-Sleep -Seconds 2
Cap "sm_$Tag"
Press-Esc
# 控制中心: 点托盘组合图标 (音量/网络, 时间左侧约 120px)
Click-At ($W - 150) ($H - 26)
Start-Sleep -Seconds 2
Cap "cc_$Tag"
Press-Esc
# 通知中心: 点时间日期区
Click-At ($W - 75) ($H - 26)
Start-Sleep -Seconds 2
Cap "nc_$Tag"
Press-Esc
$g.Dispose(); $b.Dispose()
Write-Output 'CAPTURE-DONE'
