[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$BackupDirectory,[string]$DataDirectory=(Join-Path $env:LOCALAPPDATA 'WorkBuddyHelper'))
$ErrorActionPreference='Stop'
$exe=Join-Path (Split-Path $PSScriptRoot -Parent) 'binaries\WorkBuddyHelper.exe'
$source=[IO.Path]::GetFullPath($BackupDirectory).TrimEnd('\')
$destination=[IO.Path]::GetFullPath($DataDirectory).TrimEnd('\')
if ($source -eq $destination) { throw 'BackupDirectory must differ from the active data directory.' }
if (!(Test-Path -LiteralPath (Join-Path $source 'state.bin'))) { throw 'BackupDirectory must contain an encrypted state.bin.' }
$localBackups=Join-Path $env:LOCALAPPDATA 'WorkBuddyDSH\backups'
New-Item -ItemType Directory -Path $localBackups -Force | Out-Null
Get-Process -Name WorkBuddyHelper -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $exe} | Stop-Process
$other=Get-Process -Name WorkBuddyHelper -ErrorAction SilentlyContinue
if ($other) { throw 'Close other Helper instances before recovery; they may be using this store.' }
$current=Join-Path $destination 'state.bin'
if (Test-Path -LiteralPath $current) { Copy-Item -LiteralPath $current -Destination (Join-Path $localBackups ('state-'+(Get-Date -Format yyyyMMdd-HHmmss)+'.bin')) }
& $exe --data-dir $destination --import $source
if ($LASTEXITCODE -ne 0) { throw 'Encrypted account merge failed. Current data and its backup were preserved.' }
Write-Host 'Merge command completed. Start Helper and verify its account count.'
