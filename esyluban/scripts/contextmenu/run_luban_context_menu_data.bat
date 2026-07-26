@echo off
setlocal EnableExtensions EnableDelayedExpansion

set TARGET=%~f1
if "%TARGET%"=="" (
  set TARGET=%CD%
  if "%TARGET%"=="" (
    echo No target path provided.
    pause
    exit /b 1
  )
)

if exist "%TARGET%\*" (
  set IS_DIR=1
  set TARGET_DIR=%TARGET%
) else (
  set IS_DIR=0
  set TARGET_DIR=%~dp1
)

set CUR_DIR=%TARGET_DIR%
set LUBAN_DIR=
set PROJECT_ROOT=
for /l %%i in (0,1,5) do (
  if exist "!CUR_DIR!\Tools\Luban\luban.conf" (
    set LUBAN_DIR=!CUR_DIR!\Tools\Luban
    set PROJECT_ROOT=!CUR_DIR!
    goto :FOUND_LUBAN
  )
  set CUR_DIR=!CUR_DIR!\..
)

:FOUND_LUBAN
if not defined LUBAN_DIR (
  echo Tools\Luban not found within 5 levels.
  pause
  exit /b 2
)

set CONF_FILE=%LUBAN_DIR%\luban.conf

rem Config travels with each project; the runtime is shared repo-wide.
rem Locate the runtime by searching upwards from the project root.
set FIND_DIR=%PROJECT_ROOT%
set LUBAN_DLL=
for /l %%i in (0,1,6) do (
  if not defined LUBAN_DLL if exist "!FIND_DIR!\esyluban\runtime\Luban.dll" set "LUBAN_DLL=!FIND_DIR!\esyluban\runtime\Luban.dll"
  if not defined LUBAN_DLL if exist "!FIND_DIR!\runtime\Luban.dll" set "LUBAN_DLL=!FIND_DIR!\runtime\Luban.dll"
  set "FIND_DIR=!FIND_DIR!\.."
)
if not defined LUBAN_DLL (
  echo Luban runtime not found. Run esyluban\scripts\build.bat first.
  pause
  exit /b 3
)

set SCAN_PATH=%TARGET%
if %IS_DIR%==1 (
  set SCAN_PATH=%TARGET_DIR%
)

set DATA_TARGETS=
set DATA_FORMAT=
set EXTRA_ARGS=
set OUTPUT_TABLE_ARGS=

for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
  "$conf=Get-Content -Raw '%CONF_FILE%';" ^
  "$json=$conf | ConvertFrom-Json;" ^
  "$data=$json.contextMenu.data;" ^
  "if($null -ne $data -and $data.targets){$data.targets -join ' '}"`
) do set DATA_TARGETS=%%A
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
  "$conf=Get-Content -Raw '%CONF_FILE%';" ^
  "$json=$conf | ConvertFrom-Json;" ^
  "$data=$json.contextMenu.data;" ^
  "if($null -ne $data -and $data.dataTarget){$data.dataTarget}"`
) do set DATA_FORMAT=%%A
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
  "$conf=Get-Content -Raw '%CONF_FILE%';" ^
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
rem Its stdout is table full names, one per line, with logging suppressed.
for /f "usebackq delims=" %%A in (`dotnet "%LUBAN_DLL%" --conf "%CONF_FILE%" -t %LIST_TARGET% --listTables "%SCAN_PATH%"`) do (
  set OUTPUT_TABLE_ARGS=!OUTPUT_TABLE_ARGS! -o %%A
)
if "%OUTPUT_TABLE_ARGS%"=="" (
  echo No exportable tables found under: %SCAN_PATH%
  pause
  exit /b 4
)

rem Per-target output directories, from contextMenu.data.outputDataDir.
rem Luban's xargs namespace is keyed by dataTarget, not by target, so a
rem "client.outputDataDir" style option would silently do nothing. Translating
rem the mapping here is what actually gives each target its own directory --
rem otherwise every target writes to the same place and the last one wins.
rem Read once into OUTDIR_<target> variables (cheaper than one call per target).
for /f "usebackq tokens=1,* delims==" %%A in (`powershell -NoProfile -Command ^
  "$c = Get-Content -Raw '%CONF_FILE%' | ConvertFrom-Json;" ^
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
  dotnet "%LUBAN_DLL%" --conf "%CONF_FILE%" -t %%t -d %DATA_FORMAT% !OUT_ARG! %OUTPUT_TABLE_ARGS% %EXTRA_ARGS%
  if errorlevel 1 (
    echo Export failed for target %%t
  )
)
popd

echo Done. Outputs are under: %PROJECT_ROOT%\TestOutputs\json
pause
endlocal
