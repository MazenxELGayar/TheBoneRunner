# Repairs missing Engine/Intermediate/ScriptModules build records for installed UE builds.
# Without these, RunUAT fails immediately with "Found no script module records."
param(
    [string]$UeRoot = "F:\Unreal Engine\UE_5.8"
)

function Get-RelativePathCompat([string]$From, [string]$To) {
    $fromUri = New-Object System.Uri(($From.TrimEnd('\') + '\'))
    $toUri = New-Object System.Uri($To)
    $relative = $fromUri.MakeRelativeUri($toUri).ToString()
    return [System.Uri]::UnescapeDataString($relative) -replace '\\', '/'
}

$ErrorActionPreference = "Stop"

function Repair-UatScriptModules {
    param([string]$EngineRoot)

    $engineDir = Join-Path $EngineRoot "Engine"
    $installedMarker = Join-Path $engineDir "Build\InstalledBuild.txt"
    $recordsDir = Join-Path $engineDir "Intermediate\ScriptModules"

    if (-not (Test-Path -LiteralPath $installedMarker)) {
        Write-Host "UAT repair: engine is not an installed build; skipping ScriptModules repair."
        return $true
    }

    $existing = @()
    if (Test-Path -LiteralPath $recordsDir) {
        $existing = @(Get-ChildItem -LiteralPath $recordsDir -Filter "*.Automation.json" -File -ErrorAction SilentlyContinue)
    }
    if ($existing.Count -ge 20) {
        Write-Host "UAT repair: ScriptModules records already present ($($existing.Count))."
        return $true
    }

    Write-Host "UAT repair: generating ScriptModules build records for installed UE..."

    $projects = Get-ChildItem -LiteralPath $engineDir -Recurse -Filter "*.Automation.csproj" -File -ErrorAction SilentlyContinue
    if (-not $projects -or $projects.Count -eq 0) {
        Write-Host "ERROR: No *.Automation.csproj files found under $engineDir" -ForegroundColor Red
        return $false
    }

    New-Item -ItemType Directory -Force -Path $recordsDir | Out-Null

    $runtimeVersion = "10.0.0"
    try {
        $dotnetDll = Join-Path $engineDir "Binaries\ThirdParty\DotNet\10.0.0\win-x64\shared\Microsoft.NETCore.App\10.0.0\System.Runtime.dll"
        if (Test-Path -LiteralPath $dotnetDll) {
            $runtimeVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($dotnetDll).ProductVersion
            if ($runtimeVersion -match "^(\d+\.\d+\.\d+)") { $runtimeVersion = $Matches[1] }
        }
    }
    catch { }

    $created = 0
    $missing = @()

    foreach ($project in $projects) {
        $content = Get-Content -LiteralPath $project.FullName -Raw

        $assemblyName = $project.BaseName
        if ($content -match '<AssemblyName>([^<]+)</AssemblyName>') {
            $assemblyName = $Matches[1].Trim()
        }

        $outputPath = $null
        if ($content -match '<OutputPath[^>]*>([^<]+)</OutputPath>') {
            $outputPath = $Matches[1].Trim()
        }

        if (-not $outputPath -or $outputPath -match '\$\(') {
            $missing += "$($project.FullName) (no OutputPath)"
            continue
        }

        $targetPath = Join-Path $outputPath "net10.0\$assemblyName.dll"
        $targetFull = [System.IO.Path]::GetFullPath((Join-Path $project.DirectoryName $targetPath))

        if (-not (Test-Path -LiteralPath $targetFull)) {
            $missing += "$($project.Name) -> $targetPath"
            continue
        }

        $projectRelative = Get-RelativePathCompat $recordsDir $project.FullName
        $targetWrite = (Get-Item -LiteralPath $targetFull).LastWriteTimeUtc.ToString("o")

        $record = [ordered]@{
            Version               = 7
            RuntimeVersion        = $runtimeVersion
            ProjectPath           = $projectRelative
            TargetBuildTime       = $targetWrite
            TargetConfiguration   = "Development"
            TargetPath            = ($targetPath -replace '\\', '/')
            ProjectReferencesAndTimes = @()
            Dependencies          = @()
            Globs                 = @()
        }

        $recordFile = Join-Path $recordsDir ($project.Name -replace '\.csproj$', '.json')
        $record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $recordFile -Encoding UTF8
        $created++
    }

    if ($missing.Count) {
        Write-Host "WARNING: skipped $($missing.Count) automation project(s) with missing DLLs:" -ForegroundColor Yellow
        $missing | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" }
    }

    if ($created -lt 1) {
        Write-Host "ERROR: failed to create ScriptModules records." -ForegroundColor Red
        return $false
    }

    Write-Host "UAT repair: wrote $created ScriptModules record(s) to $recordsDir"
    return $true
}

if ($MyInvocation.InvocationName -ne '.') {
    $ok = Repair-UatScriptModules -EngineRoot $UeRoot
    if (-not $ok) { exit 1 }
}
