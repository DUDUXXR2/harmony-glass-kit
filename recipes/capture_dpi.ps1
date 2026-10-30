# DPI-aware 截图: SetProcessDPIAware -> 按物理分辨率整屏抓取
# 用法: powershell -File capture_dpi.ps1 [-Tag xxx]
param([string]$Tag = 'dpi')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -Namespace Win32 -Name Dpi -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[DllImport("user32.dll")] public static extern int GetSystemMetrics(int n);
'@
[Win32.Dpi]::SetProcessDPIAware() | Out-Null
$W = [Win32.Dpi]::GetSystemMetrics(0)   # SM_CXSCREEN 物理宽
$H = [Win32.Dpi]::GetSystemMetrics(1)   # SM_CYSCREEN 物理高
Write-Output "physical: $W x $H"
$out = Join-Path (Split-Path $PSScriptRoot) 'screenshots'
$b = New-Object System.Drawing.Bitmap($W, $H)
$g = [System.Drawing.Graphics]::FromImage($b)
$g.CopyFromScreen(0, 0, 0, 0, $b.Size)
$b.Save((Join-Path $out "desk_$Tag.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $b.Dispose()
Write-Output "saved desk_$Tag.png"
