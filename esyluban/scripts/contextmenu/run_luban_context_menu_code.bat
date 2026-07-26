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

set CODE_TARGETS=
set TARGET_NAME=
set TARGET_NAMES=
set EXTRA_ARGS=
set OUTPUT_TABLE_ARGS=

for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
  "$conf=Get-Content -Raw '%CONF_FILE%';" ^
  "$json=$conf | ConvertFrom-Json;" ^
  "$code=$json.contextMenu.code;" ^
  "if($null -ne $code -and $code.targets){$code.targets -join ' '}"`
) do set TARGET_NAMES=%%A
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
  "$conf=Get-Content -Raw '%CONF_FILE%';" ^
  "$json=$conf | ConvertFrom-Json;" ^
  "$code=$json.contextMenu.code;" ^
  "if($null -ne $code -and $code.target){$code.target}"`
) do set TARGET_NAME=%%A
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
  "$conf=Get-Content -Raw '%CONF_FILE%';" ^
  "$json=$conf | ConvertFrom-Json;" ^
  "$code=$json.contextMenu.code;" ^
  "if($null -ne $code -and $code.codeTargets){$code.codeTargets -join ' '}"`
) do set CODE_TARGETS=%%A
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
  "$conf=Get-Content -Raw '%CONF_FILE%';" ^
  "$json=$conf | ConvertFrom-Json;" ^
  "$code=$json.contextMenu.code;" ^
  "if($null -ne $code -and $code.extraArgs){$code.extraArgs -join ' '}"`
) do set EXTRA_ARGS=%%A

if "%TARGET_NAMES%"=="" set TARGET_NAMES=%TARGET_NAME%
if "%TARGET_NAMES%"=="" set TARGET_NAMES=client
if "%CODE_TARGETS%"=="" set CODE_TARGETS=cs-simple-json

set LIST_TARGET=
for %%t in (%TARGET_NAMES%) do (
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

pushd "%LUBAN_DIR%"
for %%t in (%TARGET_NAMES%) do (
  for %%c in (%CODE_TARGETS%) do (
    rem Step 2: full schema load (so cross-table refs resolve), but -o limits
    rem which tables actually get exported.
    dotnet "%LUBAN_DLL%" --conf "%CONF_FILE%" -t %%t -c %%c %OUTPUT_TABLE_ARGS% %EXTRA_ARGS%
    if errorlevel 1 (
      echo Code generation failed for target %%t code target %%c
    )
  )
)
popd

echo Done. Outputs are under: %PROJECT_ROOT%\TestOutputs\code
pause
endlocal
