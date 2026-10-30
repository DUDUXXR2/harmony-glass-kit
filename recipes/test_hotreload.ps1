# Hot-reload test v2: red clock at CONTIGUOUS index 24.
# The engine rule loop stops at the first empty target, so the old index-40 rule
# was never read - that test was invalid. This one is in the right slot.
# Usage: powershell -File test_hotreload.ps1 [add|remove]
param([string]$Mode = 'add')
$hw = [Microsoft.Win32.Registry]::LocalMachine
$sk = $hw.OpenSubKey('SOFTWARE\Windhawk\Engine\Mods\windows-11-taskbar-styler\Settings', $true)
foreach ($n in @($sk.GetValueNames())) {
    # NOTE: -like '[24]*' is a wildcard char class, never matches literal value names - use StartsWith
    if ($n.StartsWith('controlStyles[40]') -or $n.StartsWith('controlStyles[24]')) { $sk.DeleteValue($n) }
}
if ($Mode -eq 'add') {
    $sk.SetValue('controlStyles[24].target', 'TextBlock#TimeInnerTextBlock', [Microsoft.Win32.RegistryValueKind]::String)
    $sk.SetValue('controlStyles[24].styles[0]', 'Foreground=#FFFF3050', [Microsoft.Win32.RegistryValueKind]::String)
}
$sk.Close()
$mkey = $hw.OpenSubKey('SOFTWARE\Windhawk\Engine\Mods\windows-11-taskbar-styler', $true)
$mkey.SetValue('SettingsChangeTime', [int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()), [Microsoft.Win32.RegistryValueKind]::DWord)
$mkey.Close()
Write-Output "hotreload-test mode=$Mode done (SettingsChangeTime bumped)"
