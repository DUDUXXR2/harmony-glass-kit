# 打开开始菜单并截图: capture_start.ps1 [-Tag xxx]
# Win 键开菜单 -> 4s 渲染 -> DPI-aware 截图 -> Esc 关闭
param([string]$Tag = 'start')
if ($env:TEMP -like 'C:*') { $env:TEMP = 'E:\ToolCache\Temp'; $env:TMP = 'E:\ToolCache\Temp' }
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace Win32 -Name Dpi -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[DllImport("user32.dll")] public static extern int GetSystemMetrics(int n);
'@
[Win32.Dpi]::SetProcessDPIAware() | Out-Null
$W = [Win32.Dpi]::GetSystemMetrics(0)
$H = [Win32.Dpi]::GetSystemMetrics(1)
$out = Join-Path (Split-Path $PSScriptRoot) 'screenshots'
Add-Type -Namespace Win32 -Name KB -MemberDefinition @'
[DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, IntPtr dwExtraInfo);
'@
function Press([byte]$vk) {
    [Win32.KB]::keybd_event($vk, $vk, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 120
    [Win32.KB]::keybd_event($vk, $vk, 2, [IntPtr]::Zero)
}
function Cap {
    $b = New-Object System.Drawing.Bitmap($W, $H)
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.CopyFromScreen(0, 0, 0, 0, $b.Size)
    $b.Save((Join-Path $out "start_$Tag.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $b.Dispose()
    Write-Output "captured start_$Tag.png ($W x $H)"
}
Start-Sleep -Milliseconds 600
Press 0x5B       # Win -> open start menu
Start-Sleep -Seconds 4
Cap
Press 0x1B       # Esc -> close
Write-Output 'START-DONE'
