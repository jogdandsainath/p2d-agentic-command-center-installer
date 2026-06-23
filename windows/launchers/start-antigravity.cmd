@echo off
REM E-Divin — Google Antigravity Launcher (Windows CMD wrapper)
REM Double-click this file or call from any terminal / CI step.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0start-antigravity.ps1" %*
