# Set DWM system backdrop (attr 38) on visible top-level windows of a process.
# Backdrop: 1=none 2=Mica 3=Acrylic 4=Mica-Alt. Works cross-process, no elevation.
# Usage: powershell -File set_backdrop.ps1 <ProcessName> [Backdrop] [ClassPattern]
#   e.g. powershell -File set_backdrop.ps1 explorer 3 CabinetWClass
param(
    [string]$ProcName,
    [int]$Backdrop = 3,
    [string]$ClassPattern = '*'
)
Add-Type -Namespace W -Name U -MemberDefinition @'
[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr h, int a, ref int v, int s);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lp);
public delegate bool EnumWindowsProc(IntPtr h, IntPtr lp);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int max);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
public struct RECT { public int L; public int T; public int R; public int B; }
'@
$procs = Get-Process -Name $ProcName -ErrorAction SilentlyContinue
if (-not $procs) { Write-Output "no process: $ProcName"; exit 1 }
$pids = @{}
foreach ($p in $procs) { $pids[[uint32]$p.Id] = $true }
$found = New-Object System.Collections.ArrayList
$cb = {
    param($h, $lp)
    $procId = [uint32]0
    [W.U]::GetWindowThreadProcessId($h, [ref]$procId) | Out-Null
    if ($pids.ContainsKey($procId) -and [W.U]::IsWindowVisible($h)) {
        $sb = New-Object System.Text.StringBuilder 256
        [W.U]::GetClassName($h, $sb, 256) | Out-Null
        $cls = $sb.ToString()
        if ($cls -like $ClassPattern) {
            [void]$found.Add(@{ Hwnd = $h; Class = $cls })
        }
    }
    return $true
}
[W.U]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
if ($found.Count -eq 0) { Write-Output "no matching windows for $ProcName class=$ClassPattern"; exit 0 }
foreach ($w in $found) {
    $v = $Backdrop
    $r = [W.U]::DwmSetWindowAttribute($w.Hwnd, 38, [ref]$v, 4)
    $rect = New-Object W.U+RECT
    [W.U]::GetWindowRect($w.Hwnd, [ref]$rect) | Out-Null
    'hwnd 0x{0:X} class={1} rect=({2},{3})-({4},{5}) DwmSetWindowAttribute(38,{6}) -> hr=0x{7:X}' -f `
        $w.Hwnd, $w.Class, $rect.L, $rect.T, $rect.R, $rect.B, $Backdrop, $r
}
