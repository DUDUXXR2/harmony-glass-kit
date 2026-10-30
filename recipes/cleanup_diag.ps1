# Clean diagnostic residue: TB rules 24/40 (red clock) + NC rules 18-20 (red panels), bump both mods.
# BUGFIX: -like 'controlStyles[24]*' NEVER matches the literal value name ([24] is a wildcard char
# class = one char '2' or '4') - the first cleanup was a silent no-op. Use .StartsWith() (literal).
# Also kills ShellExperienceHost/ShellHost so NC panels respawn clean on next open
# (taskbar hot-reloads on bump, proven; NC hot-reload unproven, so kill to be safe).
# Usage: powershell -File cleanup_diag.ps1   (elevated)
$hw = [Microsoft.Win32.Registry]::LocalMachine

function Remove-Rules([string]$modId, [string[]]$prefixes) {
    $sk = $hw.OpenSubKey("SOFTWARE\Windhawk\Engine\Mods\$modId\Settings", $true)
    $deleted = 0
    foreach ($n in @($sk.GetValueNames())) {
        foreach ($p in $prefixes) {
            if ($n.StartsWith($p)) { $sk.DeleteValue($n); $deleted++; break }
        }
    }
    $sk.Close()
    $mkey = $hw.OpenSubKey("SOFTWARE\Windhawk\Engine\Mods\$modId", $true)
    $mkey.SetValue('SettingsChangeTime', [int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()), [Microsoft.Win32.RegistryValueKind]::DWord)
    $mkey.Close()
    Write-Output "$modId : removed $deleted values, bumped"
}

Remove-Rules 'windows-11-taskbar-styler'          @('controlStyles[24]', 'controlStyles[40]')
Remove-Rules 'windows-11-notification-center-styler' @('controlStyles[18]', 'controlStyles[19]', 'controlStyles[20]')

Stop-Process -Name ShellExperienceHost -Force -ErrorAction SilentlyContinue
Stop-Process -Name ShellHost -Force -ErrorAction SilentlyContinue
Write-Output 'shell hosts killed (respawn on next panel open)'
