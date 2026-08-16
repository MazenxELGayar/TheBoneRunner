# Resize game art into GDK MicrosoftGame.config ShellVisuals slots.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$Project = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$IconSrcCandidates = @(
    (Join-Path $Project "Content\Assets\Images\Icon.png"),
    (Join-Path $Project "Content\Assets\Icon.png"),
    (Join-Path $Project "Content\UI\Icon.png")
)
$SplashSrcCandidates = @(
    (Join-Path $Project "Content\Assets\Images\Splash.png"),
    (Join-Path $Project "Content\Assets\Images\SplashScreen.png"),
    (Join-Path $Project "Content\Assets\Splash.png")
)

function First-Existing([string[]]$Paths) {
    foreach ($p in $Paths) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

$IconSrc = First-Existing $IconSrcCandidates
$SplashSrc = First-Existing $SplashSrcCandidates
$Dests = @(
    (Join-Path $Project "Build\Windows\MSGaming\Resources"),
    (Join-Path $Project "Build\Win64\MSGaming\Resources")
)

if (-not $IconSrc -or -not $SplashSrc) {
    Write-Host "Store tile art is not in the project yet. Skipping PNG generation."
    Write-Host "When you have them, put:"
    Write-Host "  Icon (square):  Content\Assets\Images\Icon.png"
    Write-Host "  Splash 1920x1080: Content\Assets\Images\Splash.png"
    Write-Host "then re-run this script."
    exit 0
}

function Save-CoverPng([string]$Src, [string]$Dst, [int]$W, [int]$H) {
    $srcImg = [System.Drawing.Image]::FromFile($Src)
    try {
        $bmp = New-Object System.Drawing.Bitmap $W, $H
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.CompositingQuality = [System.Drawing.CompositingQuality]::HighQuality
        $scale = [Math]::Max($W / [double]$srcImg.Width, $H / [double]$srcImg.Height)
        $dw = [int][Math]::Ceiling($srcImg.Width * $scale)
        $dh = [int][Math]::Ceiling($srcImg.Height * $scale)
        $x = [int](($W - $dw) / 2)
        $y = [int](($H - $dh) / 2)
        $g.DrawImage($srcImg, $x, $y, $dw, $dh)
        $g.Dispose()
        $dir = Split-Path $Dst -Parent
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $bmp.Save($Dst, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
    }
    finally { $srcImg.Dispose() }
    Write-Host ("Wrote {0}x{1}  {2}" -f $W, $H, $Dst)
}

foreach ($dest in $Dests) {
    Save-CoverPng $IconSrc (Join-Path $dest "SmallLogo.png") 44 44
    Save-CoverPng $IconSrc (Join-Path $dest "StoreLogo.png") 100 100
    Save-CoverPng $IconSrc (Join-Path $dest "Logo.png") 150 150
    Save-CoverPng $IconSrc (Join-Path $dest "Square480x480Logo.png") 480 480
    Save-CoverPng $SplashSrc (Join-Path $dest "SplashScreen.png") 1920 1080
}

$IcoSrcCandidates = @(
    (Join-Path $Project "Content\Assets\Images\Icon.ico"),
    (Join-Path $Project "Content\Assets\Icon.ico"),
    (Join-Path $Project "Build\Windows\Application.ico")
)
$IcoSrc = First-Existing $IcoSrcCandidates
if ($IcoSrc -and ($IcoSrc -ne (Join-Path $Project "Build\Windows\Application.ico"))) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Project "Build\Windows") | Out-Null
    Copy-Item -LiteralPath $IcoSrc -Destination (Join-Path $Project "Build\Windows\Application.ico") -Force
    Write-Host "Copied .ico -> Build\Windows\Application.ico (embedded on next Shipping build)"
}
