param(
    [Parameter(Mandatory)][string]$WorkerPath,
    [Parameter(Mandatory)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$workerText = [IO.File]::ReadAllText($WorkerPath)
$loopPosition = $workerText.IndexOf('if (Test-Path -LiteralPath $readyPath)', [StringComparison]::Ordinal)
if ($loopPosition -lt 0) { throw 'Cannot locate worker request loop.' }
$setup = $workerText.Substring(0, $loopPosition)
$setup = [Regex]::Replace($setup, '\$parentProcessId = \d+',
    '$parentProcessId = [Diagnostics.Process]::GetCurrentProcess().Id')
. ([ScriptBlock]::Create($setup))
$script:edgeConnection = $null

Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class SpeechSmokeMci {
    [DllImport("winmm.dll", CharSet = CharSet.Unicode)]
    public static extern uint mciSendString(string command, StringBuilder result, int size, IntPtr callback);
}
'@

function Invoke-Mci([string]$command) {
    $result = [Text.StringBuilder]::new(256)
    $errorCode = [SpeechSmokeMci]::mciSendString($command, $result, 256, [IntPtr]::Zero)
    if ($errorCode) { throw "MCI error $errorCode for $command" }
    return $result.ToString()
}

try {
    # Only fixed test text is submitted. Playback is muted before starting.
    $sample = 'This is a speech segment. The next segment is prepared during playback. '
    $rates = @('-25%', '+0%', '+25%', '+50%', '+100%')
    $labels = @('0.75x', '1x', '1.25x', '1.5x', '2x')
    $connection = $null
    $previousDuration = 0
    for ($index = 0; $index -lt $rates.Count; $index++) {
        $audioPath = Join-Path $OutputDirectory ("smoke_$index.mp3")
        $errorPath = Join-Path $OutputDirectory ("smoke_$index.error")
        $donePath = Join-Path $OutputDirectory ("smoke_$index.done")
        Invoke-EdgeSpeechRequest ($sample * 2) 'en-US-JennyNeural' $audioPath $errorPath $donePath $rates[$index]
        if (Test-Path -LiteralPath $errorPath) { throw ([IO.File]::ReadAllText($errorPath)) }
        if (-not (Test-Path -LiteralPath $donePath) -or (Get-Item -LiteralPath $audioPath).Length -eq 0) {
            throw 'Speech worker did not finish with nonempty audio.'
        }
        if ($index -eq 0) { $connection = $script:edgeConnection }
        elseif (-not [Object]::ReferenceEquals($connection, $script:edgeConnection)) {
            throw 'Speech connection was not reused for the next segment.'
        }
        $null = Invoke-Mci ('open "' + $audioPath + '" type mpegvideo alias YiDuSpeechSmoke')
        try {
            $null = Invoke-Mci 'set YiDuSpeechSmoke time format milliseconds'
            $duration = [int](Invoke-Mci 'status YiDuSpeechSmoke length')
            if ($duration -le 0 -or ($previousDuration -gt 0 -and $duration -ge $previousDuration)) {
                throw 'Increasing the speech speed did not shorten the audio.'
            }
            $previousDuration = $duration
            $null = Invoke-Mci 'setaudio YiDuSpeechSmoke volume to 0'
            $null = Invoke-Mci 'play YiDuSpeechSmoke'
            if ((Invoke-Mci 'status YiDuSpeechSmoke mode') -ne 'playing') { throw 'Audio did not start playing.' }
            Write-Output ("PASS: live speech {0}, {1} ms, {2} bytes, MCI playback" -f $labels[$index], $duration, (Get-Item -LiteralPath $audioPath).Length)
        }
        finally { $null = Invoke-Mci 'close YiDuSpeechSmoke' }
    }
}
finally {
    Close-EdgeSpeechConnection
    $parentProcess.Dispose()
}
