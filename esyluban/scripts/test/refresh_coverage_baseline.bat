@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem This script lives in esyluban\scripts\test\; two levels up is esyluban\
set ESY_ROOT=%~dp0..\..
set EXAMPLE_ROOT=%ESY_ROOT%\examples\dev
set OUTPUT_DIR=%EXAMPLE_ROOT%\TestOutputs\json_nol10n
set BASELINE_DIR=%ESY_ROOT%\baselines\coverage
set BASELINE_ROOT=%ESY_ROOT%\baselines
set BASELINE_LOG=%BASELINE_ROOT%\baseline_log.md

if not exist "%OUTPUT_DIR%" (
  echo Output not found: !OUTPUT_DIR!
  exit /b 1
)

if not exist "%BASELINE_ROOT%" (
  mkdir "!BASELINE_ROOT!"
)

if not exist "%BASELINE_DIR%" (
  mkdir "!BASELINE_DIR!"
)

robocopy "%OUTPUT_DIR%" "%BASELINE_DIR%" /MIR /COPY:DAT /R:3 /W:1 >nul
echo Coverage baseline refreshed: %BASELINE_DIR%

powershell -NoProfile -Command "$log=$env:BASELINE_LOG; $now=(Get-Date).ToString('s'); $entry='- '+$now+' refresh from '+$env:OUTPUT_DIR; Add-Content -Encoding UTF8 -Path $log -Value $entry"

endlocal
