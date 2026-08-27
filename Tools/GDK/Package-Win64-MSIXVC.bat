@echo off
setlocal EnableExtensions
title The Bone Run Win64 MSIXVC package
cd /d "%~dp0"

REM Always launch via this .bat (not the .ps1). Bypass skips the execution-policy prompt.
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0Package-Win64-MSIXVC.ps1" %*
exit /b %ERRORLEVEL%
