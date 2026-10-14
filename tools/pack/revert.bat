@echo off
setlocal
chcp 65001 >nul
if not "%~1"=="" set "XINGHUI_INSTALL_ROOT=%~1"
set "ENGINE=%~dp0tools\pack\patch.ps1"
if not exist "%ENGINE%" set "ENGINE=%~dp0patch.ps1"
if not defined XINGHUI_INSTALL_ROOT set /p XINGHUI_INSTALL_ROOT=Install directory: 
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ENGINE%" -Mode Revert
set "RESULT=%ERRORLEVEL%"
if not defined XINGHUI_PATCH_TEST pause
exit /b %RESULT%
