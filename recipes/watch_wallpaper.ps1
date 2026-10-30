# 壁纸变更监视器: 轮询壁纸文件哈希, 变化时自动重跑 apply_text_contrast.ps1 (开始菜单文字自动反色)。
# 由计划任务 HarmonyGlass\TextContrast 在登录时启动 (隐藏窗口), 30s 轮询, CPU 几乎为零。
# 手动停止: Stop-ScheduledTask / Stop-Process -Name powershell (找本脚本)
$proj = Split-Path $PSScriptRoot
$apply = Join-Path $proj 'recipes\apply_text_contrast.ps1'
$log   = Join-Path $proj 'watch.log'
function WLog([string]$m) { $m | Add-Content -Path $log -Encoding UTF8 }

function Get-WallHash {
    $p = (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -ErrorAction SilentlyContinue).Wallpaper
    if (-not $p -or -not (Test-Path $p)) { $p = Join-Path $env:APPDATA 'Microsoft\Windows\Themes\TranscodedWallpaper' }
    if (Test-Path $p) { (Get-FileHash $p -Algorithm SHA1).Hash } else { $null }
}

WLog ("=== watcher start $(Get-Date -Format s) pid=$PID ===")
$last = Get-WallHash
while ($true) {
    Start-Sleep -Seconds 30
    $cur = Get-WallHash
    if ($cur -ne $last) {
        WLog ("wallpaper change detected $(Get-Date -Format s): $last -> $cur")
        & powershell -NoProfile -ExecutionPolicy Bypass -File $apply -Mode auto 2>&1 | ForEach-Object { WLog $_ }
        $last = Get-WallHash
        WLog "apply_text_contrast re-run done"
    }
}
