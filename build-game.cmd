@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-game.ps1" %*
pause
