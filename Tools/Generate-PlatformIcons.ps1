# Resize Content/Assets/Images source art into Android, Windows, and Microsoft Store sizes.
# Sources: iconSquare.png (app icon) and 1920x1080.png (splash / hero).
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$Project = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Images = Join-Path $Project "Content\Assets\Images"
$IconSrc = Join-Path $Images "iconSquare.png"
$SplashSrc = Join-Path $Images "1920x1080.png"
if (-not (Test-Path -LiteralPath $IconSrc)) { $IconSrc = Join-Path $Images "Icon.png" }
if (-not (Test-Path -LiteralPath $SplashSrc)) { $SplashSrc = Join-Path $Images "Splash.png" }

function Save-CoverPng([string]$Src, [string]$Dst, [int]$W, [int]$H, [double]$AnchorY = 0.5) {
    $srcImg = [System.Drawing.Image]::FromFile($Src)
    try {
        $bmp = New-Object System.Drawing.Bitmap $W, $H
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.Clear([System.Drawing.Color]::Black)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $scale = [Math]::Max($W / [double]$srcImg.Width, $H / [double]$srcImg.Height)
        $dw = [int][Math]::Ceiling($srcImg.Width * $scale)
        $dh = [int][Math]::Ceiling($srcImg.Height * $scale)
        $x = [int](($W - $dw) / 2)
        $y = [int](($H - $dh) * $AnchorY)
        $g.DrawImage($srcImg, $x, $y, $dw, $dh)
        $g.Dispose()
        $dir = Split-Path $Dst -Parent
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $bmp.Save($Dst, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
    }
    finally { $srcImg.Dispose() }
    Write-Host ("  {0,4}x{1,-4}  {2}" -f $W, $H, $Dst.Substring($Project.Length + 1))
}

function Save-IcoFromPngs([string[]]$PngPaths, [string]$Dst) {
    $images = @()
    foreach ($p in $PngPaths) {
        $bytes = [IO.File]::ReadAllBytes($p)
        $bmp = [System.Drawing.Bitmap]::FromFile($p)
        try {
            $images += [pscustomobject]@{ W = $bmp.Width; H = $bmp.Height; Bytes = $bytes }
        }
        finally { $bmp.Dispose() }
    }
    $count = $images.Count
    $ms = New-Object IO.MemoryStream
    $bw = New-Object IO.BinaryWriter $ms
    $bw.Write([uint16]0)
    $bw.Write([uint16]1)
    $bw.Write([uint16]$count)
    $offset = 6 + (16 * $count)
    foreach ($im in $images) {
        $w = if ($im.W -ge 256) { [byte]0 } else { [byte]$im.W }
        $h = if ($im.H -ge 256) { [byte]0 } else { [byte]$im.H }
        $bw.Write($w)
        $bw.Write($h)
        $bw.Write([byte]0)
        $bw.Write([byte]0)
        $bw.Write([uint16]1)
        $bw.Write([uint16]32)
        $bw.Write([uint32]$im.Bytes.Length)
        $bw.Write([uint32]$offset)
        $offset += $im.Bytes.Length
    }
    foreach ($im in $images) { $bw.Write($im.Bytes) }
    $bw.Flush()
    $dir = Split-Path $Dst -Parent
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    [IO.File]::WriteAllBytes($Dst, $ms.ToArray())
    $bw.Dispose()
    $ms.Dispose()
    Write-Host ("  ICO         {0}" -f $Dst.Substring($Project.Length + 1))
}

if (-not (Test-Path -LiteralPath $IconSrc)) { throw "Missing icon: expected Content\Assets\Images\iconSquare.png" }
if (-not (Test-Path -LiteralPath $SplashSrc)) { throw "Missing splash: expected Content\Assets\Images\1920x1080.png" }

Copy-Item -LiteralPath $IconSrc -Destination (Join-Path $Images "Icon.png") -Force
Copy-Item -LiteralPath $SplashSrc -Destination (Join-Path $Images "Splash.png") -Force
Write-Host "Canonical sources: Icon.png and Splash.png"

$IconPack = Join-Path $Images "Icons"
Write-Host ""
Write-Host "Windows / editor icon pack (Content\Assets\Images\Icons)"
$icoPngs = @()
foreach ($size in @(16, 20, 24, 32, 36, 40, 48, 64, 72, 96, 128, 144, 192, 256, 512, 1024)) {
    $png = Join-Path $IconPack ("{0}x{0}.png" -f $size)
    Save-CoverPng $IconSrc $png $size $size 0.5
    Copy-Item -LiteralPath $png -Destination (Join-Path $IconPack ("{0}.png" -f $size)) -Force
    if ($size -in @(16, 24, 32, 48, 64, 128, 256)) { $icoPngs += $png }
}

$IcoPath = Join-Path $IconPack "Icon.ico"
Save-IcoFromPngs $icoPngs $IcoPath
Copy-Item -LiteralPath $IcoPath -Destination (Join-Path $Images "Icon.ico") -Force
New-Item -ItemType Directory -Force -Path (Join-Path $Project "Build\Windows") | Out-Null
Copy-Item -LiteralPath $IcoPath -Destination (Join-Path $Project "Build\Windows\Application.ico") -Force
Write-Host "  Copied Application.ico -> Build\Windows\Application.ico"

Write-Host ""
Write-Host "Microsoft Store / GDK ShellVisuals"
$gdkDests = @(
    (Join-Path $Project "Build\Windows\MSGaming\Resources"),
    (Join-Path $Project "Build\Win64\MSGaming\Resources")
)
foreach ($dest in $gdkDests) {
    Save-CoverPng $IconSrc (Join-Path $dest "SmallLogo.png") 44 44
    Save-CoverPng $IconSrc (Join-Path $dest "StoreLogo.png") 100 100
    Save-CoverPng $IconSrc (Join-Path $dest "Logo.png") 150 150
    Save-CoverPng $IconSrc (Join-Path $dest "Square480x480Logo.png") 480 480
    Save-CoverPng $SplashSrc (Join-Path $dest "SplashScreen.png") 1920 1080 0.5
}

Write-Host ""
Write-Host "Microsoft Store listing logos"
$Listing = Join-Path $Project "Tools\GDK\StoreListing\Assets"
Save-CoverPng $IconSrc (Join-Path $Listing "Logos\Poster1440x2160.png") 1440 2160 0.0
Save-CoverPng $IconSrc (Join-Path $Listing "Logos\Box1080x1080.png") 1080 1080 0.0
Save-CoverPng $IconSrc (Join-Path $Listing "Logos\Tile300x300.png") 300 300 0.0
Save-CoverPng $SplashSrc (Join-Path $Listing "Promo\TitledHero1920x1080.png") 1920 1080 0.5
Save-CoverPng $IconSrc (Join-Path $Listing "Promo\FeaturedSquare1080x1080.png") 1080 1080 0.55

Write-Host ""
Write-Host "Android launcher / splash / Play Store"
$AndroidRes = Join-Path $Project "Build\Android\res"
$androidIcons = @(
    @{ Folder = "drawable-ldpi";    Size = 36 },
    @{ Folder = "drawable-mdpi";    Size = 48 },
    @{ Folder = "drawable-hdpi";    Size = 72 },
    @{ Folder = "drawable-xhdpi";   Size = 96 },
    @{ Folder = "drawable-xxhdpi";  Size = 144 },
    @{ Folder = "drawable-xxxhdpi"; Size = 192 }
)
foreach ($e in $androidIcons) {
    Save-CoverPng $IconSrc (Join-Path $AndroidRes ($e.Folder + "\icon.png")) $e.Size $e.Size
}
Save-CoverPng $IconSrc (Join-Path $AndroidRes "drawable\icon.png") 192 192
Save-CoverPng $SplashSrc (Join-Path $AndroidRes "drawable\splashscreen_landscape.png") 1920 1080 0.5
Save-CoverPng $SplashSrc (Join-Path $AndroidRes "drawable\splashscreen_portrait.png") 1080 1920 0.5
Save-CoverPng $SplashSrc (Join-Path $AndroidRes "drawable\downloadimageh.png") 1920 1080 0.5
Save-CoverPng $SplashSrc (Join-Path $AndroidRes "drawable\downloadimagev.png") 1080 1920 0.5
Save-CoverPng $IconSrc (Join-Path $Images "PlayStore\HiResIcon512.png") 512 512
Save-CoverPng $SplashSrc (Join-Path $Images "PlayStore\FeatureGraphic1024x500.png") 1024 500 0.5

function Save-CoverJpeg([string]$Src, [string]$Dst, [int]$W, [int]$H, [double]$AnchorY = 0.5) {
    $srcImg = [System.Drawing.Image]::FromFile($Src)
    try {
        $bmp = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.Clear([System.Drawing.Color]::Black)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $scale = [Math]::Max($W / [double]$srcImg.Width, $H / [double]$srcImg.Height)
        $dw = [int][Math]::Ceiling($srcImg.Width * $scale)
        $dh = [int][Math]::Ceiling($srcImg.Height * $scale)
        $x = [int](($W - $dw) / 2)
        $y = [int](($H - $dh) * $AnchorY)
        $g.DrawImage($srcImg, $x, $y, $dw, $dh)
        $g.Dispose()
        $dir = Split-Path $Dst -Parent
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
        $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
        $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality, [long]92)
        $bmp.Save($Dst, $codec, $ep)
        $bmp.Dispose()
    }
    finally { $srcImg.Dispose() }
    Write-Host ("  {0,4}x{1,-4}  {2}" -f $W, $H, $Dst.Substring($Project.Length + 1))
}

Write-Host ""
Write-Host "Google Play Console listing graphics"
$Play = Join-Path $Project "Tools\PlayStore\Assets"
New-Item -ItemType Directory -Force -Path $Play | Out-Null
Copy-Item -LiteralPath (Join-Path $Images "PlayStore\HiResIcon512.png") -Destination (Join-Path $Play "HiResIcon512.png") -Force
Copy-Item -LiteralPath (Join-Path $Images "PlayStore\FeatureGraphic1024x500.png") -Destination (Join-Path $Play "FeatureGraphic1024x500.png") -Force
$phone = Join-Path $Play "Phone"
$tab7 = Join-Path $Play "Tablet7"
$tab10 = Join-Path $Play "Tablet10"
Save-CoverJpeg $SplashSrc (Join-Path $phone "01.jpg") 1920 1080 0.45
Save-CoverJpeg $SplashSrc (Join-Path $phone "02.jpg") 1920 1080 0.15
Save-CoverJpeg $SplashSrc (Join-Path $phone "03.jpg") 1920 1080 0.85
Save-CoverJpeg $IconSrc   (Join-Path $phone "04.jpg") 1920 1080 0.35
Save-CoverJpeg $IconSrc   (Join-Path $phone "05.jpg") 1920 1080 0.55
Save-CoverJpeg $IconSrc   (Join-Path $phone "06.jpg") 1920 1080 0.0
Save-CoverJpeg $SplashSrc (Join-Path $phone "07.jpg") 1920 1080 0.6
Save-CoverJpeg $IconSrc   (Join-Path $phone "08.jpg") 1920 1080 0.7
Save-CoverJpeg $SplashSrc (Join-Path $tab7 "01.jpg") 1920 1200 0.45
Save-CoverJpeg $IconSrc   (Join-Path $tab7 "02.jpg") 1920 1200 0.4
Save-CoverJpeg $SplashSrc (Join-Path $tab10 "01.jpg") 2560 1600 0.45
Save-CoverJpeg $IconSrc   (Join-Path $tab10 "02.jpg") 2560 1600 0.4

Write-Host ""
Write-Host "Done."
Write-Host "Play Console upload pack: Tools\PlayStore\"
Write-Host "Windows exe icon is Build\Windows\Application.ico (used on the next Shipping build)."
