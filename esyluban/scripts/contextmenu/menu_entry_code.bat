@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ---------------------------------------------------------------
rem EsyLuban context menu entry point (CODE).
rem
rem install_luban_context_menu.bat copies THIS file into %ProgramData%
rem and points the registry at the copy. Because that copy is frozen at
rem install time, it deliberately contains no export logic at all -- only
rem the directory contract below. Everything that might need fixing lives
rem in the project's own Tools\Luban\contextmenu\, so replacing a project's
rem Tools\Luban also upgrades its right-click behaviour, with no reinstall.
rem
rem Re-running the installer is only required if this contract changes:
rem   - luban.conf sits at <project>\Tools\Luban\ , at most 5 levels up
rem   - the real script sits at <that dir>\contextmenu\
rem   - it is called as: script.bat "<selected path>" "<Tools\Luban dir>"
rem
rem NOTE: keep this file ASCII-only. cmd parses .bat using the system
rem ANSI code page, so UTF-8 non-ASCII comments break execution.
rem ---------------------------------------------------------------

set IMPL_NAME=run_luban_context_menu_code.bat

set TARGET=%~f1
if "%TARGET%"=="" set TARGET=%CD%
if "%TARGET%"=="" (
  echo [ERROR] No target path provided.
  pause
  exit /b 1
)

if exist "%TARGET%\*" (
  set TARGET_DIR=%TARGET%
) else (
  set TARGET_DIR=%~dp1
)

rem Locate the project by its luban.conf.
set CUR_DIR=%TARGET_DIR%
set LUBAN_DIR=
set PROJECT_ROOT=
for /l %%i in (0,1,5) do (
  if not defined LUBAN_DIR if exist "!CUR_DIR!\Tools\Luban\luban.conf" (
    set "LUBAN_DIR=!CUR_DIR!\Tools\Luban"
    set "PROJECT_ROOT=!CUR_DIR!"
  )
  set "CUR_DIR=!CUR_DIR!\.."
)
if not defined LUBAN_DIR (
  echo [ERROR] Tools\Luban\luban.conf not found within 5 levels above:
  echo           %TARGET_DIR%
  echo.
  echo         Expected layout:  ^<project^>\Tools\Luban\luban.conf
  pause
  exit /b 2
)

rem Release layout keeps the real script beside luban.conf. The in-repo
rem layout has example projects share one copy under esyluban\scripts.
set IMPL=
if exist "%LUBAN_DIR%\contextmenu\%IMPL_NAME%" set "IMPL=%LUBAN_DIR%\contextmenu\%IMPL_NAME%"
if not defined IMPL (
  set FIND_DIR=%PROJECT_ROOT%
  for /l %%i in (0,1,6) do (
    if not defined IMPL if exist "!FIND_DIR!\esyluban\scripts\contextmenu\%IMPL_NAME%" set "IMPL=!FIND_DIR!\esyluban\scripts\contextmenu\%IMPL_NAME%"
    set "FIND_DIR=!FIND_DIR!\.."
  )
)
if not defined IMPL (
  echo [ERROR] Export script not found:
  echo           %LUBAN_DIR%\contextmenu\%IMPL_NAME%
  echo.
  echo         contextmenu\ is a runtime dependency, not just an installer --
  echo         the right-click menu calls into it on every export. Do not
  echo         delete it. Restore Tools\Luban from a full release package.
  pause
  exit /b 5
)

call "%IMPL%" "%TARGET%" "%LUBAN_DIR%"
exit /b %errorlevel%
