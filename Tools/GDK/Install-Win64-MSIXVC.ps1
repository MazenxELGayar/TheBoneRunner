# Install RedHood .msixvc via wdapp. Asks where to put the game.
param(
    [string]$PackagePath,
    [string]$InstallFolder
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "RedHood GDK install"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$DefaultDir = Join-Path $ProjectRoot "Saved\Packages\Windows\MSGameStore\Shipping"
$ArchiveDir = Join-Path $ProjectRoot "Packages\Win64_GDK"
$GdkBin = "F:\Unreal Engine\Microsoft\GDK\GDK_2604.2.7849\bin\wdapp.exe"

function Repair-GdkPath([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $cleaned = $Value.Trim().Trim('"')
    $cleaned = $cleaned -replace '"\s*/M\s*$', ''
    $cleaned = $cleaned -replace '\s+/M\s*$', ''
    $cleaned = $cleaned.Trim().Trim('"')
    if (-not $cleaned.EndsWith("\")) { $cleaned += "\" }
    if (Test-Path -LiteralPath $cleaned) { return $cleaned }
    return $null
}

function Find-LatestMsixvc([string]$Dir) {
    if (-not (Test-Path -LiteralPath $Dir)) { return $null }
    return Get-ChildItem -LiteralPath $Dir -Filter "*.msixvc" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

function Read-Folder([string]$Prompt) {
    Write-Host $Prompt
    Write-Host "Example: F:\Games\RedHood"
    $raw = Read-Host "Folder"
    $raw = $raw.Trim().Trim('"')
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return $raw
}

$env:GameDK = Repair-GdkPath $env:GameDK
if (-not $env:GameDK) { $env:GameDK = Repair-GdkPath ([Environment]::GetEnvironmentVariable("GameDK", "Machine")) }
if (-not $env:GameDK) { $env:GameDK = Repair-GdkPath ([Environment]::GetEnvironmentVariable("GameDK", "User")) }
if (-not $env:GameDK) { $env:GameDK = "F:\Unreal Engine\Microsoft\GDK\GDK_2604.2.7849\" }
$wdapp = Join-Path $env:GameDK "bin\wdapp.exe"
if (-not (Test-Path -LiteralPath $wdapp)) { $wdapp = $GdkBin }

Write-Host "========================================"
Write-Host "RedHood - GDK local install"
Write-Host "========================================"
Write-Host "wdapp: $wdapp"
Write-Host ""

if (-not $PackagePath) {
    $PackagePath = Find-LatestMsixvc $DefaultDir
    if (-not $PackagePath) { $PackagePath = Find-LatestMsixvc $ArchiveDir }
}

if (-not $PackagePath -or -not (Test-Path -LiteralPath $PackagePath)) {
    Write-Host "ERROR: .msixvc not found. Run Package-Win64-MSIXVC.bat first." -ForegroundColor Red
    Read-Host "Press Enter to close" | Out-Null
    exit 1
}

Write-Host "Package: $PackagePath"
Write-Host ""

if (-not $InstallFolder) {
    $InstallFolder = Read-Folder "Where do you want to install the game?"
}
if (-not $InstallFolder) {
    Write-Host "ERROR: no install folder given." -ForegroundColor Red
    Read-Host "Press Enter to close" | Out-Null
    exit 1
}

$InstallFolder = [IO.Path]::GetFullPath($InstallFolder)
$drive = ([IO.Path]::GetPathRoot($InstallFolder)).TrimEnd("\")
if ($drive.Length -lt 2) {
    Write-Host "ERROR: install folder must be a local drive path (for example F:\Games\RedHood)." -ForegroundColor Red
    Read-Host "Press Enter to close" | Out-Null
    exit 1
}
$driveLetter = $drive.Substring(0, 1)

$pkgCopyDir = Join-Path (Split-Path $InstallFolder -Parent) "Installation"
if ([string]::IsNullOrWhiteSpace((Split-Path $InstallFolder -Parent))) {
    $pkgCopyDir = Join-Path $InstallFolder "Installation"
}

Write-Host ""
Write-Host "Game will install to: $InstallFolder"
Write-Host ("Installer copy:        {0}" -f $pkgCopyDir)
Write-Host ("Drive:                 {0}:" -f $driveLetter)
Write-Host ""
$confirm = Read-Host "Proceed? [Y/n]"
if ($confirm -and $confirm -notmatch "^[Yy]") {
    Write-Host "Cancelled."
    Read-Host "Press Enter to close" | Out-Null
    exit 0
}

if (-not (Test-Path -LiteralPath $wdapp)) {
    Write-Host "ERROR: wdapp.exe not found." -ForegroundColor Red
    Read-Host "Press Enter to close" | Out-Null
    exit 1
}

New-Item -ItemType Directory -Force -Path $InstallFolder | Out-Null
New-Item -ItemType Directory -Force -Path $pkgCopyDir | Out-Null
$destPkg = Join-Path $pkgCopyDir ([IO.Path]::GetFileName($PackagePath))
Copy-Item -LiteralPath $PackagePath -Destination $destPkg -Force
Write-Host "Copied installer to $destPkg"
Write-Host ""

Write-Host "Registering install folder for drive ${driveLetter}: ..."
Write-Host "(Windows Developer Mode must be on: Settings -> System -> For developers)"
$folderOut = & $wdapp gamefolder "${driveLetter}:" /set $InstallFolder 2>&1
$folderOut | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "wdapp gamefolder failed. Enable Developer Mode, then run this .bat as Administrator." -ForegroundColor Yellow
    Write-Host "The .msixvc is already copied to: $destPkg"
    Read-Host "Press Enter to close" | Out-Null
    exit 1
}

Write-Host ""
Write-Host "Installing (package first, then /drive=$driveLetter) ..."
# Syntax: wdapp install <package filepath> [/AllChunks] [/drive=<letter>]
$installArgs = @("install", $destPkg, "/drive=$driveLetter", "/AllChunks")
Write-Host ("Command: wdapp " + ($installArgs -join " "))
$installOut = & $wdapp @installArgs 2>&1
$installOut | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    Write-Host "wdapp install failed." -ForegroundColor Red
    Read-Host "Press Enter to close" | Out-Null
    exit 1
}

Write-Host ""
Write-Host "Applying folder / shortcut icons if an .ico is available ..."
$iconScript = Join-Path $PSScriptRoot "Apply-GameFolderIcons.ps1"
& $iconScript -GameRoot $InstallFolder

Write-Host ""
Write-Host "Installed apps:"
& $wdapp list 2>&1 | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "Done."
Write-Host "Installer: $destPkg"
Write-Host "Game:      $InstallFolder"
Write-Host "Launch:    `"$wdapp`" launch <AUMID from list above>"
Read-Host "Press Enter to close" | Out-Null
exit 0
