param(
    [string]$AutoHotkeyPath = (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey64.exe'),
    [switch]$Online
)

$ErrorActionPreference = 'Stop'
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\YiDu.ahk')).Replace("`r`n", "`n")
$testDirectory = Join-Path ([IO.Path]::GetTempPath()) ('YiDuSpeechTests_' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $testDirectory

function Get-SourceBlock([string]$start, [string]$end) {
    $startPosition = $source.IndexOf($start, [StringComparison]::Ordinal)
    $endPosition = $source.IndexOf($end, $startPosition, [StringComparison]::Ordinal)
    if ($startPosition -lt 0 -or $endPosition -lt 0) { throw "Cannot extract $start" }
    return $source.Substring($startPosition, $endPosition - $startPosition)
}

try {
    $globals = Get-SourceBlock 'global SpeechAudioPath :=' 'LoadConfig()'
    $speech = Get-SourceBlock "`nStartEdgeSpeech(text, voice)`n" "`nCleanupSpeech(*)`n"
    $speech = $speech.Replace('TrayTip(', 'TestTrayTip(')
    $worker = Get-SourceBlock "`nBuildEdgeSpeechWorkerPowerShell(" "`nGetAppearancePalette()`n"
    $tests = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'speech-tests.ahk'))
    $testPath = Join-Path $testDirectory 'speech-tests.ahk'
    [IO.File]::WriteAllText($testPath, "#Requires AutoHotkey v2.0`n#Warn All, StdOut`n" + $globals + $tests + $speech + $worker, [Text.UTF8Encoding]::new($true))

    & $AutoHotkeyPath /ErrorStdOut /iLib (Join-Path $testDirectory 'includes.txt') (Join-Path $PSScriptRoot '..\YiDu.ahk') | Write-Output
    if ($LASTEXITCODE -ne 0) { throw 'AutoHotkey source validation failed.' }
    & $AutoHotkeyPath /ErrorStdOut $testPath $testDirectory | Write-Output
    if ($LASTEXITCODE -ne 0) { throw 'Speech tests failed.' }

    $tokens = $null
    $parseErrors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $testDirectory 'worker.ps1'), [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
    Write-Output 'PASS: embedded PowerShell worker syntax'

    if ($Online) {
        $smokePath = Join-Path $PSScriptRoot 'speech-smoke.ps1'
        $workerPath = Join-Path $testDirectory 'worker.ps1'
        $stdoutPath = Join-Path $testDirectory 'smoke.stdout'
        $stderrPath = Join-Path $testDirectory 'smoke.stderr'
        $process = Start-Process powershell.exe -WindowStyle Hidden -PassThru -ArgumentList @(
            '-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
            '-File', ('"' + $smokePath + '"'), '-WorkerPath', ('"' + $workerPath + '"'),
            '-OutputDirectory', ('"' + $testDirectory + '"')) -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        try {
            if (-not $process.WaitForExit(60000)) { throw 'Online speech smoke test timed out.' }
            Get-Content -LiteralPath $stdoutPath
            if ($process.ExitCode -ne 0) { throw ([IO.File]::ReadAllText($stderrPath)) }
        }
        finally {
            if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
            $process.Dispose()
        }
    }
}
finally {
    Remove-Item -LiteralPath $testDirectory -Recurse -Force
}
