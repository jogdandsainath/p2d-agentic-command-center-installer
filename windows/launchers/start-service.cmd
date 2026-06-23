@echo off
REM E-Divin — Service/Backend Launcher (Windows CMD wrapper)
powershell.exe -ExecutionPolicy Bypass -File "%~dp0start-service.ps1" %*
