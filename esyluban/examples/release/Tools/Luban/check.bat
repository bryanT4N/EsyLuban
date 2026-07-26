@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem This project holds only its own luban.conf.
rem The Luban runtime is shared repo-wide; locate it by searching upwards.
set SCRIPT_DIR=%~dp0
set CONF_FILE=%SCRIPT_DIR%luban.conf

set FIND_DIR=%SCRIPT_DIR:~0,-1%
set LUBAN_DLL=
for /l %%i in (0,1,6) do (
  if not defined LUBAN_DLL if exist "!FIND_DIR!\esyluban\runtime\Luban.dll" set "LUBAN_DLL=!FIND_DIR!\esyluban\runtime\Luban.dll"
  if not defined LUBAN_DLL if exist "!FIND_DIR!\runtime\Luban.dll" set "LUBAN_DLL=!FIND_DIR!\runtime\Luban.dll"
  set "FIND_DIR=!FIND_DIR!\.."
)

if not defined LUBAN_DLL (
  echo [ERROR] Luban runtime not found: esyluban\runtime\Luban.dll
  echo         Run esyluban\scripts\build.bat first to build from source.
  pause
  exit /b 1
)

pushd "%SCRIPT_DIR%"

echo %* | findstr /i /c:"--conf" >nul
if %errorlevel%==0 (
  dotnet "%LUBAN_DLL%" -t all -f %*
) else (
  dotnet "%LUBAN_DLL%" -t all -f --conf "%CONF_FILE%" %*
)

popd

pause
endlocal
