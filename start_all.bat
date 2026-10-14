@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
if not exist "backend\python\python.exe" (
  echo 缺少底座内置Python，请检查补丁链。
  pause
  exit /b 1
)
"backend\python\python.exe" -B -X utf8 "backend\scripts\start_all.py"
if errorlevel 1 (
  if not defined XINGHUI_PATCH_TEST pause
  exit /b 1
)
