# Package The Bone Runner Android App Bundle (Google Play .aab).
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$UatExtraArgs
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "The Bone Runner Android AAB"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$UeRoot = "F:\Unreal Engine\UE_5.8"
$Project = Join-Path $ProjectRoot "TheBoneRunner.uproject"
$Archive = Join-Path $ProjectRoot "Packages\Android"
$Log = Join-Path $env:TEMP "TheBoneRunner_Package_Android_AAB.log"
$RunUat = Join-Path $UeRoot "Engine\Build\BatchFiles\RunUAT.bat"

$pause = $true
$forward = @()
foreach ($a in $UatExtraArgs) {
    if ($a -ieq "-nopause") { $pause = $false } else { $forward += $a }
}

Write-Host "========================================"
Write-Host "The Bone Runner - Package Android AAB"
Write-Host "========================================"
Write-Host "PROJECT=$Project"
Write-Host "ARCHIVE=$Archive"
Write-Host "LOG=$Log"
Write-Host ""

if (-not (Test-Path -LiteralPath $RunUat)) {
    Write-Host "ERROR: RunUAT not found at $UeRoot" -ForegroundColor Red
    if ($pause) { Read-Host "Press Enter to close" | Out-Null }
    exit 1
}
if (-not (Test-Path -LiteralPath $Project)) {
    Write-Host "ERROR: Project not found: $Project" -ForegroundColor Red
    if ($pause) { Read-Host "Press Enter to close" | Out-Null }
    exit 1
}

New-Item -ItemType Directory -Force -Path $Archive | Out-Null
Write-Host "Close Unreal Editor first if Live Coding is active."
Write-Host "Needs local keystore: Build\Android\thebonerunner-release.keystore"
Write-Host ""

$argLine = @(
    "BuildCookRun",
    "-project=`"$Project`"",
    "-platform=Android",
    "-clientconfig=Shipping",
    "-cookflavor=ASTC",
    "-build", "-cook", "-stage", "-pak", "-package",
    "-archive", "-archivedirectory=`"$Archive`"",
    "-distribution",
    "-utf8output",
    "-NoLiveCoding"
) + $forward

& $RunUat @argLine 2>&1 | Tee-Object -FilePath $Log
$err = $LASTEXITCODE

Write-Host ""
Write-Host "UAT exit code: $err"
Write-Host "Full log: $Log"
Write-Host "Look for .aab under: $Archive"
Get-ChildItem -LiteralPath $Archive -Recurse -Filter "*.aab" -ErrorAction SilentlyContinue |
    ForEach-Object { Write-Host ("  " + $_.FullName) }

if ($err -ne 0) {
    Write-Host "FAILED." -ForegroundColor Red
    if ($pause) { Read-Host "Press Enter to close" | Out-Null }
    exit $err
}

Write-Host "SUCCESS — upload the .aab in Play Console -> Production / Testing -> Create release." -ForegroundColor Green
if ($pause) { Read-Host "Press Enter to close" | Out-Null }
exit 0
