# HarmonyGlass 全局材质应用器 v3 (elevated) — 默认热重载, 秒级生效
# 用法: sudo powershell -File <本项目路径>\recipes\apply_material.ps1 [-Material <path>] [-Restart]
# 改 material.json 后重跑本脚本即可全局生效 (默认不重启 explorer)。日志 -> HarmonyGlass\run.log
param(
    [string]$Material = (Join-Path (Split-Path $PSScriptRoot) 'material.json'),
    [switch]$Restart
)
$ErrorActionPreference = 'Stop'
$proj     = Split-Path $PSScriptRoot
$logfile  = Join-Path $proj 'run.log'
$bkdir    = Join-Path $proj 'backup'
New-Item -ItemType Directory -Path $bkdir -Force | Out-Null
"=== apply_material $(Get-Date -Format s) ===" | Add-Content -Path $logfile -Encoding UTF8
function Log([string]$m) { $m | Add-Content -Path $logfile -Encoding UTF8 }

try {
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------- material ----------
$mat  = Get-Content -Raw -Encoding UTF8 -Path $Material | ConvertFrom-Json
$blur = $mat.blur; $rad = $mat.radius; $edge = $mat.edge; $sur = $mat.surfaces
Log ("material v" + $mat.version + " blur=" + $blur.amount + " tint=" + $blur.tintColor +
     " o=" + $blur.tintOpacity + " sat=" + $blur.tintSaturation)

function MkGlass([string]$name, [double]$amount) {
    # 注意: WindhawkBlur 只支持 BlurAmount/TintColor/TintOpacity/TintLuminosityOpacity/TintSaturation/NoiseOpacity/NoiseDensity
    # (无 FallbackColor — 模糊不可用时引擎自动退化为纯 tint 渲染)
    ('{0}=<WindhawkBlur BlurAmount="{1}" TintColor="{2}" TintOpacity="{3}" TintLuminosityOpacity="{4}" TintSaturation="{5}"{6} />' -f
        $name, $amount, $blur.tintColor, $blur.tintOpacity, $blur.tintLuminosityOpacity, $blur.tintSaturation, $NoiseAttr)
}
# 注意: 引擎常量按前缀匹配、先到先得 -> GlassBlur/GlassLite 互不为前缀, 顺序无关
$NoiseAttr = ''
if ($blur.PSObject.Properties['noiseOpacity'] -and $blur.noiseOpacity -gt 0) {
    $NoiseAttr = ' NoiseOpacity="{0}" NoiseDensity="{1}"' -f $blur.noiseOpacity, $blur.noiseDensity
}
$GlassBlur  = MkGlass 'GlassBlur'  $blur.amount
$GlassLite  = MkGlass 'GlassLite' $blur.amountLite
# 边缘光: 顶部冷白亮带 -> 中段微光; 底部微光 (两条渐变, 近似参考的边缘折射)
$HLTop = 'EdgeHighlightTop=<LinearGradientBrush StartPoint="0,0" EndPoint="0,1">' +
      ('<GradientStop Color="{0}" Offset="0.0" />' -f $edge.highlightTop) +
      ('<GradientStop Color="{0}" Offset="0.10" />' -f $edge.highlightTop2) +
      '<GradientStop Color="#08FFFFFF" Offset="0.5" />' +
      '<GradientStop Color="#00FFFFFF" Offset="1.0" /></LinearGradientBrush>'
$HLBot = 'EdgeHighlightBot=<LinearGradientBrush StartPoint="0,1" EndPoint="0,0">' +
         ('<GradientStop Color="{0}" Offset="0.0" />' -f $edge.highlightBottom) +
         '<GradientStop Color="#00FFFFFF" Offset="1.0" /></LinearGradientBrush>'
$Dark = 'EdgeDark=<SolidColorBrush Color="{0}" />' -f $edge.darkStroke
# 面板描边刷: 竖直渐变 — 顶描边采样 offset0 (冰白镜面), 底描边采样 offset1 (白背光), 侧描边取中段
$PanelBorder = 'PanelBorder=<LinearGradientBrush StartPoint="0,0" EndPoint="0,1">' +
               ('<GradientStop Color="{0}" Offset="0.0" />' -f $edge.highlightTop) +
               '<GradientStop Color="#18FFFFFF" Offset="0.35" />' +
               ('<GradientStop Color="{0}" Offset="1.0" />' -f $edge.highlightBottom) +
               '</LinearGradientBrush>'
# 任务栏段与面板共用 PanelBorder 常量

$hw = [Microsoft.Win32.Registry]::LocalMachine
function Open-Settings([string]$modId) {
    $k = $hw.OpenSubKey("SOFTWARE\Windhawk\Engine\Mods\$modId\Settings", $true)
    if ($null -eq $k) { throw "cannot open $modId settings" }
    $k
}
function Clear-Styler([object]$k) {
    foreach ($n in @($k.GetValueNames())) {
        if ($n -like 'controlStyles*' -or $n -like 'styleConstants*') { $k.DeleteValue($n) }
    }
}
function Set-Reg([object]$k, [string]$name, [string]$value) {
    $k.SetValue($name, $value, [Microsoft.Win32.RegistryValueKind]::String)
}
function Set-Rule([object]$k, [int]$idx, [string]$target, [string[]]$styles) {
    Set-Reg $k "controlStyles[$idx].target" $target
    for ($j = 0; $j -lt $styles.Count; $j++) {
        Set-Reg $k "controlStyles[$idx].styles[$j]" $styles[$j]
    }
}
function Backup-Mod([string]$modId) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $bk = Join-Path $bkdir "$modId-before-$stamp.reg"
    reg export "HKLM\SOFTWARE\Windhawk\Engine\Mods\$modId" $bk /y | Out-Null
    Log "backup $modId -> $bk"
}
function Bump-ChangeTime([string]$modId) {
    $mkey = $hw.OpenSubKey("SOFTWARE\Windhawk\Engine\Mods\$modId", $true)
    $mkey.SetValue('SettingsChangeTime', [int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()),
                   [Microsoft.Win32.RegistryValueKind]::DWord)
    $mkey.Close()
}
# 热重载: 引擎监测 SettingsChangeTime, bump 后线程内重载样式 (无 explorer 重启, ~1-2s 生效)
# 验证: taskbar styler L9760 / NC styler L5389 均实现 Wh_ModSettingsChanged 遍历宿主窗口热应用
function Stop-ShellHosts {
    Stop-Process -Name ShellExperienceHost -Force -ErrorAction SilentlyContinue
    Stop-Process -Name ShellHost -Force -ErrorAction SilentlyContinue
}
function Restart-Explorer {
    Log "restarting explorer + shell hosts"
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    # NC styler 宿主 (控制中心/通知中心/媒体卡) 不随 explorer 重启, 忔须单独杀
    Stop-ShellHosts
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    Start-Sleep -Seconds 6
    Log "explorer restarted"
}

# ================================================================ TASKBAR
if ($sur.taskbar) {
    Backup-Mod 'windows-11-taskbar-styler'
    $k = Open-Settings 'windows-11-taskbar-styler'
    Clear-Styler $k
    0..7 | ForEach-Object { Set-Reg $k "styleConstants[$_]" @($GlassBlur, $GlassLite, $HLTop, $HLBot, $Dark, "PillR=$($rad.taskbarPill)", "ElemR=$($rad.element)", $PanelBorder)[($_)] }
    $i = 0
    # --- 华为贴底全宽骨架: RootGrid 承载玻璃(已验证渲染), Margin=0 贴底; 上下双缘高光线 (近似 |dot(n,45°)| 对称镜面) ---
    Set-Rule $k $i 'Taskbar.TaskbarFrame > Grid#RootGrid' @(
        'Margin=0,0,0,0', "BorderThickness=$($edge.borderThickness)", 'BorderBrush:=$PanelBorder',
        "CornerRadius=$($rad.taskbarPill)", 'Background:=$GlassBlur'); $i++
    Set-Rule $k $i 'Taskbar.TaskbarBackground#BackgroundControl > Grid > Rectangle#BackgroundFill' @('Visibility=Collapsed'); $i++
    Set-Rule $k $i 'Taskbar.TaskbarBackground#BackgroundControl > Grid > Rectangle#BackgroundStroke' @('Visibility=Collapsed'); $i++
    # 顶部/底部边缘光 (边缘折射近似: 亮带在胶囊上缘 10% 内)
    Set-Rule $k $i 'Grid#SystemTrayFrameGrid' @(
        'Margin=0,8,8,7', 'Background:=Transparent', 'BorderThickness=0', "CornerRadius=$($rad.element)"); $i++
    Set-Rule $k $i 'SystemTray.ChevronIconView' @('Padding=2,4,2,4', "CornerRadius=$($rad.element)", 'Margin=5,0,0,0'); $i++
    Set-Rule $k $i 'SystemTray.NotifyIconView#NotifyItemIcon' @('Padding=2,4,2,4', "CornerRadius=$($rad.element)", 'Margin=5,0,0,0'); $i++
    Set-Rule $k $i 'SystemTray.OmniButton' @('Padding=2,4,2,4', "CornerRadius=$($rad.element)"); $i++
    Set-Rule $k $i 'SystemTray.OmniButton#NotificationCenterButton > Grid > ContentPresenter > ItemsPresenter > StackPanel > ContentPresenter > systemtray:IconView#SystemTrayIcon > Grid' @('Padding=2,4,2,4'); $i++
    Set-Rule $k $i 'SystemTray.IconView#SystemTrayIcon > Grid#ContainerGrid > ContentPresenter#ContentPresenter > Grid#ContentGrid > SystemTray.TextIconContent > Grid#ContainerGrid' @('Padding=10', "CornerRadius=$($rad.element)"); $i++
    Set-Rule $k $i 'SystemTray.Stack#ShowDesktopStack' @('Visibility=Visible'); $i++
    Set-Rule $k $i 'Windows.UI.Xaml.Controls.Grid#AugmentedEntryPointContentGrid' @('Margin=4,0,0,0'); $i++
    # --- 托盘弹层/菜单/溢出: 统一玻璃 ---
    Set-Rule $k $i 'Windows.UI.Xaml.Controls.Border#OverflowFlyoutBackgroundBorder' @(
        'Background:=$GlassBlur', 'BorderBrush:=$PanelBorder', "BorderThickness=$($edge.borderThickness)", "CornerRadius=$($rad.panel)"); $i++
    Set-Rule $k $i 'Windows.UI.Xaml.Controls.MenuFlyoutPresenter > Windows.UI.Xaml.Controls.Border' @(
        'Background:=$GlassBlur', 'BorderBrush:=$PanelBorder', "BorderThickness=$($edge.borderThickness)", "CornerRadius=$($rad.panel)"); $i++
    Set-Rule $k $i 'Windows.UI.Xaml.Controls.Grid#ConfirmatorMainGrid' @(
        "CornerRadius=$($rad.panel)", "BorderThickness=$($edge.borderThickness)", 'BorderBrush:=$PanelBorder', 'Background:=$GlassBlur'); $i++
    Set-Rule $k $i 'Windows.UI.Xaml.Controls.ToolTip > ContentPresenter#LayoutRoot' @(
        'Background:=$GlassLite', "BorderThickness=$($edge.borderThickness)", 'BorderBrush:=$PanelBorder', "CornerRadius=$($rad.element)"); $i++
    Set-Rule $k $i 'Grid#HoverFlyoutGrid > Border#HoverFlyoutBackground' @(
        'Background:=$GlassBlur', "BorderThickness=$($edge.borderThickness)", 'BorderBrush:=$PanelBorder', "CornerRadius=$($rad.panel)"); $i++
    Set-Rule $k $i 'Grid#ModalRootGrid > Border#BackgroundElement' @(
        "BorderThickness=$($edge.borderThickness)", 'BorderBrush:=$PanelBorder', 'Background:=Transparent', "CornerRadius=$($rad.panel)"); $i++
    Set-Rule $k $i 'Grid#ModalRootGrid > Border#BackgroundElement > WindowsInternal.ComposableShell.Experiences.Switcher.SwitchItemList' @('Background:=$GlassBlur'); $i++
    Set-Rule $k $i 'WindowsInternal.ComposableShell.Experiences.Switcher.VirtualDesktopBarElement#VirtualDesktopBar > Grid > Border' @(
        "BorderThickness=$($edge.borderThickness)", 'BorderBrush:=$PanelBorder', 'Background:=$GlassBlur', "CornerRadius=$($rad.panel)"); $i++
    Set-Rule $k $i 'Border#BackgroundDimmingLayer' @('Background:=Transparent'); $i++
    Set-Rule $k $i 'Taskbar.TaskListButtonPanel#ExperienceToggleButtonRootPanel > Border#BackgroundElement' @("CornerRadius=$($rad.element)"); $i++
    Set-Rule $k $i 'Taskbar.TaskListButton#TaskListButton' @("CornerRadius=$($rad.element)"); $i++
    Set-Rule $k $i 'Border#SnapBarBorder' @('Background:=$GlassBlur', 'BorderBrush:=$PanelBorder', "CornerRadius=$($rad.panel)", "BorderThickness=$($edge.borderThickness)", 'RenderTransform:=<TranslateTransform X="0" Y="10" />', 'Margin=0,0,0,-10'); $i++
    Set-Rule $k $i 'Border#SnapPickerBorder' @('Background:=$GlassBlur', 'BorderBrush:=$PanelBorder', "CornerRadius=$($rad.panel)", "BorderThickness=$($edge.borderThickness)"); $i++
    Bump-ChangeTime 'windows-11-taskbar-styler'
    $k.Close()
    Log "taskbar-styler written ($i rules)"
}

# ============================================================ START MENU
if ($sur.startMenu) {
    Backup-Mod 'windows-11-start-menu-styler'
    $k = Open-Settings 'windows-11-start-menu-styler'
    Clear-Styler $k
    Set-Reg $k 'styleConstants[0]' $GlassBlur
    Set-Reg $k 'styleConstants[1]' $GlassLite
    Set-Reg $k 'styleConstants[2]' $PanelBorder
    Set-Reg $k 'styleConstants[3]' $Dark
    Set-Reg $k 'styleConstants[4]' "CornerRadius=$($rad.panel)"
    Set-Reg $k 'styleConstants[5]' "ElementCornerRadius=$($rad.element)"
    Set-Reg $k 'styleConstants[6]' "BorderThickness=$($edge.borderThickness)"
    $i = 0
    Set-Rule $k $i 'Border#AcrylicBorder' @('Background:=$GlassBlur', 'CornerRadius=$CornerRadius', 'BorderBrush:=$PanelBorder', 'BorderThickness=$BorderThickness'); $i++
    Set-Rule $k $i 'Border#AppBorder' @('Background:=$GlassBlur', 'CornerRadius=$CornerRadius', 'BorderBrush:=$PanelBorder', 'BorderThickness=$BorderThickness'); $i++
    Set-Rule $k $i 'Border#AcrylicOverlay' @('Visibility=Collapsed'); $i++
    Set-Rule $k $i 'Border#AccentAppBorder' @('Background:=$GlassBlur', 'CornerRadius=$CornerRadius', 'BorderBrush:=$PanelBorder', 'BorderThickness=$BorderThickness'); $i++
    Set-Rule $k $i 'Border#LayerBorder' @('Visibility=Collapsed'); $i++
    # 元素级
    Set-Rule $k $i 'Windows.UI.Xaml.Controls.Border#BorderElement' @('Background:=$GlassLite', 'CornerRadius=$ElementCornerRadius', 'BorderThickness=0'); $i++
    Set-Rule $k $i 'MenuFlyoutPresenter > Border' @('Background:=$GlassBlur', 'CornerRadius=$CornerRadius', 'BorderBrush:=$PanelBorder', 'BorderThickness=$BorderThickness'); $i++
    Set-Rule $k $i 'Border#TaskbarSearchBackground' @('Background:=$GlassLite', 'CornerRadius=$ElementCornerRadius', 'BorderThickness=0'); $i++
    Set-Rule $k $i 'Windows.UI.Xaml.Controls.Button > Windows.UI.Xaml.Controls.Border#BackgroundBorder' @('Background:=$GlassLite', 'CornerRadius=$ElementCornerRadius'); $i++
    Set-Rule $k $i 'Grid@SearchBoxInputStates > Border#TaskbarSearchBackground' @('Background:=$GlassLite', 'CornerRadius=$ElementCornerRadius'); $i++
    Bump-ChangeTime 'windows-11-start-menu-styler'
    $k.Close()
    Log "start-menu-styler written ($i rules)"
}

# ==================================== NOTIFICATION / CONTROL / MEDIA (NC styler)
if ($sur.notificationCenter -or $sur.controlCenter -or $sur.media) {
    Backup-Mod 'windows-11-notification-center-styler'
    $k = Open-Settings 'windows-11-notification-center-styler'
    Clear-Styler $k
    Set-Reg $k 'styleConstants[0]' $GlassBlur
    Set-Reg $k 'styleConstants[1]' $GlassLite
    Set-Reg $k 'styleConstants[2]' $PanelBorder
    Set-Reg $k 'styleConstants[3]' $Dark
    Set-Reg $k 'styleConstants[4]' "Radius=$($rad.panel)"
    Set-Reg $k 'styleConstants[5]' "RadiusSmall=$($rad.element)"
    Set-Reg $k 'styleConstants[6]' 'Accent=<SolidColorBrush Color="{ThemeResource SystemAccentColorLight1}" Opacity="1" />'
    Set-Reg $k 'styleConstants[7]' 'Transparent=<SolidColorBrush Color="Transparent" />'
    $i = 0
    # --- 通知中心 / 日历 ---
    Set-Rule $k $i 'Grid#NotificationCenterGrid' @('Background:=$GlassBlur', "CornerRadius=$($rad.panel)", "BorderThickness=$($edge.borderThickness)", 'BorderBrush:=$PanelBorder'); $i++
    Set-Rule $k $i 'Grid#CalendarCenterGrid' @('Background:=$GlassBlur', "CornerRadius=$($rad.panel)", "BorderThickness=$($edge.borderThickness)", 'BorderBrush:=$PanelBorder'); $i++
    # --- 控制中心 (快速设置) ---
    Set-Rule $k $i 'Grid#ControlCenterRegion' @('Background:=$GlassBlur', "CornerRadius=$($rad.panel)", "BorderThickness=$($edge.borderThickness)", 'BorderBrush:=$PanelBorder'); $i++
    Set-Rule $k $i 'Grid#L1Grid > Border' @('Background:=Transparent', 'BorderThickness=0'); $i++
    # --- 媒体控制 (SMTC 卡片) ---
    Set-Rule $k $i 'Windows.UI.Xaml.Controls.Grid#MediaTransportControlsRegion' @('Background:=$GlassBlur', "CornerRadius=$($rad.panel)", "BorderThickness=$($edge.borderThickness)", 'BorderBrush:=$PanelBorder'); $i++
    Set-Rule $k $i 'Grid#MediaTransportControlsRoot' @('Background:=Transparent'); $i++
    # --- 通知 toast ---
    Set-Rule $k $i 'ActionCenter.FlexibleToastView#FlexibleNormalToastView' @('Background:=Transparent'); $i++
    Set-Rule $k $i 'ActionCenter.FlexibleItemView' @("CornerRadius=$($rad.element)"); $i++
    # --- 弹层/跳转列表 ---
    Set-Rule $k $i 'MenuFlyoutPresenter > Border' @('Background:=$GlassBlur', "CornerRadius=$($rad.panel)", "BorderThickness=$($edge.borderThickness)", 'BorderBrush:=$PanelBorder', 'Padding=2,4,2,4'); $i++
    Set-Rule $k $i 'Border#JumpListRestyledAcrylic' @('Background:=$GlassBlur', "CornerRadius=$($rad.panel)", "BorderThickness=$($edge.borderThickness)", 'BorderBrush:=$PanelBorder', 'Margin=-2,-2,-2,-2'); $i++
    # --- 专注会话/日历顶栏透明化, 防止双层玻璃 ---
    Set-Rule $k $i 'ScrollViewer#CalendarControlScrollViewer' @('Background:=$Transparent', 'BorderThickness=0'); $i++
    Set-Rule $k $i 'Border#CalendarHeaderMinimizedOverlay' @('Background:=$Transparent', 'BorderThickness=0'); $i++
    Set-Rule $k $i 'ActionCenter.FocusSessionControl#FocusSessionControl > Grid#FocusGrid' @('Background:=$Transparent', 'BorderThickness=0'); $i++
    Set-Rule $k $i 'ContentPresenter#PageContent' @('Background:=$Transparent'); $i++
    Set-Rule $k $i 'ContentPresenter#PageContent > Grid > Border' @('Background:=$Transparent'); $i++
    Set-Rule $k $i 'QuickActions.ControlCenter.AccessibleWindow#PageWindow > ContentPresenter > Grid#FullScreenPageRoot' @('Background:=$Transparent'); $i++
    Set-Rule $k $i 'QuickActions.ControlCenter.AccessibleWindow#PageWindow > ContentPresenter > Grid#FullScreenPageRoot > ContentPresenter#PageHeader' @('Background:=$Transparent'); $i++
    Set-Rule $k $i 'ScrollViewer#ListContent' @('Background:=$Transparent'); $i++
    Bump-ChangeTime 'windows-11-notification-center-styler'
    $k.Close()
    Log "notification-center-styler written ($i rules)"
}

# 默认走热重载 (写完设置即生效, 宿主进程全程存活); -Restart 才重启 explorer
if ($Restart) {
    Restart-Explorer
} else {
    # 宿主活着 = bump 即热重载 (taskbar L9760 / NC L5389 Wh_ModSettingsChanged);
    # 宿主死了 (从未打开过面板) = 下次打开读注册表新值。两条路径都通, 无需重启。
    Log 'hot-reload mode: SettingsChangeTime bumped, no process restart'
}
Log 'ALL-DONE'
} catch {
    Log "FATAL: $($_.Exception.Message)"
    Log $_.ScriptStackTrace
    throw
}
