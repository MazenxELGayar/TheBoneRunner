# Live progress wrapper for The Bone Run Win64 MSIXVC packaging.
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$UatExtraArgs
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "The Bone Run Win64 MSIXVC package"

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$UeRoot = "F:\Unreal Engine\UE_5.8"
$Project = Join-Path $ProjectRoot "TheBoneRun.uproject"
$Archive = Join-Path $ProjectRoot "Packages\Win64_GDK"
$Log = Join-Path $env:TEMP "TheBoneRun_Package_Win64_GDK.log"
$RunUat = Join-Path $UeRoot "Engine\Build\BatchFiles\RunUAT.bat"
$MsixOut = Join-Path $ProjectRoot "Saved\Packages\Windows\MSGameStore\Shipping"
$Pf86 = ${env:ProgramFiles(x86)}

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

$env:GameDK = Repair-GdkPath $env:GameDK
if (-not $env:GameDK) { $env:GameDK = Repair-GdkPath ([Environment]::GetEnvironmentVariable("GameDK", "Machine")) }
if (-not $env:GameDK) { $env:GameDK = Repair-GdkPath ([Environment]::GetEnvironmentVariable("GameDK", "User")) }
if (-not $env:GameDK) { $env:GameDK = "F:\Unreal Engine\Microsoft\GDK\GDK_2604.2.7849\" }

$env:GameDKLatest = Repair-GdkPath $env:GameDKLatest
if (-not $env:GameDKLatest) { $env:GameDKLatest = Repair-GdkPath ([Environment]::GetEnvironmentVariable("GameDKLatest", "Machine")) }
if (-not $env:GameDKLatest) { $env:GameDKLatest = Repair-GdkPath (Join-Path $env:GameDK "260402\") }

$pause = $true
$forward = @()
foreach ($a in $UatExtraArgs) {
    if ($a -ieq "-nopause") { $pause = $false } else { $forward += $a }
}

Write-Host "========================================"
Write-Host "The Bone Run - Package Win64 MSIXVC"
Write-Host "========================================"
Write-Host "UE_ROOT=$UeRoot"
Write-Host "PROJECT=$Project"
Write-Host "GameDK=$($env:GameDK)"
Write-Host "LOG=$Log"
if ($forward.Count) { Write-Host ("Extra args: " + ($forward -join " ")) }
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

$netFx = Join-Path $Pf86 "Reference Assemblies\Microsoft\Framework\.NETFramework"
if (-not (Test-Path -LiteralPath $netFx)) {
    Write-Host "WARNING: .NET Framework targeting pack not found." -ForegroundColor Yellow
    Write-Host "  winget install Microsoft.DotNet.Framework.DeveloperPack_4"
    Write-Host ""
}

New-Item -ItemType Directory -Force -Path $Archive | Out-Null

Write-Host "Close Unreal Editor first if Live Coding is active."
Write-Host "Progress updates while UAT runs. Cook can take a long time."
Write-Host "Store IDs must be filled in Config\UserEngine.ini before packaging will succeed."
Write-Host ""

$wrap = Join-Path $env:TEMP "TheBoneRun_Package_Win64_GDK_run.cmd"
$argLine = @(
    "BuildCookRun",
    "-project=`"$Project`"",
    "-platform=Win64",
    "-clientconfig=Shipping",
    "-build", "-cook", "-stage", "-pak", "-iostore", "-compressed",
    "-package",
    "-archive", "-archivedirectory=`"$Archive`"",
    "-utf8output",
    "-NoLiveCoding"
) + $forward
$argLine = $argLine -join " "

@(
    "@echo off",
    "setlocal",
    "call `"$RunUat`" $argLine > `"$Log`" 2>&1",
    "exit /b %ERRORLEVEL%"
) | Set-Content -LiteralPath $wrap -Encoding ASCII

$stages = [ordered]@{
    "BUILD COMMAND STARTED"        = @{ Pct = 8;  Name = "Build" }
    "BUILD COMMAND COMPLETED"      = @{ Pct = 18; Name = "Build done" }
    "COOK COMMAND STARTED"         = @{ Pct = 22; Name = "Cook" }
    "COOK COMMAND COMPLETED"       = @{ Pct = 68; Name = "Cook done" }
    "STAGE COMMAND STARTED"        = @{ Pct = 72; Name = "Stage" }
    "STAGE COMMAND COMPLETED"      = @{ Pct = 82; Name = "Stage done" }
    "PACKAGE COMMAND STARTED"      = @{ Pct = 86; Name = "Package" }
    "Successfully created package" = @{ Pct = 96; Name = "Package created" }
    "ARCHIVE COMMAND STARTED"      = @{ Pct = 97; Name = "Archive" }
}

function Get-Bar([int]$Pct) {
    $width = 28
    if ($Pct -lt 0) { $Pct = 0 }
    if ($Pct -gt 100) { $Pct = 100 }
    $fill = [int][math]::Round($width * $Pct / 100.0)
    return "[" + ("#" * $fill) + ("-" * ($width - $fill)) + "]"
}

function Short-Line([string]$Line, [int]$Max = 80) {
    if ([string]::IsNullOrWhiteSpace($Line)) { return "" }
    $t = $Line.Trim()
    if ($t.Length -le $Max) { return $t }
    return $t.Substring(0, $Max - 3) + "..."
}

if (Test-Path -LiteralPath $Log) { Remove-Item -LiteralPath $Log -Force -ErrorAction SilentlyContinue }

$proc = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", "`"$wrap`"") -WorkingDirectory $UeRoot -PassThru -WindowStyle Hidden

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$pct = 4
$stage = "Starting UAT"
$lastLine = ""
$seenCount = 0
$spin = @("|", "/", "-", "\")
$spinI = 0

try {
    while (-not $proc.HasExited) {
        if (Test-Path -LiteralPath $Log) {
            $lines = @(Get-Content -LiteralPath $Log -ErrorAction SilentlyContinue)
            if ($lines.Count -gt $seenCount) {
                for ($i = $seenCount; $i -lt $lines.Count; $i++) {
                    $line = [string]$lines[$i]
                    $lastLine = $line
                    foreach ($key in $stages.Keys) {
                        if ($line.IndexOf($key, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                            $pct = $stages[$key].Pct
                            $stage = $stages[$key].Name
                        }
                    }
                }
                $seenCount = $lines.Count
            }
        }

        if ($stage -eq "Cook" -and $pct -lt 66) {
            $pct = [Math]::Min(66, 22 + [int]($sw.Elapsed.TotalMinutes * 3))
        }

        $elapsed = $sw.Elapsed.ToString("mm\:ss")
        $bar = Get-Bar $pct
        $spinChar = $spin[$spinI % 4]
        $spinI++
        $status = "{0}  {1,3}%  {2,-16}  {3}  {4}" -f $bar, $pct, $stage, $elapsed, $spinChar
        $detail = Short-Line $lastLine

        Write-Progress -Activity "Packaging The Bone Run for Microsoft Store (.msixvc)" -Status $status -PercentComplete $pct -CurrentOperation $detail
        Write-Host ("`r{0}  {1}" -f $status, $detail).PadRight(150) -NoNewline
        Start-Sleep -Milliseconds 500
    }
}
finally {
    if (-not $proc.HasExited) { $proc.WaitForExit() }
    Start-Sleep -Milliseconds 300
    Write-Host ""
    Write-Progress -Activity "Packaging The Bone Run for Microsoft Store (.msixvc)" -Completed
}

$err = $proc.ExitCode
$sw.Stop()

if ($err -eq 0) {
    Write-Host ("{0}  100%  Done              {1}" -f (Get-Bar 100), $sw.Elapsed.ToString("mm\:ss")) -ForegroundColor Green
} else {
    Write-Host ("{0}  {1,3}%  FAILED            {2}" -f (Get-Bar $pct), $pct, $sw.Elapsed.ToString("mm\:ss")) -ForegroundColor Red
}

Write-Host ""
Write-Host "----- last 40 log lines -----"
if (Test-Path -LiteralPath $Log) { Get-Content -LiteralPath $Log -Tail 40 }
Write-Host "------------------------------"
Write-Host "Full log: $Log"
Write-Host "UAT exit code: $err"
Write-Host "Output folder: $Archive"
Write-Host "Also check: $MsixOut"
Write-Host ""

if ($err -ne 0) {
    Write-Host "FAILED." -ForegroundColor Red
    if ($pause) { Read-Host "Press Enter to close" | Out-Null }
    exit 1
}

Write-Host "SUCCESS (check for .msixvc)" -ForegroundColor Green
if ($pause) { Read-Host "Press Enter to close" | Out-Null }
exit 0
