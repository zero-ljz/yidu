param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$sdkRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10'
$windowsMetadata = Get-ChildItem (Join-Path $sdkRoot 'UnionMetadata') -Recurse -Filter 'Windows.winmd' |
    Where-Object FullName -NotMatch '\\Facade\\' |
    Sort-Object FullName -Descending |
    Select-Object -First 1
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$windowsRuntime = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\System.Runtime.WindowsRuntime.dll'
$systemRuntime = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\System.Runtime.dll'

if (-not $windowsMetadata) {
    throw 'Windows Runtime metadata was not found. Install the Windows SDK.'
}

foreach ($path in @($csc, $windowsRuntime, $systemRuntime)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required build dependency was not found: $path"
    }
}

$OutputPath = [IO.Path]::GetFullPath($OutputPath)
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
& $csc /nologo /target:winexe /optimize+ "/out:$OutputPath" "/reference:$($windowsMetadata.FullName)" "/reference:$windowsRuntime" "/reference:$systemRuntime" (Join-Path $PSScriptRoot 'YiDuStartupTask.cs')
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OutputPath)) {
    throw "Failed to compile YiDuStartupTask.exe (exit $LASTEXITCODE)."
}
