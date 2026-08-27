@echo off
setlocal EnableExtensions
title Generate The Bone Runner platform icons
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Generate-PlatformIcons.ps1"
exit /b %ERRORLEVEL%
