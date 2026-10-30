$ErrorActionPreference = 'Stop'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class TouchpadDpiCheck {
 [DllImport("user32.dll")] public static extern IntPtr GetDpiAwarenessContextForProcess(IntPtr process);
 [DllImport("user32.dll")] public static extern int GetAwarenessFromDpiAwarenessContext(IntPtr context);
 [DllImport("user32.dll")] public static extern bool AreDpiAwarenessContextsEqual(IntPtr first,IntPtr second);
}
'@
$residents = @(Get-Process nelisp-touchpad -ErrorAction Stop)
if ($residents.Count -ne 1) { throw 'Expected exactly one resident process' }
$context = [TouchpadDpiCheck]::GetDpiAwarenessContextForProcess($residents[0].Handle)
$isV2 = [TouchpadDpiCheck]::AreDpiAwarenessContextsEqual($context, [IntPtr]::new(-4))
"Awareness=$([TouchpadDpiCheck]::GetAwarenessFromDpiAwarenessContext($context)) PerMonitorV2=$isV2"
if (-not $isV2) { throw 'The installed resident is not Per Monitor V2 aware' }
