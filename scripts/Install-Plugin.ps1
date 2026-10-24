[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$DshExe,[string]$DshHome=(Join-Path $env:APPDATA 'dsh-desktop\harness'),[string]$Version='4.10.0')
$ErrorActionPreference='Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Use an exact numeric plugin version.' }
$exe=(Resolve-Path -LiteralPath $DshExe).Path
if ([IO.Path]::GetFileName($exe) -ne 'DSH Desktop.exe') { throw 'Select the actual DSH Desktop.exe.' }
$resources=Join-Path (Split-Path $exe -Parent) 'resources'
$wrapper=Join-Path $resources 'harness-node-entry.mjs'
$entry=Join-Path $resources 'app.asar\node_modules\@deepseek-ai\dsh\lib\bin.js'
if (!(Test-Path -LiteralPath $wrapper)) { throw 'Unsupported Desktop layout: harness-node-entry.mjs is missing.' }
$shims=Join-Path $DshHome '.desktop-bin'
if (!(Test-Path -LiteralPath (Join-Path $shims 'pnpm.cmd'))) { throw 'Open DSH Desktop once to initialize its packaged pnpm shim, then retry.' }
$oldNode=$env:ELECTRON_RUN_AS_NODE; $oldHome=$env:DSH_HOME; $oldPath=$env:PATH
try {
    $env:ELECTRON_RUN_AS_NODE='1'; $env:DSH_HOME=$DshHome; $env:PATH=$shims+';'+$env:PATH
    & $exe $wrapper $entry plugin --profile web add ('dsh-connect-workbuddy@'+$Version)
    if ($LASTEXITCODE -ne 0) { throw 'Plugin installation failed.' }
    $package=Get-Content -LiteralPath (Join-Path $DshHome 'profiles\web\node_modules\dsh-connect-workbuddy\package.json') -Raw | ConvertFrom-Json
    if ($package.version -ne $Version) { throw 'Installed version differs from the requested version.' }
    Write-Host ('Installed Desktop web profile plugin '+$package.version+'. Restart DSH Desktop, then verify a real minimal request.')
} finally { $env:ELECTRON_RUN_AS_NODE=$oldNode; $env:DSH_HOME=$oldHome; $env:PATH=$oldPath }
