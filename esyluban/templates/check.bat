@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem The runtime normally sits next to this script (Tools\Luban\runtime).
rem Searching upwards also covers the in-repo layout, where all example
rem projects share one runtime at esyluban\runtime.
set SCRIPT_DIR=%~dp0
set CONF_FILE=%SCRIPT_DIR%luban.conf

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

rem -f (forceLoadTableDatas) makes Luban load and validate every row without
rem writing any output -- that is what makes this a check rather than an export.
rem
rem With no arguments, fall back to the target shipped in the template conf.
rem Pass -t yourself if you renamed it or added more targets.
set CHECK_ARGS=%*
if "%~1"=="" set CHECK_ARGS=-t client

echo %* | findstr /i /c:"--conf" >nul
if %errorlevel%==0 (
  "%LUBAN_EXE%" -f %CHECK_ARGS%
) else (
  "%LUBAN_EXE%" -f --conf "%CONF_FILE%" %CHECK_ARGS%
)

popd

if not defined LUBAN_NO_PAUSE pause
endlocal
