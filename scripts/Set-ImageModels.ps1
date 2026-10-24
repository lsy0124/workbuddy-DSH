[CmdletBinding()]
param([ValidateSet('cn','global')][string]$Region='cn',[Parameter(Mandatory=$true)][AllowEmptyCollection()][string[]]$ModelIds,[string]$DshHome=(Join-Path $env:APPDATA 'dsh-desktop\harness'))
. (Join-Path $PSScriptRoot 'Common.ps1')
$connection=Get-DshConnection $DshHome
try {
    $slot=@{}; $slot[$Region]=@{imageModelIds=@($ModelIds | Select-Object -Unique)}
    $null=Invoke-DshApi $connection '/plugins/dsh-connect-workbuddy/__save' Post @{field='regions';value=$slot}
    $usage=Invoke-DshApi $connection ('/plugins/dsh-connect-workbuddy/usage?region='+$Region+'&detail=fast')
    $saved=@($usage.imageModelIds)
    $expected=@($ModelIds | Sort-Object -Unique)
    if ($expected.Count -ne $saved.Count -or @($expected | Where-Object {$_ -notin $saved}).Count) { throw 'Saved image model IDs did not match the requested set.' }
    Write-Host ('Image input flags saved and read back: '+$saved.Count)
    Write-Host 'This changes attachment routing only; upstream models must actually support images.'
} finally { $connection=$null }
