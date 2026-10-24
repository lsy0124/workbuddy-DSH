Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

function Get-DshConnection {
    param([string]$DshHome = (Join-Path $env:APPDATA 'dsh-desktop\harness'))
    Add-Type -AssemblyName System.Web
    $logPath = Join-Path (Split-Path $DshHome -Parent) 'logs\harness.log'
    $match = Get-Content -LiteralPath $logPath | Select-String 'dsh web: (http://.*)' | Select-Object -Last 1
    if (!$match) { throw 'Open DSH Desktop first; its live endpoint was not found.' }
    $uri = [uri]$match.Matches.Groups[1].Value
    if (!$uri.IsLoopback -or $uri.Scheme -ne 'http') { throw 'Only a local DSH Desktop endpoint is supported.' }
    $token = [System.Web.HttpUtility]::ParseQueryString($uri.Query)['token']
    if (!$token) { throw 'DSH endpoint has no authentication token.' }
    $base = $uri.GetLeftPart([System.UriPartial]::Authority)
    return @{Base=$base;Headers=@{Authorization=('Bearer '+$token);Origin=$base}}
}

function Invoke-DshApi {
    param($Connection,[string]$Path,[string]$Method='Get',$Body=$null,[int]$TimeoutSec=45)
    $request = @{Uri=($Connection.Base+$Path);Headers=$Connection.Headers;Method=$Method;TimeoutSec=$TimeoutSec}
    if ($null -ne $Body) {
        $request.ContentType = 'application/json; charset=utf-8'
        $request.Body = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $Body -Depth 20 -Compress))
    }
    try { Invoke-RestMethod @request }
    catch { throw ('DSH request failed at '+($Path.Split('?')[0])+'. Check that Desktop and the plugin are running. No request body was logged.') }
}

function ConvertTo-ExpiryMilliseconds {
    param($Value)
    $number = 0L
    if ([long]::TryParse([string]$Value,[ref]$number)) {
        if ($number -lt 100000000000L) { return ($number*1000L) }
        return $number
    }
    return ([DateTimeOffset]::Parse([string]$Value)).ToUnixTimeMilliseconds()
}

function Read-HelperState {
    param([string]$DataDirectory)
    Add-Type -AssemblyName System.Security
    $bytes = [IO.File]::ReadAllBytes((Join-Path $DataDirectory 'state.bin'))
    if ($bytes.Length -le 4 -or [Text.Encoding]::ASCII.GetString($bytes,0,4) -ne 'WBH1') { throw 'Expected a WBH1 Windows DPAPI Helper state file.' }
    try {
        $plain = [Security.Cryptography.ProtectedData]::Unprotect($bytes[4..($bytes.Length-1)],$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
        return ([Text.Encoding]::UTF8.GetString($plain) | ConvertFrom-Json)
    } catch { throw 'Windows could not decrypt Helper state. Run as the Windows user that saved the accounts, outside a restricted runner. Do not delete the state file.' }
    finally { $plain=$null; $bytes=$null }
}
