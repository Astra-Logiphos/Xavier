@echo off
setlocal
set PYTHONUTF8=1
chcp 65001 >nul
cd /d "%~dp0"
if exist "backend\python\python.exe" (
  "backend\python\python.exe" -B -X utf8 "backend\scripts\local_backend.py" %*
) else (
  where py >nul 2>nul
  if errorlevel 1 (
    echo 未找到 Python。请安装 Python 3.12 或使用包含 Python 的新版 Windows ZIP。
    pause
    exit /b 1
  )
  py -3 -c "import sys; assert sys.version_info >= (3,12), 'Python 3.12+ required'"
  if errorlevel 1 exit /b 1
  py -3 -m pip install -r server\requirements.txt
  if errorlevel 1 exit /b 1
  py -3 -B -X utf8 scripts\local_backend.py %*
)
if errorlevel 1 (
  echo 启动失败，请查看上方信息及本地 backend.log。
  if not "%~1"=="--background" pause
  exit /b 1
)
