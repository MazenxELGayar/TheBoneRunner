# Apply folder icon + launch shortcut on a GDK install folder.
param(
    [Parameter(Mandatory = $true)]
    [string]$GameRoot
)

$ErrorActionPreference = "Continue"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$IcoCandidates = @(
    (Join-Path $ProjectRoot "Build\Windows\Application.ico"),
    (Join-Path $ProjectRoot "Content\Assets\Images\Icon.ico"),
    (Join-Path $ProjectRoot "Content\Assets\Icon.ico")
)
$IcoSrc = $null
foreach ($c in $IcoCandidates) {
    if (Test-Path -LiteralPath $c) { $IcoSrc = $c; break }
}

function Find-GameFolders([string]$Root) {
    $exe = Get-ChildItem -LiteralPath $Root -Recurse -Filter "TheBoneRun.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "vc_redist" } |
        Select-Object -First 1
    if (-not $exe) { return $null }
    $content = $exe.DirectoryName
    $title = Split-Path $content -Parent
    return [pscustomobject]@{ Content = $content; Title = $title; Exe = $exe.FullName }
}

function Set-FolderIcon([string]$Folder, [string]$IcoName) {
    $ini = Join-Path $Folder "desktop.ini"
    @"
[.ShellClassInfo]
IconResource=$IcoName,0
IconFile=$IcoName
IconIndex=0
"@ | Set-Content -LiteralPath $ini -Encoding Unicode
    attrib.exe +s +r "$Folder"  >$null 2>&1
    attrib.exe +h +s "$ini"     >$null 2>&1
    attrib.exe +h (Join-Path $Folder $IcoName) >$null 2>&1
}

$found = Find-GameFolders $GameRoot
if (-not $found) {
    Write-Host "Could not find TheBoneRun.exe under $GameRoot" -ForegroundColor Yellow
    exit 1
}

if ($IcoSrc) {
    Copy-Item -LiteralPath $IcoSrc -Destination (Join-Path $found.Title "TheBoneRun.ico") -Force
    Set-FolderIcon $found.Title "TheBoneRun.ico"
} else {
    Write-Host "No Application.ico found — skipping folder icon. Add art later and re-run." -ForegroundColor Yellow
}

# Content is the payload folder — keep the default Explorer folder icon.

$shell = New-Object -ComObject WScript.Shell
$lnk = Join-Path $found.Title "The Bone Run.lnk"
$sc = $shell.CreateShortcut($lnk)
$sc.TargetPath = $found.Exe
$sc.WorkingDirectory = $found.Content
$sc.WindowStyle = 1
$sc.Description = "The Bone Run"
if ($IcoSrc) { $sc.IconLocation = (Join-Path $found.Title "TheBoneRun.ico") }
$sc.Save()

$uninstSrc = Join-Path $PSScriptRoot "Uninstall-TheBoneRun.bat"
$uninstDst = Join-Path $found.Title "Uninstall TheBoneRun.bat"
if (Test-Path -LiteralPath $uninstSrc) {
    Copy-Item -LiteralPath $uninstSrc -Destination $uninstDst -Force
    Write-Host "Uninstall: $uninstDst"
}

Write-Host "Shortcut: $lnk"
Write-Host "Note: GDK encrypts TheBoneRun.exe, so Explorer still shows a generic .exe icon. Use the shortcut."
exit 0
