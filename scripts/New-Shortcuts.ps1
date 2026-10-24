[CmdletBinding()]
param([string]$DshExe)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$desktop=[Environment]::GetFolderPath('Desktop')
$shell=New-Object -ComObject WScript.Shell
$link=$shell.CreateShortcut((Join-Path $desktop 'WorkBuddy Helper.lnk'))
$link.TargetPath=Join-Path $root 'binaries\WorkBuddyHelper.exe'
$link.WorkingDirectory=Join-Path $root 'binaries'
$link.Arguments='--host 127.0.0.1 --port 18080 --data-dir "'+(Join-Path $env:LOCALAPPDATA 'WorkBuddyHelper')+'"'
$link.Save()
if ($DshExe) {
    $resolved=(Resolve-Path -LiteralPath $DshExe).Path
    $link=$shell.CreateShortcut((Join-Path $desktop 'DSH Desktop.lnk'))
    $link.TargetPath=$resolved; $link.WorkingDirectory=Split-Path $resolved -Parent; $link.Save()
}
Write-Host 'Desktop shortcuts created using the actual Windows Desktop folder.'
