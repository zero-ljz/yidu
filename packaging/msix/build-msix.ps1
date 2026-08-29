param(
    [string]$Version = '',
    [string]$OutputPath = '',
    [ValidateSet('Sideload', 'Store')]
    [string]$Mode = 'Sideload',
    [string]$IdentityName = 'YiDu.Desktop',
    [string]$Publisher = 'CN=zero-ljz',
    [string]$PublisherDisplayName = 'zero-ljz',
    [string]$Ahk2ExePath = '',
    [string]$AhkBasePath = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sourcePath = Join-Path $root 'YiDu.ahk'
$iconPath = Join-Path $root 'YiDu.ico'
$buildRoot = Join-Path $root 'build\msix'
$layoutPath = Join-Path $buildRoot 'layout'
$developmentIdentityName = 'YiDu.Desktop'
$developmentPublisher = 'CN=zero-ljz'
$storeIdentityName = 'zero-ljz.65035B1959F4'
$storePublisher = 'CN=2393B316-80C9-466F-AA0D-A54F1924BC33'
$storePublisherDisplayName = 'zero-ljz'

function Find-FirstExistingPath([string]$ExplicitPath, [string[]]$Candidates, [string]$Description) {
    if ($ExplicitPath) {
        $resolved = [IO.Path]::GetFullPath($ExplicitPath)
        if (-not (Test-Path -LiteralPath $resolved)) {
            throw "$Description was not found: $resolved"
        }
        return $resolved
    }

    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return [IO.Path]::GetFullPath($candidate)
        }
    }

    throw "$Description was not found. Install AutoHotkey v2 or pass its path explicitly."
}

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Application source was not found: $sourcePath"
}
if (-not (Test-Path -LiteralPath $iconPath)) {
    throw "Application icon was not found: $iconPath"
}

if (-not $Version) {
    $scriptText = Get-Content -Raw -Encoding utf8 $sourcePath
    $versionMatch = [regex]::Match($scriptText, '(?m)^;@Ahk2Exe-SetVersion\s+(\d+\.\d+\.\d+(?:\.\d+)?)\s*$')
    if (-not $versionMatch.Success) {
        throw 'Unable to read the MSIX version from the Ahk2Exe version directive.'
    }
    $Version = $versionMatch.Groups[1].Value
}

if ($Version -match '^\d+\.\d+\.\d+$') {
    $Version += '.0'
}
if ($Version -notmatch '^\d+\.\d+\.\d+\.\d+$') {
    throw "MSIX version must have three or four numeric parts: $Version"
}
foreach ($part in ($Version -split '\.')) {
    if ([int64]$part -gt 65535) {
        throw "Each MSIX version part must be between 0 and 65535: $Version"
    }
}

if ($Mode -eq 'Store') {
    if ($IdentityName -eq $developmentIdentityName) {
        $IdentityName = $storeIdentityName
    }
    if ($Publisher -eq $developmentPublisher) {
        $Publisher = $storePublisher
    }
    if (-not $PublisherDisplayName) {
        $PublisherDisplayName = $storePublisherDisplayName
    }
}

$displayVersion = (($Version -split '\.')[0..2] -join '.')
if (-not $OutputPath) {
    $packageFlavor = if ($Mode -eq 'Store') { 'Store-MSIX' } else { 'MSIX' }
    $OutputPath = Join-Path $root "release\YiDu-$displayVersion-$packageFlavor-x64.msix"
}
elseif (-not [IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $root $OutputPath
}
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
if ([IO.Path]::GetExtension($OutputPath) -ne '.msix') {
    throw "MSIX output path must use the .msix extension: $OutputPath"
}

$Ahk2ExePath = Find-FirstExistingPath $Ahk2ExePath @(
    (Join-Path $env:ProgramFiles 'AutoHotkey\Compiler\Ahk2Exe.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'AutoHotkey\Compiler\Ahk2Exe.exe')
) 'Ahk2Exe'
$AhkBasePath = Find-FirstExistingPath $AhkBasePath @(
    (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey64.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'AutoHotkey\v2\AutoHotkey64.exe')
) 'AutoHotkey v2 x64 base executable'

$sdkRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
$sdkBin = Get-ChildItem $sdkRoot -Directory |
    Where-Object Name -Match '^\d+\.\d+\.\d+\.\d+$' |
    Where-Object {
        (Test-Path -LiteralPath (Join-Path $_.FullName 'x64\MakeAppx.exe')) -and
        (Test-Path -LiteralPath (Join-Path $_.FullName 'x64\SignTool.exe'))
    } |
    Sort-Object { [version]$_.Name } -Descending |
    Select-Object -First 1
if (-not $sdkBin) {
    throw 'MakeAppx.exe and SignTool.exe were not found in the installed Windows SDKs.'
}
$makeAppx = Join-Path $sdkBin.FullName 'x64\MakeAppx.exe'
$signTool = Join-Path $sdkBin.FullName 'x64\SignTool.exe'

if (Test-Path -LiteralPath $layoutPath) {
    Remove-Item -LiteralPath $layoutPath -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $layoutPath | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $layoutPath 'tools') | Out-Null

$compiledPath = Join-Path $layoutPath 'YiDu.exe'
$compilerArguments = @(
    '/in', ('"' + $sourcePath + '"'),
    '/out', ('"' + $compiledPath + '"'),
    '/icon', ('"' + $iconPath + '"'),
    '/base', ('"' + $AhkBasePath + '"')
)
$compilerProcess = Start-Process -FilePath $Ahk2ExePath -ArgumentList $compilerArguments -WindowStyle Hidden -Wait -PassThru
if ($compilerProcess.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $compiledPath)) {
    throw "Ahk2Exe failed with exit code $($compilerProcess.ExitCode)."
}

Copy-Item -LiteralPath $iconPath -Destination (Join-Path $layoutPath 'YiDu.ico') -Force
Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination (Join-Path $layoutPath 'LICENSE.txt') -Force

$startupHelperPath = Join-Path $layoutPath 'tools\YiDuStartupTask.exe'
& (Join-Path $PSScriptRoot 'build-startup-helper.ps1') -OutputPath $startupHelperPath
if ($LASTEXITCODE -ne 0) {
    throw "Startup helper build failed with exit code $LASTEXITCODE."
}
$helperProcess = Start-Process -FilePath $startupHelperPath -ArgumentList '--self-test' -WindowStyle Hidden -Wait -PassThru
if ($helperProcess.ExitCode -ne 0) {
    throw "Startup helper self-test failed with exit code $($helperProcess.ExitCode)."
}

& (Join-Path $PSScriptRoot 'generate-assets.ps1')
$layoutAssets = Join-Path $layoutPath 'Assets'
New-Item -ItemType Directory -Force -Path $layoutAssets | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot 'Assets\*') -Destination $layoutAssets -Force

$manifest = Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot 'AppxManifest.xml.template')
$manifest = $manifest.Replace('__IDENTITY_NAME__', [Security.SecurityElement]::Escape($IdentityName))
$manifest = $manifest.Replace('__PUBLISHER__', [Security.SecurityElement]::Escape($Publisher))
$manifest = $manifest.Replace('__PUBLISHER_DISPLAY_NAME__', [Security.SecurityElement]::Escape($PublisherDisplayName))
$manifest = $manifest.Replace('__VERSION__', $Version)
[IO.File]::WriteAllText((Join-Path $layoutPath 'AppxManifest.xml'), $manifest, (New-Object Text.UTF8Encoding($false)))

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
Remove-Item -LiteralPath $OutputPath -Force -ErrorAction SilentlyContinue
& $makeAppx pack /o /h SHA256 /d $layoutPath /p $OutputPath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OutputPath)) {
    throw "MakeAppx failed with exit code $LASTEXITCODE."
}

if ($Mode -eq 'Sideload') {
    $friendlyName = 'YiDu MSIX Development'
    $certificate = Get-ChildItem Cert:\CurrentUser\My |
        Where-Object { $_.Subject -eq $Publisher -and $_.FriendlyName -eq $friendlyName -and $_.HasPrivateKey -and $_.NotAfter -gt (Get-Date).AddDays(30) } |
        Sort-Object NotAfter -Descending |
        Select-Object -First 1
    if (-not $certificate) {
        $certificate = New-SelfSignedCertificate -Type Custom -Subject $Publisher -FriendlyName $friendlyName `
            -CertStoreLocation Cert:\CurrentUser\My -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 `
            -KeyExportPolicy Exportable -KeyUsage DigitalSignature -NotAfter (Get-Date).AddYears(3) `
            -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}')
    }

    & $signTool sign /fd SHA256 /sha1 $certificate.Thumbprint $OutputPath
    if ($LASTEXITCODE -ne 0) {
        throw "SignTool failed with exit code $LASTEXITCODE."
    }

    $certificatePath = [IO.Path]::ChangeExtension($OutputPath, '.cer')
    Export-Certificate -Cert $certificate -FilePath $certificatePath -Force | Out-Null
}

Write-Host "MSIX created: $OutputPath"
