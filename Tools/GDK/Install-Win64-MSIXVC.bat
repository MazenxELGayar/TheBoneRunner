@echo off
setlocal EnableExtensions
title The Bone Runner GDK install
cd /d "%~dp0"
REM Prompts for the game install folder. Do not use -NonInteractive (needs input).
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Win64-MSIXVC.ps1" %*
exit /b %ERRORLEVEL%
