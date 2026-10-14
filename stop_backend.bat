@echo off
setlocal
chcp 65001 >nul
set "XINGHUI_STOP_ROOT=%~1"
if not defined XINGHUI_STOP_ROOT if exist "%~dp0backend\python\python.exe" set "XINGHUI_STOP_ROOT=%~dp0"
if not defined XINGHUI_STOP_ROOT set /p XINGHUI_STOP_ROOT=Install directory: 
powershell.exe -NoProfile -Command "$folder=[IO.Path]::GetFullPath((Join-Path $env:XINGHUI_STOP_ROOT 'backend\python')); $paths=@((Join-Path $folder 'python.exe'),(Join-Path $folder 'pythonw.exe')); $owned=@(Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -in $paths }); foreach($p in ($owned | Sort-Object CreationDate)) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }; Write-Output '本地后端已停止，其他安装的 Python 未改动。'"
set "RESULT=%ERRORLEVEL%"
if not defined XINGHUI_PATCH_TEST pause
exit /b %RESULT%
