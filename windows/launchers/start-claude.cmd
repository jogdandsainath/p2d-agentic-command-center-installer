@echo off
REM E-Divin — Claude Code Launcher (Windows CMD wrapper)
powershell.exe -ExecutionPolicy Bypass -File "%~dp0start-claude.ps1" %*
