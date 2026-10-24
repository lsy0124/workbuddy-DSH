[CmdletBinding()]
param([string]$DataDirectory=(Join-Path $env:LOCALAPPDATA 'WorkBuddyHelper'),[int]$Port=18080,[switch]$NoOpen)
$ErrorActionPreference='Stop'
$exe=Join-Path (Split-Path $PSScriptRoot -Parent) 'binaries\WorkBuddyHelper.exe'
if (!(Test-Path -LiteralPath $exe)) { throw 'The bundled official Helper binary is missing.' }
$arguments=@('--host','127.0.0.1','--port',[string]$Port,'--data-dir',$DataDirectory)
if ($NoOpen) { $arguments+='--no-open' }
# Foreground invocation retains startup diagnostics. Keep the terminal open.
& $exe @arguments
if ($LASTEXITCODE -ne 0) { throw ('Helper exited with code '+$LASTEXITCODE+'. Preserve state.bin and inspect the error above.') }
