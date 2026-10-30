$ErrorActionPreference = 'Stop'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class TouchpadProbe {
 [DllImport("user32.dll",SetLastError=true)] static extern bool SystemParametersInfoW(uint action,uint size,IntPtr data,uint flags);
 [DllImport("user32.dll",SetLastError=true)] static extern uint SendInput(uint count,IntPtr data,int size);
 public static uint State() {
  IntPtr p=Marshal.AllocHGlobal(48);
  try {
   for(int i=0;i<48;i+=4) Marshal.WriteInt32(p,i,0);
   Marshal.WriteInt32(p,0,1);
   if(!SystemParametersInfoW(0xAE,48,p,0)) throw new System.ComponentModel.Win32Exception();
   return (uint)Marshal.ReadInt32(p,12);
  } finally {Marshal.FreeHGlobal(p);}
 }
 public static void Toggle() {
  IntPtr p=Marshal.AllocHGlobal(240);
  try {
   for(int i=0;i<240;i+=4) Marshal.WriteInt32(p,i,0);
   int[] keys={0x11,0x5B,0x87,0x87,0x5B,0x11};
   for(int i=0;i<6;i++) {
    Marshal.WriteInt32(p,i*40,1);
    Marshal.WriteInt16(p,i*40+8,(short)keys[i]);
    Marshal.WriteInt32(p,i*40+12,i>=3?2:0);
   }
   if(SendInput(6,p,40)!=6) throw new System.ComponentModel.Win32Exception();
  } finally {Marshal.FreeHGlobal(p);}
 }
}
'@
$before=[TouchpadProbe]::State()
try {
 [TouchpadProbe]::Toggle()
 Start-Sleep -Milliseconds 600
 $after=[TouchpadProbe]::State()
 "Before=$before After=$after Changed=$((($before -bxor $after) -band 8) -ne 0)"
 if ((($before -bxor $after) -band 8) -eq 0) {throw 'Shell touchpad shortcut did not change the enabled state'}
} finally {
 if (([TouchpadProbe]::State() -band 8) -ne ($before -band 8)) {
  [TouchpadProbe]::Toggle()
  Start-Sleep -Milliseconds 600
 }
 "Restored=$(([TouchpadProbe]::State() -band 8) -eq ($before -band 8))"
}
