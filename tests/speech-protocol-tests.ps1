param([Parameter(Mandatory)][string]$WorkerPath)

$ErrorActionPreference = 'Stop'
$workerText = [IO.File]::ReadAllText($WorkerPath)
$loopPosition = $workerText.IndexOf('if (Test-Path -LiteralPath $readyPath)', [StringComparison]::Ordinal)
if ($loopPosition -lt 0) { throw 'Cannot locate worker request loop.' }
$setup = $workerText.Substring(0, $loopPosition)
$setup = [Regex]::Replace($setup, '\$parentProcessId = \d+',
    '$parentProcessId = [Diagnostics.Process]::GetCurrentProcess().Id')
. ([ScriptBlock]::Create($setup))

function Assert($condition, [string]$message) {
    if (-not $condition) { throw $message }
}

try {
    # Fixed vectors cross-checked against edge-tts' independent Python implementation.
    $vectors = @(
        @(0L, '52BC7A17B50DFEC9-28C4394775C8751CD2F6859C030C06DB1489ACAB3B3A7651831FC26895177ED6'),
        @(1700000000L, '2CD23A2CA0B2595A-F3C846C370E05F9CC83ACC5F995C5F5D87A4D0F14CE8936A0F902E64099E38A2'),
        @(1800000000L, '99E54519B490BE5C-E162DB0977FBDCB9B86DD8148BF1BCDC3C0303176CE39852A42B415935C20654'),
        @(1792032299L, '674B218A78CBD308-AD039E91E143A009CD63DAF5F12E36D5D3013AC1AE82956328D3F67672E0CBB5'),
        @(1792032300L, '63F10C5237118919-D4295F3F91F94E3DAF72A3904255C03AF4F953CA55C9E7936A93BF77E16426FD')
    )
    foreach ($vector in $vectors) {
        Assert ([EdgeSpeechToken]::Generate($vector[0], $trustedToken) -ceq $vector[1]) "Token mismatch at $($vector[0])"
    }
    Assert ([EdgeSpeechToken]::Generate(1792032000L, $trustedToken) -ceq $vectors[3][1]) 'Token changed within five-minute window'
    Write-Output 'PASS: v2 token vectors and five-minute boundary'

    foreach ($skew in @(-86400L, 86400L)) {
        $serverTime = [DateTimeOffset]::UtcNow.AddSeconds($skew)
        Update-EdgeSpeechClock ("HTTP/1.1 403 Forbidden`r`nDate: " + $serverTime.ToString('r') + "`r`n`r`n")
        Assert ([Math]::Abs($script:edgeClockSkewSeconds - $skew) -le 2) 'Server clock correction failed'
        $expectedToken = [EdgeSpeechToken]::Generate(
            [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + $script:edgeClockSkewSeconds, $trustedToken)
        Assert ((Get-SecMsGec) -ceq $expectedToken) 'Token ignored corrected clock'
    }
    $lastSkew = $script:edgeClockSkewSeconds
    Update-EdgeSpeechClock "HTTP/1.1 403 Forbidden`r`nDate: invalid`r`n`r`n"
    Assert ($script:edgeClockSkewSeconds -eq $lastSkew) 'Invalid Date changed clock correction'
    Update-EdgeSpeechClock "HTTP/1.1 403 Forbidden`r`nContent-Length: 0`r`n`r`n"
    Assert ($script:edgeClockSkewSeconds -eq $lastSkew) 'Missing Date changed clock correction'
    Write-Output 'PASS: server clock correction, invalid and missing Date'

    # Capture a complete opening request without contacting the service.
    function Open-EdgeWebSocket([string]$uri) { $script:capturedUri = $uri; return @{ Socket = 'test' } }
    function Send-WebSocketText($socket, [string]$message) { $script:capturedConfig = $message }
    $script:edgeClockSkewSeconds = 0L
    Open-EdgeSpeechConnection
    Assert ($script:capturedUri.Contains('&Sec-MS-GEC-Version=2-' + $edgeVersion)) 'Wrong protocol version'
    Assert ($script:capturedUri -match '&Sec-MS-GEC=[0-9A-F]{16}-[0-9A-F]{64}&') 'Wrong token format'
    Assert ($userAgent.Contains('Edg/' + $edgeVersion.Split('.')[0] + '.0.0.0')) 'User-Agent does not match protocol version'
    Assert ($script:capturedConfig.Contains('audio-24khz-48kbitrate-mono-mp3')) 'Audio format changed'
    Write-Output 'PASS: handshake protocol version, token, User-Agent and audio configuration'
}
finally { $parentProcess.Dispose() }
