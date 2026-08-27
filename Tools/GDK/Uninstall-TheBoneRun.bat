@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Uninstall The Bone Run
cd /d "%~dp0"

echo ========================================
echo Uninstall The Bone Run
echo ========================================
echo GDK installs are removed with wdapp, not Windows Settings -^> Apps.
echo.

set "WDAPP="
if defined GameDKLatest if exist "%GameDKLatest%bin\wdapp.exe" set "WDAPP=%GameDKLatest%bin\wdapp.exe"
if not defined WDAPP if defined GameDK if exist "%GameDK%bin\wdapp.exe" set "WDAPP=%GameDK%bin\wdapp.exe"
if not defined WDAPP if exist "F:\Unreal Engine\Microsoft\GDK\GDK_2604.2.7849\bin\wdapp.exe" set "WDAPP=F:\Unreal Engine\Microsoft\GDK\GDK_2604.2.7849\bin\wdapp.exe"
if not defined WDAPP if exist "C:\Program Files (x86)\Microsoft GDK\bin\wdapp.exe" set "WDAPP=C:\Program Files (x86)\Microsoft GDK\bin\wdapp.exe"

if not defined WDAPP (
  echo ERROR: wdapp.exe not found. Cannot uninstall a GDK package from Settings -^> Apps.
  echo Install Microsoft GDK, or run this from a machine with the GDK tools.
  echo.
  pause
  exit /b 1
)

echo Using: "!WDAPP!"
echo.
echo Looking up installed The Bone Run packages...
set "PFN="
for /f "usebackq tokens=* delims=" %%A in (`"!WDAPP!" list 2^>nul`) do (
  echo %%A | findstr /i /c:"TheBoneRun" /c:"The Bone Run" /c:"MazenX.TheBoneRun" >nul
  if not errorlevel 1 (
    echo %%A | findstr /c:"!" >nul
    if errorlevel 1 (
      for /f "tokens=* delims=" %%B in ("%%A") do set "PFN=%%B"
    )
  )
)

if not defined PFN (
  echo.
  echo The Bone Run is not registered with wdapp right now.
  echo That Windows message "the action is only valid for products that are currently installed"
  echo means Settings -^> Apps / Remove-AppxPackage cannot remove this GDK install.
  echo.
  echo If the game still runs, run this .bat again as Administrator.
  echo If the game is already gone, you can delete this folder yourself.
  echo.
  pause
  exit /b 0
)

echo Found package: !PFN!
echo.
set /p CONFIRM=Uninstall The Bone Run? [Y/n]
if /i "!CONFIRM!"=="n" goto :CANCEL
if /i "!CONFIRM!"=="no" goto :CANCEL

echo.
echo Uninstalling !PFN! ...
"!WDAPP!" uninstall !PFN!
set ERR=!ERRORLEVEL!
echo.
if not "!ERR!"=="0" (
  echo wdapp uninstall failed ^(exit !ERR!^).
  echo Right-click this file -^> Run as administrator and try once more.
  pause
  exit /b !ERR!
)

echo The Bone Run was uninstalled.
echo You can delete leftover files in this folder if they remain.
echo.
pause
exit /b 0

:CANCEL
echo Cancelled.
pause
exit /b 0
