@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Export every target this project ships, each into its own directory.
rem
rem WHY THIS SCRIPT EXISTS
rem Luban's xargs namespace is keyed by dataTarget / codeTarget -- "json",
rem "cs-simple-json" -- and NOT by the target you pass to -t. So writing
rem   "client.outputDataDir=..\GenData\client"
rem in luban.conf looks right and does nothing at all: the option is never
rem read, every target falls back to the global outputDataDir, and each run
rem overwrites the previous one's files. Per-target directories therefore
rem have to be passed per invocation, which is what this script does.
rem The right-click menu solves the same problem the same way, by translating
rem contextMenu.data.outputDataDir into one -x per target.
rem
rem NOTE: keep this file ASCII-only. cmd parses .bat using the system ANSI
rem code page, so UTF-8 non-ASCII comments break execution. Inside ( ) blocks
rem always use !VAR!, never percent-VAR-percent -- cmd expands percent signs
rem while READING the block, so a path containing ')' closes it early and the
rem script dies at parse time.

set "SCRIPT_DIR=%~dp0"

rem Optional first argument redirects everything to another root, which is how
rem the regression exports this project without touching the checked-in copy.
if "%~1"=="" (
  set "OUT_ROOT=%SCRIPT_DIR%..\..\Projects\Csharp_Unity_json\Assets"
) else (
  set "OUT_ROOT=%~1"
)

set "LUBAN_NO_PAUSE=1"
set FAILED=0

call :Gen client data+code
call :Gen server data+code
call :Gen editor data

if not "!FAILED!"=="0" (
  echo.
  echo [ERROR] !FAILED! target^(s^) failed to export.
  endlocal & exit /b 1
)

echo.
echo [OK] all targets exported under: !OUT_ROOT!
endlocal & exit /b 0

:Gen
rem %1 = target name, %2 = "data+code" or "data"
set "T=%~1"
echo.
echo [GEN] target !T! -- %~2
if "%~2"=="data+code" (
  call "%SCRIPT_DIR%gen.bat" -t !T! -d json -c cs-simple-json ^
    -x outputDataDir="!OUT_ROOT!\GenData\!T!" ^
    -x outputCodeDir="!OUT_ROOT!\GenCode\!T!"
) else (
  call "%SCRIPT_DIR%gen.bat" -t !T! -d json ^
    -x outputDataDir="!OUT_ROOT!\GenData\!T!"
)
if errorlevel 1 (
  echo [FAIL] target !T! returned !errorlevel!
  set /a FAILED+=1
)
goto :eof
