# Set the undocumented accent policy (SetWindowCompositionAttribute, WCA_ACCENT_POLICY)
# on a window. State 4 = ACCENT_ENABLE_ACRYLICBLURBEHIND: old-style acrylic where the
# tint color + alpha ARE tunable (AABBGGRR), unlike the fixed DWM system backdrop presets.
# Blur radius is fixed; no luminosity/saturation controls.
# States: 0=disabled 1=gradient 2=transparent-gradient 3=blurbehind 4=acrylic 5=hostbackdrop
# Usage:
#   powershell -File set_accent.ps1 -ProcName explorer -TintHex 40FCF8F5 -ClassPattern CabinetWClass
#   powershell -File set_accent.ps1 -Hwnd 0x12345 -TintHex 40FCF8F5
#   powershell -File set_accent.ps1 -Hwnd 0x12345 -State 0     # reset
param(
    [string]$ProcName,
    [string]$TintHex = '40FCF8F5',   # AABBGGRR: alpha 0x40 (~25%), color #F5F8FC
    [int]$State = 4,
    [string]$ClassPattern = '*',
    [string]$Hwnd = ''
)
if ($env:TEMP -like 'C:*') { $env:TEMP = 'E:\ToolCache\Temp'; $env:TMP = 'E:\ToolCache\Temp' }
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class AccentApi {
    [DllImport("user32.dll")]
    public static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref Wcad data);
    [StructLayout(LayoutKind.Sequential)]
    public struct AccentPolicy {
        public int AccentState;
        public int AccentFlags;
        public int GradientColor;   // AABBGGRR
        public int AnimationId;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct Wcad {
        public int Attribute;       // 19 = WCA_ACCENT_POLICY
        public IntPtr Data;
        public int SizeOfData;
    }
}
"@
$tint = [Convert]::ToInt32($TintHex, 16)
if ($tint -lt 0) { throw "alpha byte must be < 0x80 (int32 conversion limit)" }
$policy = New-Object AccentApi+AccentPolicy
$policy.AccentState = $State
$policy.AccentFlags = 0
$policy.GradientColor = $tint
$policy.AnimationId = 0
$size = [Runtime.InteropServices.Marshal]::SizeOf([type][AccentApi+AccentPolicy])
$ptr  = [Runtime.InteropServices.Marshal]::AllocHGlobal($size)
[Runtime.InteropServices.Marshal]::StructureToPtr($policy, $ptr, $false)
try {
    if ($Hwnd -ne '') {
        $h = [IntPtr][Int64]$Hwnd
        $wcad = New-Object AccentApi+Wcad
        $wcad.Attribute = 19
        $wcad.Data = $ptr
        $wcad.SizeOfData = $size
        $hr = [AccentApi]::SetWindowCompositionAttribute($h, [ref]$wcad)
        'hwnd=0x{0:X} state={1} tint=0x{2} hr=0x{3:X}' -f $h, $State, $TintHex, $hr
        exit 0
    }
    Add-Type -Namespace W -Name U -MemberDefinition @'
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
        $wcad = New-Object AccentApi+Wcad
        $wcad.Attribute = 19
        $wcad.Data = $ptr
        $wcad.SizeOfData = $size
        $hr = [AccentApi]::SetWindowCompositionAttribute($w.H, [ref]$wcad)
        'hwnd=0x{0:X} class={1} state={2} tint=0x{3} hr=0x{4:X}' -f $w.H, $w.Class, $State, $TintHex, $hr
    }
} finally {
    [Runtime.InteropServices.Marshal]::FreeHGlobal($ptr)
}
