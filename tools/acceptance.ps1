param([string]$AppPath)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $AppPath) { $AppPath = Join-Path $projectRoot 'target/nelisp-touchpad.exe' }
function Invoke-App([string]$Argument) {
 $process = Start-Process -FilePath $AppPath -ArgumentList $Argument -WindowStyle Hidden -PassThru
 if (-not $process.WaitForExit(5000)) { throw "Timed out: $Argument" }
 $process.ExitCode
}
$before = Invoke-App '--status'
if ($before -notin @(0,10)) { throw "Touchpad state unavailable: $before" }
$devicesBefore = @(Get-PnpDevice -Class Mouse | Select-Object Status,InstanceId | Sort-Object InstanceId | ConvertTo-Json -Compress)
try {
 if ((Invoke-App '--inspect') -ne 0) { throw 'Tray icon or native menu inspection failed' }
 if ((Invoke-App '--off') -ne 0 -or (Invoke-App '--status') -ne 10) { throw 'Touchpad off failed' }
 if ((Invoke-App '--on') -ne 0 -or (Invoke-App '--status') -ne 0) { throw 'Touchpad on failed' }
 $devicesAfter = @(Get-PnpDevice -Class Mouse | Select-Object Status,InstanceId | Sort-Object InstanceId | ConvertTo-Json -Compress)
 if (Compare-Object $devicesBefore $devicesAfter) { throw 'Pointing device state changed' }
 $residents = @(Get-Process nelisp-touchpad)
 $duplicate = Start-Process -FilePath $AppPath -WindowStyle Hidden -PassThru
 if (-not $duplicate.WaitForExit(3000) -or $duplicate.ExitCode -ne 0) { throw 'Duplicate instance was not rejected' }
 if (@(Get-Process nelisp-touchpad).Count -ne $residents.Count) { throw 'Resident process count changed' }
 'PASS: tray presence, native menu, off/on, pointing devices, single instance'
} finally {
 if ((Invoke-App '--status') -ne $before) {
  $restore = if ($before -eq 0) { '--on' } else { '--off' }
  if ((Invoke-App $restore) -ne 0) { throw 'Original touchpad state could not be restored' }
 }
}
