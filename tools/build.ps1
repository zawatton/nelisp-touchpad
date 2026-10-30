$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$targetRoot = Join-Path $projectRoot 'target'
New-Item -ItemType Directory -Force $targetRoot | Out-Null
$logPath = Join-Path $targetRoot 'build.log'
$savedPythonBin = $env:PYTHON_BIN
try {
 if (-not $env:PYTHON_BIN) { $env:PYTHON_BIN = (Get-Command python -ErrorAction Stop).Source }
 & emacs -Q --batch -l (Join-Path $projectRoot 'build.el') *> $logPath
 if ($LASTEXITCODE -ne 0) { Get-Content $logPath -Tail 8; throw 'NeLisp build failed; see target/build.log' }
} finally { $env:PYTHON_BIN = $savedPythonBin }
Get-Content $logPath -Tail 1
