$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sourcePath = Join-Path $root 'assets\yidu-icon.png'
$assetsPath = Join-Path $PSScriptRoot 'Assets'

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Application icon was not found: $sourcePath"
}

New-Item -ItemType Directory -Force -Path $assetsPath | Out-Null

function Write-Logo([string]$Name, [int]$Width, [int]$Height, [int]$LogoSize) {
    $source = [System.Drawing.Image]::FromFile($sourcePath)
    try {
        $bitmap = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.Clear([System.Drawing.Color]::Transparent)
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $x = [int](($Width - $LogoSize) / 2)
                $y = [int](($Height - $LogoSize) / 2)
                $graphics.DrawImage($source, $x, $y, $LogoSize, $LogoSize)
            }
            finally {
                $graphics.Dispose()
            }
            $bitmap.Save((Join-Path $assetsPath $Name), [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $bitmap.Dispose()
        }
    }
    finally {
        $source.Dispose()
    }
}

Write-Logo 'StoreLogo.png' 50 50 50
Write-Logo 'Square44x44Logo.png' 44 44 44
Write-Logo 'Square150x150Logo.png' 150 150 150
Write-Logo 'Wide310x150Logo.png' 310 150 150
