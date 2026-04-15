: << 'CMDBLOCK'
@echo off
setlocal

if "%~1"=="" exit /b 0

set "HOOK_DIR=%~dp0"
set "SCRIPT_NAME=%~1"
if "%HOOK_DIR:~-1%"=="\" set "HOOK_DIR=%HOOK_DIR:~0,-1%"

if not exist "%HOOK_DIR%\%SCRIPT_NAME%" exit /b 0

if exist "C:\Program Files\Git\bin\bash.exe" "C:\Program Files\Git\bin\bash.exe" -l -c "command -v cygpath >/dev/null 2>&1 || exit 0; cd \"$(cygpath -u \"%HOOK_DIR%\")\" && \"./%SCRIPT_NAME%\""
if exist "C:\Program Files\Git\bin\bash.exe" exit /b %ERRORLEVEL%

if exist "C:\Program Files (x86)\Git\bin\bash.exe" "C:\Program Files (x86)\Git\bin\bash.exe" -l -c "command -v cygpath >/dev/null 2>&1 || exit 0; cd \"$(cygpath -u \"%HOOK_DIR%\")\" && \"./%SCRIPT_NAME%\""
if exist "C:\Program Files (x86)\Git\bin\bash.exe" exit /b %ERRORLEVEL%

where bash >nul 2>nul
if errorlevel 1 exit /b 0

bash -l -c "command -v cygpath >/dev/null 2>&1 || exit 0; cd \"$(cygpath -u \"%HOOK_DIR%\")\" && \"./%SCRIPT_NAME%\""
exit /b %ERRORLEVEL%

exit /b 0
CMDBLOCK

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_NAME="${1:-}"

if [ -z "$SCRIPT_NAME" ]; then
    exit 0
fi

shift || true
SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"

if [ ! -f "$SCRIPT_PATH" ]; then
    exit 0
fi

exec sh "$SCRIPT_PATH" "$@"
