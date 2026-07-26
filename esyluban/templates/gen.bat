@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem The runtime normally sits next to this script (Tools\Luban\runtime).
rem Searching upwards also covers the in-repo layout, where all example
rem projects share one runtime at esyluban\runtime.
set SCRIPT_DIR=%~dp0
set CONF_FILE=%SCRIPT_DIR%luban.conf

rem Luban requires -t. Without it the user gets a wall of option help from
rem the argument parser, which says nothing about this project's targets.
if "%~1"=="" (
  echo [USAGE] gen.bat -t ^<target^> [-d ^<data format^>] [-c ^<code target^>]
  echo.
  echo   gen.bat -t client -d json                        export data only
  echo   gen.bat -t client -c cs-simple-json              generate code only
  echo   gen.bat -t client -d json -c cs-simple-json      both
  echo.
  echo   Target names are the "targets" entries in:
  echo     %CONF_FILE%
  echo   Data formats: json bin xml lua yaml bson
  echo.
  echo   To export just some of your tables, use the right-click menu instead.
  if not defined LUBAN_NO_PAUSE pause
  exit /b 1
)

set FIND_DIR=%SCRIPT_DIR:~0,-1%
set LUBAN_EXE=
for /l %%i in (0,1,6) do (
  if not defined LUBAN_EXE if exist "!FIND_DIR!\esyluban\runtime\Luban.exe" set "LUBAN_EXE=!FIND_DIR!\esyluban\runtime\Luban.exe"
  if not defined LUBAN_EXE if exist "!FIND_DIR!\runtime\Luban.exe" set "LUBAN_EXE=!FIND_DIR!\runtime\Luban.exe"
  set "FIND_DIR=!FIND_DIR!\.."
)

if not defined LUBAN_EXE (
  echo [ERROR] Luban runtime not found.
  echo         Expected here: %SCRIPT_DIR%runtime\Luban.exe
  echo.
  echo         Using a release download? Extract it so that the runtime folder
  echo         sits next to luban.conf, both inside your project's Tools\Luban.
  echo         Building from source? Run esyluban\scripts\build.bat first.
  if not defined LUBAN_NO_PAUSE pause
  exit /b 1
)

pushd "%SCRIPT_DIR%"

echo %* | findstr /i /c:"--conf" >nul
if %errorlevel%==0 (
  "%LUBAN_EXE%" %*
) else (
  "%LUBAN_EXE%" --conf "%CONF_FILE%" %*
)

popd

if not defined LUBAN_NO_PAUSE pause
endlocal
