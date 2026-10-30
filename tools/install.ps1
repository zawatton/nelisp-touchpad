param([switch]$NoStartup)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$sourceExe = Join-Path $projectRoot 'target/nelisp-touchpad.exe'
if (-not (Test-Path -LiteralPath $sourceExe)) { throw 'Run tools/build.ps1 first' }
$installRoot = Join-Path $env:LOCALAPPDATA 'NeLispTouchpad'
$installExe = Join-Path $installRoot 'nelisp-touchpad.exe'
$mingwBin = if ($env:MINGW_BIN) { $env:MINGW_BIN } else { Split-Path (Get-Command gcc -ErrorAction Stop).Source -Parent }
$objdump = Join-Path $mingwBin 'objdump.exe'
# Resolve only dependencies shipped by this toolchain; Windows owns the rest.
$queue = [Collections.Generic.Queue[string]]::new()
$queue.Enqueue($sourceExe)
$sources = @{}
while ($queue.Count -gt 0) {
 $file = $queue.Dequeue()
 foreach ($line in (& $objdump -p $file)) {
  if ($line -match 'DLL Name:\s*(.+)$') {
   $name = $Matches[1].Trim()
   $candidate = Join-Path $mingwBin $name
   if ((Test-Path -LiteralPath $candidate) -and -not $sources.ContainsKey($name)) {
    $sources[$name] = $candidate
    $queue.Enqueue($candidate)
   }
  }
 }
 if ($LASTEXITCODE -ne 0) { throw "Import inspection failed: $file" }
}
New-Item -ItemType Directory -Force $installRoot | Out-Null
if (Test-Path -LiteralPath $installExe) {
 $shutdown = Start-Process -FilePath $installExe -ArgumentList '--quit' -WindowStyle Hidden -PassThru
 if (-not $shutdown.WaitForExit(5000)) { throw 'Existing app did not shut down' }
 Start-Sleep -Milliseconds 200
 $backupRoot = Join-Path $installRoot ('backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
 New-Item -ItemType Directory $backupRoot | Out-Null
 Copy-Item -LiteralPath $installExe -Destination $backupRoot
}
Copy-Item -LiteralPath $sourceExe -Destination $installExe -Force
foreach ($name in $sources.Keys) { Copy-Item -LiteralPath $sources[$name] -Destination (Join-Path $installRoot $name) -Force }
$shell = New-Object -ComObject WScript.Shell
$linkPaths = @((Join-Path ([Environment]::GetFolderPath('Programs')) 'NeLisp Touchpad.lnk'))
if (-not $NoStartup) { $linkPaths += Join-Path ([Environment]::GetFolderPath('Startup')) 'NeLisp Touchpad.lnk' }
foreach ($linkPath in $linkPaths) {
 $link = $shell.CreateShortcut($linkPath)
 $link.TargetPath = $installExe
 $link.WorkingDirectory = $installRoot
 $link.Description = 'NeLisp and Sumi touchpad control'
 $link.Save()
}
$process = Start-Process -FilePath $installExe -WorkingDirectory $installRoot -WindowStyle Hidden -PassThru
Start-Sleep -Milliseconds 500
$process.Refresh()
if ($process.HasExited) { throw "Resident app exited: $($process.ExitCode)" }
"Installed=$installRoot PID=$($process.Id) BundledDLLs=$($sources.Count) Startup=$(-not $NoStartup)"
