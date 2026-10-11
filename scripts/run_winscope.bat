@echo off
rem Run a Winscope build (dist/prod) on Windows: double-click this file in the build folder.
rem Starts a local web server and opens the browser; also starts winscope_proxy.py
rem (ADB trace capture, port 5544) when adb is on PATH.
rem Usage: run_winscope.bat [port]   (default 8080)
setlocal
cd /d "%~dp0"
set "PORT=%~1"
if "%PORT%"=="" set "PORT=8080"

set "PY="
where py >nul 2>nul && set "PY=py -3"
if not defined PY where python >nul 2>nul && set "PY=python"
if not defined PY (
  echo Python 3 not found. Install it from https://www.python.org/downloads/ and retry.
  pause
  exit /b 1
)
if not exist index.html (
  echo index.html not found. Put this script in the Winscope build folder.
  pause
  exit /b 1
)

where adb >nul 2>nul
if errorlevel 1 (
  echo adb not on PATH: skipping winscope_proxy.py. You can still open trace files.
) else (
  if exist winscope_proxy.py start "Winscope proxy (copy the token into Winscope)" %PY% winscope_proxy.py
)

echo Winscope: http://127.0.0.1:%PORT%/   (close this window to stop)
start "" cmd /c "timeout /t 2 >nul & start http://127.0.0.1:%PORT%/"
%PY% -m http.server %PORT% --bind 127.0.0.1
