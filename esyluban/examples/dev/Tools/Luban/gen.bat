@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem The runtime normally sits next to this script (Tools\Luban\runtime).
rem Searching upwards also covers the in-repo layout, where all example
rem projects share one runtime at esyluban\runtime.
rem
rem IMPORTANT: inside ( ) blocks always use !VAR!, never percent-VAR-percent.
rem cmd expands percent-signs while READING the whole block, so a path
rem containing ')' -- "C:\Program Files (x86)\..", "Battle (WIP)\.." --
rem closes the block early and the script dies at parse time, before any
rem branch runs. Batch parameters are parse-time as well, hence ARGS below.
rem
rem This applies to rem lines too: writing a tilde-d-p-N form in a comment
rem is itself a parse error. Spell such things out instead of quoting them.
rem
rem NOTE: keep this file ASCII-only. cmd parses .bat using the system
rem ANSI code page, so UTF-8 non-ASCII comments break execution.

set "SCRIPT_DIR=%~dp0"
set "CONF_FILE=%SCRIPT_DIR%luban.conf"
set "ARGS=%*"

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
  echo     !CONF_FILE!
  echo   Data formats: json bin xml lua yaml bson
  echo.
  echo   To export just some of your tables, use the right-click menu instead.
  if not defined LUBAN_NO_PAUSE pause
  exit /b 1
)

rem Windows still caps most paths at 260 characters, and a deeply nested project
rem plus this tool's own subdirectories can cross it. When that happens cmd fails
rem with "The current directory is invalid" -- a message that points nowhere near
rem the real cause. Say it plainly instead.
set "PATH_LEN_PROBE=%SCRIPT_DIR%"
call :StrLen PATH_LEN_PROBE PATH_LEN
if !PATH_LEN! gtr 200 (
  echo [WARN] This tool sits at a very deep path ^(!PATH_LEN! characters^):
  echo        !SCRIPT_DIR!
  echo        Windows caps most paths at 260. If export fails with an error like
  echo        "The current directory is invalid", move the project somewhere
  echo        shallower -- that is almost certainly the cause.
  echo.
)

set "FIND_DIR=%SCRIPT_DIR:~0,-1%"
set LUBAN_EXE=
for /l %%i in (0,1,6) do (
  if not defined LUBAN_EXE if exist "!FIND_DIR!\esyluban\runtime\Luban.exe" set "LUBAN_EXE=!FIND_DIR!\esyluban\runtime\Luban.exe"
  if not defined LUBAN_EXE if exist "!FIND_DIR!\runtime\Luban.exe" set "LUBAN_EXE=!FIND_DIR!\runtime\Luban.exe"
  set "FIND_DIR=!FIND_DIR!\.."
)

if not defined LUBAN_EXE (
  echo [ERROR] Luban runtime not found.
  echo         Expected here: !SCRIPT_DIR!runtime\Luban.exe
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
  "!LUBAN_EXE!" !ARGS!
) else (
  "!LUBAN_EXE!" --conf "!CONF_FILE!" !ARGS!
)
set "GEN_ERR=!errorlevel!"

popd

if not "!GEN_ERR!"=="0" (
  echo.
  echo [ERROR] Luban exited with code !GEN_ERR!
  if not defined LUBAN_NO_PAUSE pause
  exit /b !GEN_ERR!
)

if not defined LUBAN_NO_PAUSE pause
exit /b 0

:StrLen
rem %1 = name of a variable holding the string, %2 = name of the output variable
setlocal EnableDelayedExpansion
set "S=!%~1!#"
set "L=0"
for %%A in (4096 2048 1024 512 256 128 64 32 16 8 4 2 1) do (
  if "!S:~%%A!" neq "" (
    set /a L+=%%A
    set "S=!S:~%%A!"
  )
)
endlocal & set "%~2=%L%"
goto :eof
