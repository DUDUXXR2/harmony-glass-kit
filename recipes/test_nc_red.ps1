# NC red diagnostic: append pure-red backgrounds at contiguous indices 18-20
# (existing rules 0-17 stay untouched; red wins as the later rule on the same target).
# Then kill the shell hosts so panels respawn with fresh settings on next open.
# Usage: powershell -File test_nc_red.ps1 [add|remove]
param([string]$Mode = 'add', [switch]$NoKill)
$hw = [Microsoft.Win32.Registry]::LocalMachine
$sk = $hw.OpenSubKey('SOFTWARE\Windhawk\Engine\Mods\windows-11-notification-center-styler\Settings', $true)
foreach ($n in @($sk.GetValueNames())) {
    # NOTE: -like '[18]*' is a wildcard char class, never matches literal value names - use StartsWith
    if ($n.StartsWith('controlStyles[18]') -or $n.StartsWith('controlStyles[19]') -or $n.StartsWith('controlStyles[20]')) { $sk.DeleteValue($n) }
}
if ($Mode -eq 'add') {
    $pairs = @(
        @('controlStyles[18].target', 'Grid#ControlCenterRegion'),
        @('controlStyles[18].styles[0]', 'Background=#FFFF0000'),
        @('controlStyles[19].target', 'Grid#NotificationCenterGrid'),
        @('controlStyles[19].styles[0]', 'Background=#FFFF0000'),
        @('controlStyles[20].target', 'Grid#CalendarCenterGrid'),
        @('controlStyles[20].styles[0]', 'Background=#FFFF0000')
    )
    foreach ($p in $pairs) { $sk.SetValue($p[0], $p[1], [Microsoft.Win32.RegistryValueKind]::String) }
}
$sk.Close()
$mkey = $hw.OpenSubKey('SOFTWARE\Windhawk\Engine\Mods\windows-11-notification-center-styler', $true)
$mkey.SetValue('SettingsChangeTime', [int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()), [Microsoft.Win32.RegistryValueKind]::DWord)
$mkey.Close()
# hosts do NOT follow explorer restarts; -NoKill tests whether the NC engine hot-reloads like the taskbar engine does
if (-not $NoKill) {
    Stop-Process -Name ShellExperienceHost -Force -ErrorAction SilentlyContinue
    Stop-Process -Name ShellHost -Force -ErrorAction SilentlyContinue
}
Write-Output "nc-red mode=$Mode done, shell hosts killed (respawn on panel open)"
