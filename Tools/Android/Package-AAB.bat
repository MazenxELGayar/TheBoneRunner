@echo off
setlocal EnableExtensions
title The Bone Runner Android AAB
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Package-AAB.ps1" %*
exit /b %ERRORLEVEL%
