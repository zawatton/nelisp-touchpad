$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$appPath = Join-Path $env:LOCALAPPDATA 'NeLispTouchpad/nelisp-touchpad.exe'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class TouchpadApplicationIconCheck {
 [DllImport("shell32.dll", CharSet=CharSet.Unicode)] public static extern uint ExtractIconEx(string path,int index,IntPtr[] large,IntPtr[] small,uint count);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern uint PrivateExtractIcons(string path,int index,int width,int height,IntPtr[] icons,uint[] ids,uint count,uint flags);
 [DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr icon);
}
'@
$count = [TouchpadApplicationIconCheck]::ExtractIconEx($appPath, -1, $null, $null, 0)
if ($count -lt 1) { throw 'Executable has no application icon resource' }
foreach ($size in @(16,32,48,256)) {
 $icons = [IntPtr[]]::new(1)
 $ids = [uint32[]]::new(1)
 $result = [TouchpadApplicationIconCheck]::PrivateExtractIcons($appPath,0,$size,$size,$icons,$ids,1,0)
 if ($result -ne 1 -or $icons[0] -eq [IntPtr]::Zero) { throw "Application icon extraction failed at $size px" }
 [void][TouchpadApplicationIconCheck]::DestroyIcon($icons[0])
}
$shell = New-Object -ComObject WScript.Shell
foreach ($folder in @('Programs','Startup')) {
 $linkPath = Join-Path ([Environment]::GetFolderPath($folder)) 'NeLisp Touchpad.lnk'
 $link = $shell.CreateShortcut($linkPath)
 if ($link.TargetPath -ne $appPath -or $link.IconLocation -ne ($appPath + ',0')) { throw "Shortcut icon mismatch: $folder" }
}
"PASS: embedded application icon group=$count; extraction at 16/32/48/256 px; Start menu and Startup icon locations"
