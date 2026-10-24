[CmdletBinding()]
param(
    [string]$HelperDataDirectory=(Join-Path $env:LOCALAPPDATA 'WorkBuddyHelper'),
    [uri]$HelperUrl='http://127.0.0.1:18080',
    [string]$DshHome=(Join-Path $env:APPDATA 'dsh-desktop\harness'),
    [string]$SelectAccountId
)
. (Join-Path $PSScriptRoot 'Common.ps1')
$state=$null; $records=$null; $text=$null; $connection=$null
try {
    if (!$HelperUrl.IsLoopback -or $HelperUrl.Scheme -ne 'http') { throw 'Helper must be a local HTTP service.' }
    $public = Invoke-RestMethod ($HelperUrl.AbsoluteUri.TrimEnd('/')+'/api/state') -TimeoutSec 10
    # Unknown, failed and expired logins must not overwrite usable DSH credentials.
    $eligible = @($public.cnAccounts | Where-Object {$_.status -in @('confirmed','ready','success','normal')} | ForEach-Object {$_.id})
    $state = Read-HelperState $HelperDataDirectory
    $records = @($state.accounts | Where-Object {$_.id -in $eligible} | ForEach-Object {
        if (!$_.accessToken -or !$_.uid) { throw 'A Helper account has incomplete credentials.' }
        @{access_token=$_.accessToken;refresh_token=$_.refreshToken;uid=[string]$_.uid;nickname=$_.nickname;domain=$_.domain;expiresAt=(ConvertTo-ExpiryMilliseconds $_.expiresAt)}
    })
    if (!$records.Count) { throw 'No eligible domestic accounts were found. Refresh accounts in Helper and check their login status.' }
    $connection = Get-DshConnection $DshHome
    $text = ConvertTo-Json -InputObject $records -Depth 8 -Compress
    $result = Invoke-DshApi $connection '/plugins/dsh-connect-workbuddy/transfer?region=cn&action=import' Post @{text=$text;indexes=@(0..($records.Count-1))}
    Write-Host ('One-time merge: imported='+$result.imported+'; skipped='+$result.skipped)
    if ($SelectAccountId) {
        $list = Invoke-DshApi $connection '/plugins/dsh-connect-workbuddy/usage?region=cn&detail=fast'
        if ($SelectAccountId -notin @($list.accounts | ForEach-Object {$_.id})) { throw 'SelectAccountId is not present in DSH. No selection was changed.' }
        $null = Invoke-DshApi $connection '/plugins/dsh-connect-workbuddy/__save' Post @{field='accounts';value=@{cn=$SelectAccountId}}
    }
    $usage = Invoke-DshApi $connection '/plugins/dsh-connect-workbuddy/usage?region=cn'
    Write-Host ('Selected account live status: '+$usage.status)
    if ($usage.status -ne 'signed-in') { throw 'Merge completed, but the selected account failed its live check. Select a valid account in DSH or log in again in Helper.' }
    Write-Host 'Selected account passed the live login/credits check. No model completion was sent.'
    Write-Host 'Reopen the WB CN panel. Duplicate historical records are preserved.'
} finally {
    $state=$null; $records=$null; $text=$null; $connection=$null
}
