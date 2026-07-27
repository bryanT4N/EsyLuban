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

rem %2 is the Tools\Luban directory, passed in by menu_entry_code.bat which
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

rem Parse the conf ONCE up front and fail loudly if it cannot be read.
rem
rem Every setting below is read through Windows PowerShell 5.1, whose
rem ConvertFrom-Json is stricter than Luban's own parser: it rejects // comments
rem AND trailing commas, both of which Luban accepts. When it failed, each query
rem returned empty and the script quietly fell back to hard-coded defaults --
rem so the menu ran, exited 0, printed Done, and ignored the entire contextMenu
rem section. Silently using different settings than the file says is worse than
rem refusing to run.
powershell -NoProfile -Command ^
  "try { Get-Content -Raw '!CONF_FILE!' | ConvertFrom-Json | Out-Null; exit 0 }" ^
  "catch { Write-Host $_.Exception.Message; exit 1 }"
if errorlevel 1 (
  echo.
  echo [ERROR] Cannot parse: !CONF_FILE!
  echo         The right-click menu reads it with Windows PowerShell 5.1, which
  echo         rejects // comments and trailing commas even though Luban accepts
  echo         them. Remove those and try again.
  if not defined LUBAN_NO_PAUSE pause
  exit /b 7
)

set CODE_TARGETS=
set TARGET_NAME=
set TARGET_NAMES=
set EXTRA_ARGS=
set OUTPUT_TABLE_ARGS=

for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
  "$conf=Get-Content -Raw '!CONF_FILE!';" ^
  "$json=$conf | ConvertFrom-Json;" ^
  "$code=$json.contextMenu.code;" ^
  "if($null -ne $code -and $code.targets){$code.targets -join ' '}"`
) do set TARGET_NAMES=%%A
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
  "$conf=Get-Content -Raw '!CONF_FILE!';" ^
  "$json=$conf | ConvertFrom-Json;" ^
  "$code=$json.contextMenu.code;" ^
  "if($null -ne $code -and $code.target){$code.target}"`
) do set TARGET_NAME=%%A
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
  "$conf=Get-Content -Raw '!CONF_FILE!';" ^
  "$json=$conf | ConvertFrom-Json;" ^
  "$code=$json.contextMenu.code;" ^
  "if($null -ne $code -and $code.codeTargets){$code.codeTargets -join ' '}"`
) do set CODE_TARGETS=%%A
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
  "$conf=Get-Content -Raw '!CONF_FILE!';" ^
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

rem Track failures explicitly -- see the note in the data script: without a
rem counter the exit code is just whatever the LAST combination left behind.
set GEN_FAILED=0

pushd "%LUBAN_DIR%"
for %%t in (%TARGET_NAMES%) do (
  for %%c in (!CODE_TARGETS!) do (
    rem Step 2: full schema load (so cross-table refs resolve), but -o limits
    rem which tables actually get exported.
    rem
    rem cleanUpOutputDir=0 is mandatory here -- see the note in the data script.
    rem Without it, generating code for one table deletes the generated code of
    rem every other table in outputCodeDir.
    "!LUBAN_EXE!" --conf "!CONF_FILE!" -t %%t -c %%c -x cleanUpOutputDir=0 -x outputSaver.%%c.cleanUpOutputDir=0 !OUTPUT_TABLE_ARGS! !EXTRA_ARGS!
    if errorlevel 1 (
      echo Code generation failed for target %%t code target %%c
      echo   If the log says a referenced table "was not exported", this
      echo   target's groups exclude the tables you selected. List only the
      echo   targets that actually contain them in contextMenu.code.targets.
      set /a GEN_FAILED+=1
    )
  )
)
popd

echo.
if not "!GEN_FAILED!"=="0" (
  echo Done with errors: !GEN_FAILED! combination^(s^) failed.
  echo   Generated code went to outputCodeDir, set in:
  echo   %CONF_FILE%
  if not defined LUBAN_NO_PAUSE pause
  endlocal & exit /b 1
)
echo Done. Generated code went to outputCodeDir, set in:
echo   %CONF_FILE%
if not defined LUBAN_NO_PAUSE pause
endlocal
