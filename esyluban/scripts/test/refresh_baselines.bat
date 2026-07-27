@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ---------------------------------------------------------------
rem Refresh regression baselines from the current export.
rem
rem   refresh_baselines.bat [coverage|xml|code|l10n|all]
rem
rem Only one of the five baseline sets used to have a refresh script. Change a
rem code template and 225 .cs baselines go red with no documented way forward --
rem the contributor's only option was a hand-written robocopy, which is the exact
rem operation baselines/README warns is unrecoverable if aimed wrong.
rem
rem core/ is deliberately NOT refreshable. It holds upstream's output on the
rem un-migrated corpus and is what proves "switching to A1/B1 definitions changed
rem nothing". Regenerate it and that proof is gone for good, so this script
rem refuses rather than offers.
rem
rem NOTE: keep this file ASCII-only. cmd parses .bat using the system ANSI code
rem page, so UTF-8 non-ASCII comments break execution.
rem ---------------------------------------------------------------

set ESY_ROOT=%~dp0..\..
set EXAMPLE_ROOT=%ESY_ROOT%\examples\dev
set OUT=%EXAMPLE_ROOT%\TestOutputs
set BASELINE_ROOT=%ESY_ROOT%\baselines
set BASELINE_LOG=%BASELINE_ROOT%\baseline_log.md

set WHICH=%~1
if "%WHICH%"=="" set WHICH=all

if /i "%WHICH%"=="core" (
  echo [REFUSED] core/ is not refreshable.
  echo.
  echo   It is upstream Luban's output on the un-migrated corpus -- the evidence
  echo   that EsyLuban's table definitions produce byte-identical data. Once
  echo   overwritten it cannot be regenerated from this repository.
  echo.
  echo   If core/ disagrees with the current export, that is the finding.
  exit /b 1
)

set REFRESHED=0

if /i "%WHICH%"=="all"      call :Refresh coverage  json_nol10n
if /i "%WHICH%"=="coverage" call :Refresh coverage  json_nol10n
if /i "%WHICH%"=="all"      call :Refresh xml       xml
if /i "%WHICH%"=="xml"      call :Refresh xml       xml
if /i "%WHICH%"=="all"      call :Refresh code_cs   code_cs
if /i "%WHICH%"=="code"     call :Refresh code_cs   code_cs
if /i "%WHICH%"=="all"      call :Refresh json_l10n json
if /i "%WHICH%"=="l10n"     call :Refresh json_l10n json

if "!REFRESHED!"=="0" (
  echo [ERROR] Nothing refreshed. Expected: coverage ^| xml ^| code ^| l10n ^| all
  echo         Got: %WHICH%
  exit /b 1
)

echo.
echo Refreshed !REFRESHED! baseline set^(s^). Review the diff before committing:
echo   git diff --stat esyluban\baselines
exit /b 0

rem ---------------------------------------------------------------
:Refresh
rem %1 = baseline directory name, %2 = TestOutputs subdirectory to copy from
set "SET_NAME=%~1"
set "SRC=%OUT%\%~2"

if not exist "%SRC%" (
  echo [SKIP] %SET_NAME%: no export at %SRC%
  echo        run scripts\test\run_full_tests_example.bat first
  goto :eof
)

rem An empty source with /MIR would wipe the baseline and report success.
set FILE_COUNT=0
for /f %%N in ('dir /b /s /a-d "%SRC%" 2^>nul ^| find /c /v ""') do set FILE_COUNT=%%N
if "!FILE_COUNT!"=="0" (
  echo [SKIP] %SET_NAME%: %SRC% is empty -- refusing to mirror nothing over a baseline
  goto :eof
)

if not exist "%BASELINE_ROOT%\%SET_NAME%" mkdir "%BASELINE_ROOT%\%SET_NAME%"
robocopy "%SRC%" "%BASELINE_ROOT%\%SET_NAME%" /MIR /COPY:DAT /R:3 /W:1 >nul
if errorlevel 8 (
  echo [FAIL] %SET_NAME%: robocopy returned !errorlevel!
  goto :eof
)

echo [OK]   %SET_NAME% refreshed from %~2 ^(!FILE_COUNT! files^)
set /a REFRESHED+=1
powershell -NoProfile -Command ^
  "$entry = '- ' + (Get-Date).ToString('s') + ' refresh ' + $env:SET_NAME + ' from ' + $env:SRC;" ^
  "Add-Content -Encoding UTF8 -Path $env:BASELINE_LOG -Value $entry"
goto :eof
