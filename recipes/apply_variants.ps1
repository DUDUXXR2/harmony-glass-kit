# HarmonyGlass - apply variants A/B/C with full logging (elevated).
# Every step appends to run.log; failures are caught and logged, not silent.
$ErrorActionPreference = 'Stop'
$root     = $PSScriptRoot
$proj     = Split-Path $root
$out      = Join-Path $proj 'screenshots'
$bkdir    = Join-Path $proj 'backup'
$logfile  = Join-Path $proj 'run.log'
New-Item -ItemType Directory -Path $out -Force   | Out-Null
New-Item -ItemType Directory -Path $bkdir -Force | Out-Null
"=== run $(Get-Date -Format s) ===" | Set-Content -Path $logfile -Encoding UTF8
function Log([string]$m) {
    $m | Add-Content -Path $logfile -Encoding UTF8
}
try {
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$modKey   = 'SOFTWARE\Windhawk\Engine\Mods\windows-11-taskbar-styler'
$settings = "$modKey\Settings"
$hw   = [Microsoft.Win32.Registry]::LocalMachine
$skey = $hw.OpenSubKey($settings, $true)
if ($null -eq $skey) { throw "cannot open $settings" }
Log "registry opened"

function Clear-StylerStyles {
    $names = @($skey.GetValueNames())
    foreach ($n in $names) {
        if ($n -like 'controlStyles*' -or $n -like 'styleConstants*') {
            $skey.DeleteValue($n)
        }
    }
}
function Set-Reg([string]$name, [string]$value) {
    $skey.SetValue($name, $value, [Microsoft.Win32.RegistryValueKind]::String)
}
function Set-Rule([int]$idx, [string]$target, [string[]]$styles) {
    Set-Reg ("controlStyles[$idx].target") $target
    for ($j = 0; $j -lt $styles.Count; $j++) {
        Set-Reg ("controlStyles[$idx].styles[$j]") $styles[$j]
    }
}
function Bump-ChangeTime {
    $mkey = $hw.OpenSubKey($modKey, $true)
    $unix = [int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
    $mkey.SetValue('SettingsChangeTime', $unix, [Microsoft.Win32.RegistryValueKind]::DWord)
    $mkey.Close()
}
function Restart-Explorer {
    Log "restarting explorer"
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Start-Process explorer.exe
    }
    Start-Sleep -Seconds 6
    Log "explorer restarted"
}
function Capture([string]$tag) {
    $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bmp = New-Object System.Drawing.Bitmap($b.Width, $b.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)
    $bmp.Save((Join-Path $out "full_$tag.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $h = 150
    $y0 = $b.Height - $h
    $tb = New-Object System.Drawing.Bitmap($b.Width, $h)
    $g2 = [System.Drawing.Graphics]::FromImage($tb)
    $rect = New-Object System.Drawing.Rectangle(0, $y0, $b.Width, $h)
    $g2.DrawImage($bmp, 0, 0, $rect, [System.Drawing.GraphicsUnit]::Pixel)
    $tb.Save((Join-Path $out "$tag.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $g2.Dispose(); $bmp.Dispose(); $tb.Dispose()
    Log "captured $tag"
}
function Apply-Variant([string]$tag, [string[]]$constants, [object[]]$rules) {
    Log "== variant $tag"
    Clear-StylerStyles
    for ($i = 0; $i -lt $constants.Count; $i++) {
        Set-Reg ("styleConstants[$i]") $constants[$i]
    }
    for ($i = 0; $i -lt $rules.Count; $i++) {
        Set-Rule $i $rules[$i][0] $rules[$i][1]
    }
    Bump-ChangeTime
    Restart-Explorer
    Capture $tag
    Log "variant $tag done"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bk = Join-Path $bkdir "tb-styler-before-ABC-$stamp.reg"
reg export "HKLM\$settings" $bk /y | Out-Null
Log "backup -> $bk"

Restart-Explorer
Capture 'baseline'

# ---- A: basic glass ----
$A_Glass = 'GlassBackground=<WindhawkBlur BlurAmount="28" TintColor="#FF252830" TintOpacity="0.16" TintLuminosityOpacity="0.08" TintSaturation="1.25" FallbackColor="#E6252830" />'
Apply-Variant 'A_basic' @($A_Glass) @(
    @('Taskbar.TaskbarFrame > Grid#RootGrid > Taskbar.TaskbarBackground > Grid > Rectangle#BackgroundFill', @('Fill:=$GlassBackground')),
    @('Rectangle#BackgroundStroke', @('Visibility=Collapsed'))
)

# ---- B: + edges ----
$B_HL = 'EdgeHighlight=<LinearGradientBrush StartPoint="0,0" EndPoint="0,1">' +
        '<GradientStop Color="#66FFFFFF" Offset="0.0" />' +
        '<GradientStop Color="#26FFFFFF" Offset="0.08" />' +
        '<GradientStop Color="#14FFFFFF" Offset="0.5" />' +
        '<GradientStop Color="#00FFFFFF" Offset="1.0" /></LinearGradientBrush>'
$B_Dark = 'EdgeShadow=<SolidColorBrush Color="#141414" />'
Apply-Variant 'B_edge' @($A_Glass, $B_HL, $B_Dark) @(
    @('Taskbar.TaskbarFrame > Grid#RootGrid > Taskbar.TaskbarBackground > Grid > Rectangle#BackgroundFill', @('Fill:=$GlassBackground')),
    @('Rectangle#BackgroundStroke', @('Visibility=1','Height=2','VerticalAlignment=0','Fill:=$EdgeHighlight')),
    @('Taskbar.TaskbarFrame', @('BorderThickness=0,1.5,0,0','BorderBrush:=$EdgeHighlight'))
)

# ---- C: cool cyan ----
$C_Glass = 'GlassBackground=<WindhawkBlur BlurAmount="30" TintColor="#FF262B33" TintOpacity="0.14" TintLuminosityOpacity="0.07" TintSaturation="1.28" FallbackColor="#E6262B33" />'
$C_HL = 'EdgeHighlight=<LinearGradientBrush StartPoint="0,0" EndPoint="0,1">' +
        '<GradientStop Color="#73EAF6FF" Offset="0.0" />' +
        '<GradientStop Color="#2BEAF6FF" Offset="0.10" />' +
        '<GradientStop Color="#12FFFFFF" Offset="0.55" />' +
        '<GradientStop Color="#00FFFFFF" Offset="1.0" /></LinearGradientBrush>'
Apply-Variant 'C_final' @($C_Glass, $C_HL) @(
    @('Taskbar.TaskbarFrame > Grid#RootGrid > Taskbar.TaskbarBackground > Grid > Rectangle#BackgroundFill', @('Fill:=$GlassBackground')),
    @('Rectangle#BackgroundStroke', @('Visibility=1','Height=2','VerticalAlignment=0','Fill:=$EdgeHighlight')),
    @('Taskbar.TaskbarFrame', @('BorderThickness=0,1.5,0,0','BorderBrush:=$EdgeHighlight'))
)

Log 'ALL-DONE'
} catch {
    Log "FATAL: $($_.Exception.Message)"
    Log $_.ScriptStackTrace
    throw
}
