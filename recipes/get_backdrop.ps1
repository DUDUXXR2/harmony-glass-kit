# Read DWM system backdrop attribute (38) for visible top-level windows of a process.
# Values: 0=Auto 1=None 2=Mica 3=Acrylic 4=Mica-Alt. Readback is cross-process, no elevation.
# Usage: powershell -File get_backdrop.ps1 <ProcessName> [ClassPattern]
param([string]$ProcName, [string]$ClassPattern = '*')
if ($env:TEMP -like 'C:*') { $env:TEMP = 'E:\ToolCache\Temp'; $env:TMP = 'E:\ToolCache\Temp' }
Add-Type -Namespace W -Name U -MemberDefinition @'
[DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out int v, int s);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lp);
public delegate bool EnumWindowsProc(IntPtr h, IntPtr lp);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
[DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int max);
'@
$pids = @{}
foreach ($p in (Get-Process -Name $ProcName -ErrorAction SilentlyContinue)) { $pids[[uint32]$p.Id] = $true }
if ($pids.Count -eq 0) { Write-Output "no process: $ProcName"; exit 1 }
$found = New-Object System.Collections.ArrayList
$cb = {
    param($h, $lp)
    $procId = [uint32]0
    [W.U]::GetWindowThreadProcessId($h, [ref]$procId) | Out-Null
    if ($pids.ContainsKey($procId) -and [W.U]::IsWindowVisible($h)) {
        $sb = New-Object System.Text.StringBuilder 256
        [W.U]::GetClassName($h, $sb, 256) | Out-Null
        if ($sb.ToString() -like $ClassPattern) { [void]$found.Add(@{ H = $h; Class = $sb.ToString() }) }
    }
    return $true
}
[W.U]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
if ($found.Count -eq 0) { Write-Output "no visible windows: $ProcName class=$ClassPattern"; exit 0 }
foreach ($w in $found) {
    $v = 0
    $hr = [W.U]::DwmGetWindowAttribute($w.H, 38, [ref]$v, 4)
    'hwnd=0x{0:X} class={1} backdrop={2} hr=0x{3:X}' -f $w.H, $w.Class, $v, $hr
}
