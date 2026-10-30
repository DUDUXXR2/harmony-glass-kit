# 开始菜单文字自动反色 v2: 采样壁纸开始菜单区域亮度 -> 文字翻转深/浅。
# 机制: 向 start-menu styler 写 Foreground 规则 + bump SettingsChangeTime 热重载。
# 阈值: 壁纸 luma > 0.5 = 亮背景 -> 深色字; <= 0.5 = 暗背景 -> 白字。
# 用法: powershell -File apply_text_contrast.ps1 [-Mode auto|light|dark|off]
#   auto  = 采样壁纸开始菜单区域自动决定 (默认)
#   light = 强制深色字 (亮壁纸)
#   dark  = 强制白色字 (暗壁纸)
#   off   = 删除全部文字规则 (恢复系统默认)
param([string]$Mode = 'auto')
if ($env:TEMP -like 'C:*') { $env:TEMP = 'E:\ToolCache\Temp'; $env:TMP = 'E:\ToolCache\Temp' }
$proj = Split-Path $PSScriptRoot
$py   = Join-Path $proj 'recipes\sample_wallpaper_luma.py'

# --- 决定文字色 (采样壁纸开始菜单所在屏幕区域, 物理 2560x1440 下约 290,1050 - 1180,1300) ---
$luma = $null
if ($Mode -eq 'auto') {
    $out = & python $py --rect 290,1050,1180,1300 2>$null
    $ml = $out | Select-String -Pattern 'luma = ([0-9.]+)'
    if ($ml) { $luma = [double]$ml.Matches[0].Groups[1].Value }
    if ($null -eq $luma) { Write-Output 'ERROR: wallpaper luma sampling failed'; exit 1 }
    if ($luma -gt 0.5) { $textMode = 'light' } else { $textMode = 'dark' }
    Write-Output "wallpaper luma(start-menu region) = $luma -> text mode: $textMode"
} else {
    $textMode = $Mode
}

# --- 文字色规则 (追加到现有规则尾部, 索引 10 起; 现有规则为 0-9) ---
# 白字版: 官方主题同款 TextBlock 全集 (社区主题验证过的写法)
$lightText = @(
    'TextBlock#Text | Foreground=White',
    'TextBlock#PinnedListHeaderText | Foreground=White',
    'TextBlock#AllListHeadingText | Foreground=White',
    'TextBlock#UserTileNameText | Foreground=White',
    'TextBlock#DisplayName | Foreground=White',
    'TextBlock#NoPinnedSuggestionsHeaderText | Foreground=White',
    'TextBlock#AllAppsHeading | Foreground=White',
    'TextBlock#TopLevelSuggestionsListHeaderText | Foreground=White'
)
$darkText = @(
    'TextBlock#Text | Foreground=#FF1A1A1A',
    'TextBlock#PinnedListHeaderText | Foreground=#FF1A1A1A',
    'TextBlock#AllListHeadingText | Foreground=#FF1A1A1A',
    'TextBlock#UserTileNameText | Foreground=#FF1A1A1A',
    'TextBlock#DisplayName | Foreground=#FF1A1A1A',
    'TextBlock#NoPinnedSuggestionsHeaderText | Foreground=#FF1A1A1A',
    'TextBlock#AllAppsHeading | Foreground=#FF1A1A1A',
    'TextBlock#TopLevelSuggestionsListHeaderText | Foreground=#FF1A1A1A'
)

$hw = [Microsoft.Win32.Registry]::LocalMachine
$sk = $hw.OpenSubKey('SOFTWARE\Windhawk\Engine\Mods\windows-11-start-menu-styler\Settings', $true)
if ($null -eq $sk) { throw 'cannot open start-menu-styler settings' }

# 清掉旧 themeResourceVariables (v1 自引用方案已废弃)
foreach ($n in @($sk.GetValueNames())) {
    if ($n.StartsWith('themeResourceVariables[')) { $sk.DeleteValue($n) }
}

# 清掉本脚本旧文字规则 (索引 >= 10)
foreach ($n in @($sk.GetValueNames())) {
    if ($n -match '^controlStyles\[(\d+)\]' -and [int]$Matches[1] -ge 10) { $sk.DeleteValue($n) }
}

if ($textMode -ne 'off') {
    $rules = if ($textMode -eq 'dark') { $lightText } else { $darkText }
    $idx = 10
    foreach ($r in $rules) {
        $parts = $r.Split('|')
        $target = $parts[0].Trim()
        $style = $parts[1].Trim()
        $sk.SetValue("controlStyles[$idx].target", $target, [Microsoft.Win32.RegistryValueKind]::String)
        $sk.SetValue("controlStyles[$idx].styles[0]", $style, [Microsoft.Win32.RegistryValueKind]::String)
        $idx++
    }
    Write-Output "text rules written: $($idx - 10) rules from index 10, mode=$textMode"
} else {
    Write-Output 'text rules removed (mode=off)'
}
$sk.Close()

$mkey = $hw.OpenSubKey('SOFTWARE\Windhawk\Engine\Mods\windows-11-start-menu-styler', $true)
$mkey.SetValue('SettingsChangeTime', [int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()), [Microsoft.Win32.RegistryValueKind]::DWord)
$mkey.Close()
Write-Output 'start-menu-styler bumped (hot-reload ~1-2s)'
