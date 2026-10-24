$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$files=Get-ChildItem (Join-Path $root 'scripts') -Filter '*.ps1'
foreach ($file in $files) {
    $parseErrors=$null; $parseTokens=$null
    $null=[System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$parseTokens,[ref]$parseErrors)
    if ($parseErrors.Count) { throw ('Syntax error in '+$file.Name) }
}
. (Join-Path $root 'scripts\Common.ps1')
if ((ConvertTo-ExpiryMilliseconds 1700000000) -ne 1700000000000L) { throw 'Unix seconds conversion failed.' }
if ((ConvertTo-ExpiryMilliseconds ([long]1700000000000)) -ne 1700000000000L) { throw 'Unix milliseconds conversion failed.' }
if ((ConvertTo-ExpiryMilliseconds '2023-11-14T22:13:20Z') -ne 1700000000000L) { throw 'ISO conversion failed.' }
Write-Host ('PASS: '+$files.Count+' scripts parsed; seconds, milliseconds and ISO conversion verified. No account API or model calls were made.')
