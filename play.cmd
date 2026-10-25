@echo off
setlocal DisableDelayedExpansion
if defined GODOT goto configured
set "HUNT_ENGINE=%~dp0build\tools\godot-4.4.1\Godot_v4.4.1-stable_win64.exe"
if exist "%HUNT_ENGINE%" goto launch
where /q godot.exe
if errorlevel 1 goto missing
set "HUNT_ENGINE=godot.exe"
goto launch

:configured
set "HUNT_ENGINE=%GODOT%"

:launch
"%HUNT_ENGINE%" --path "%~dp0." %*
exit /b %errorlevel%

:missing
echo Godot was not found. Install Godot 4.4.x and add it to PATH,
echo or set GODOT to the full path of your Godot executable.
echo See README.md in this folder for setup instructions.
if "%~1"=="" pause
exit /b 1
