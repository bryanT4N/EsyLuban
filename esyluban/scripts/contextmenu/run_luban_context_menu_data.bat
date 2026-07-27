@echo off
setlocal EnableExtensions EnableDelayedExpansion

set TARGET=%~f1
rem Batch parameters expand at parse time, so they cannot appear
rem inside a ( ) block. Hoist it here and use !ARG1_DIR! below.
set "ARG1_DIR=%~dp1"
if "%TARGET%"=="" (
  set TARGET=!CD!
  if "!TARGET!"=="" (
    echo No target path provided.
    if not defined LUBAN_NO_PAUSE pause
    exit /b 1
  )
)

if exist "%TARGET%\*" (
  set IS_DIR=1
  set TARGET_DIR=!TARGET!
) else (
  set IS_DIR=0
  set TARGET_DIR=!ARG1_DIR!
)

rem %2 is the Tools\Luban directory, passed in by menu_entry_data.bat which
rem already resolved it. Falling back to searching keeps this script runnable
rem on its own -- useful for testing and for calling it from a build script.
set LUBAN_DIR=%~f2
set PROJECT_ROOT=
if defined LUBAN_DIR (
  for %%I in ("!LUBAN_DIR!\..\..") do set "PROJECT_ROOT=%%~fI"
) else (
  set CUR_DIR=!TARGET_DIR!
  for /l %%i in (0,1,5) do (
    if not defined LUBAN_DIR if exist "!CUR_DIR!\Tools\Luban\luban.conf" (
      set "LUBAN_DIR=!CUR_DIR!\Tools\Luban"
      set "PROJECT_ROOT=!CUR_DIR!"
    )
    set "CUR_DIR=!CUR_DIR!\.."
  )
)

if not defined LUBAN_DIR (
  echo Tools\Luban not found within 5 levels.
  if not defined LUBAN_NO_PAUSE pause
  exit /b 2
)

set CONF_FILE=%LUBAN_DIR%\luban.conf

rem The runtime ships next to luban.conf (Tools\Luban\runtime), so each
rem project carries its own version and upgrades independently. Look there
rem first; only then search upwards, which supports the in-repo layout where
rem one runtime is shared by all example projects.
set LUBAN_EXE=
if exist "%LUBAN_DIR%\runtime\Luban.exe" set "LUBAN_EXE=%LUBAN_DIR%\runtime\Luban.exe"
set FIND_DIR=%PROJECT_ROOT%
for /l %%i in (0,1,6) do (
  if not defined LUBAN_EXE if exist "!FIND_DIR!\esyluban\runtime\Luban.exe" set "LUBAN_EXE=!FIND_DIR!\esyluban\runtime\Luban.exe"
  if not defined LUBAN_EXE if exist "!FIND_DIR!\runtime\Luban.exe" set "LUBAN_EXE=!FIND_DIR!\runtime\Luban.exe"
  set "FIND_DIR=!FIND_DIR!\.."
)
if not defined LUBAN_EXE (
  echo [ERROR] Luban runtime not found.
  echo         Expected here: !LUBAN_DIR!\runtime\Luban.exe
  echo.
  echo         Using a release download? Extract it so that the runtime folder
  echo         sits next to luban.conf, both inside your project's Tools\Luban.
  echo         Building from source? Run esyluban\scripts\build.bat first.
  if not defined LUBAN_NO_PAUSE pause
  exit /b 3
)

set SCAN_PATH=%TARGET%
if %IS_DIR%==1 (
  set SCAN_PATH=!TARGET_DIR!
)

set DATA_TARGETS=
set DATA_FORMAT=
set EXTRA_ARGS=
set OUTPUT_TABLE_ARGS=

for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
  "$conf=Get-Content -Raw '!CONF_FILE!';" ^
  "$json=$conf | ConvertFrom-Json;" ^
  "$data=$json.contextMenu.data;" ^
  "if($null -ne $data -and $data.targets){$data.targets -join ' '}"`
) do set DATA_TARGETS=%%A
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
  "$conf=Get-Content -Raw '!CONF_FILE!';" ^
  "$json=$conf | ConvertFrom-Json;" ^
  "$data=$json.contextMenu.data;" ^
  "if($null -ne $data -and $data.dataTarget){$data.dataTarget}"`
) do set DATA_FORMAT=%%A
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
  "$conf=Get-Content -Raw '!CONF_FILE!';" ^
  "$json=$conf | ConvertFrom-Json;" ^
  "$data=$json.contextMenu.data;" ^
  "if($null -ne $data -and $data.extraArgs){$data.extraArgs -join ' '}"`
) do set EXTRA_ARGS=%%A

if "%DATA_TARGETS%"=="" set DATA_TARGETS=client server editor
if "%DATA_FORMAT%"=="" set DATA_FORMAT=json

set LIST_TARGET=
for %%t in (%DATA_TARGETS%) do (
  if not defined LIST_TARGET set LIST_TARGET=%%t
)
if "%LIST_TARGET%"=="" set LIST_TARGET=client

rem Step 1: ask Luban which tables live under the selected path.
rem Its stdout is table full names, one per line; logs go to stderr.
rem
rem Route through a temp file rather than `for /f`: for /f discards the exit
rem code, so a failed listing was indistinguishable from an empty one. That is
rem how "your B1 has a syntax error" and "there are no tables here" ended up
rem printing the same message -- to the one audience that cannot debug it.
set "LIST_TMP=%TEMP%\luban_tables_%RANDOM%%RANDOM%.txt"
"!LUBAN_EXE!" --conf "!CONF_FILE!" -t !LIST_TARGET! --listTables "!SCAN_PATH!" > "!LIST_TMP!"
set "LIST_ERR=!errorlevel!"
if not "!LIST_ERR!"=="0" (
  del /q "!LIST_TMP!" 2>nul
  echo.
  echo [ERROR] Could not list tables under: !SCAN_PATH!
  echo         Luban exited with code !LIST_ERR!; the reason is printed above.
  echo         Common causes: a malformed B1 cell, or a table name collision.
  if not defined LUBAN_NO_PAUSE pause
  exit /b 6
)
for /f "usebackq delims=" %%A in ("!LIST_TMP!") do (
  set OUTPUT_TABLE_ARGS=!OUTPUT_TABLE_ARGS! -o %%A
)
del /q "!LIST_TMP!" 2>nul
if "!OUTPUT_TABLE_ARGS!"=="" (
  echo No exportable tables found under: !SCAN_PATH!
  echo   ^(the listing succeeded - this folder genuinely has no exportable table^)
  if not defined LUBAN_NO_PAUSE pause
  exit /b 4
)

rem Per-target output directories, from contextMenu.data.outputDataDir.
rem Luban's xargs namespace is keyed by dataTarget, not by target, so a
rem "client.outputDataDir" style option would silently do nothing. Translating
rem the mapping here is what actually gives each target its own directory --
rem otherwise every target writes to the same place and the last one wins.
rem Read once into OUTDIR_<target> variables (cheaper than one call per target).
for /f "usebackq tokens=1,* delims==" %%A in (`powershell -NoProfile -Command ^
  "$c = Get-Content -Raw '!CONF_FILE!' | ConvertFrom-Json;" ^
  "$m = $c.contextMenu.data.outputDataDir;" ^
  "if ($m) { $m.PSObject.Properties | ForEach-Object { $_.Name + '=' + $_.Value } }"`
) do set "OUTDIR_%%A=%%B"

pushd "%LUBAN_DIR%"
for %%t in (%DATA_TARGETS%) do (
  set OUT_ARG=
  call set "TARGET_OUT=%%OUTDIR_%%t%%"
  if defined TARGET_OUT set OUT_ARG=-x outputDataDir=!TARGET_OUT!

  rem Step 2: full schema load (so cross-table refs resolve), but -o limits
  rem which tables actually get exported.
  rem
  rem cleanUpOutputDir=0 is mandatory here. Luban defaults it to true and then
  rem deletes every file in outputDataDir that is not part of THIS run's output.
  rem Combined with -o that would mean: exporting one table wipes every other
  rem table's data, plus any unrelated file that lives in that directory --
  rem which destroys the whole point of exporting a selected subset.
  rem Full exports via gen.bat keep the cleanup, where it correctly removes
  rem leftovers from tables that no longer exist.
  "!LUBAN_EXE!" --conf "!CONF_FILE!" -t %%t -d !DATA_FORMAT! !OUT_ARG! -x cleanUpOutputDir=0 -x outputSaver.!DATA_FORMAT!.cleanUpOutputDir=0 !OUTPUT_TABLE_ARGS! !EXTRA_ARGS!
  if errorlevel 1 (
    echo Export failed for target %%t
  ) else (
    if defined TARGET_OUT (
      echo   [%%t] -^> !TARGET_OUT!
    ) else (
      echo   [%%t] -^> see outputDataDir in luban.conf
    )
  )
)
popd

echo.
echo Done. Paths above are relative to %LUBAN_DIR%
if not defined LUBAN_NO_PAUSE pause
endlocal
