@echo off
setlocal EnableExtensions

rem This script lives in esyluban\scripts\test\; two levels up is esyluban\
set ESY_ROOT=%~dp0..\..
set EXAMPLE_ROOT=%ESY_ROOT%\examples\dev
set LUBAN_DIR=%EXAMPLE_ROOT%\Tools\Luban
rem Runtime is shared repo-wide, no longer copied into each project
set LUBAN_DLL=%ESY_ROOT%\runtime\Luban.dll
set CONF_FILE=%LUBAN_DIR%\luban.conf
set OUTPUT_DIR=%EXAMPLE_ROOT%\TestOutputs\json
set OUTPUT_DIR_NO_L10N=%EXAMPLE_ROOT%\TestOutputs\json_nol10n
set L10N_FILE=%EXAMPLE_ROOT%\DataTables\l10n\texts.xlsx
set BASELINE_DIR_CORE=%ESY_ROOT%\baselines\core
set BASELINE_DIR_COVERAGE=%ESY_ROOT%\baselines\coverage
set COMPARE_REPORT_CORE=%EXAMPLE_ROOT%\TestOutputs\compare_report.json
set COMPARE_REPORT_COVERAGE=%EXAMPLE_ROOT%\TestOutputs\compare_report_coverage.json
set NEGATIVE_DIR=%EXAMPLE_ROOT%\DataTables\negatives
set NEGATIVE_OUTPUT_DIR=%EXAMPLE_ROOT%\TestOutputs\negatives
set NEGATIVE_LOG=%EXAMPLE_ROOT%\TestOutputs\negative_tests.log

pushd "%LUBAN_DIR%"

echo [EXAMPLE] generate json outputs (with l10n)
dotnet "%LUBAN_DLL%" ^
  -t all ^
  -d json ^
  --conf "%CONF_FILE%" ^
  -x outputDataDir="%OUTPUT_DIR%" ^
  -x all.outputDataDir="%OUTPUT_DIR%" ^
  -x l10n.provider=default ^
  -x l10n.textFile.path=%L10N_FILE% ^
  -x l10n.textFile.keyFieldName=key ^
  -x l10n.textFile.languageFieldName=zh ^
  -x l10n.convertTextKeyToValue=1

echo [EXAMPLE] generate json outputs (no l10n)
dotnet "%LUBAN_DLL%" ^
  -t all ^
  -d json ^
  --conf "%CONF_FILE%" ^
  -x outputDataDir="%OUTPUT_DIR_NO_L10N%" ^
  -x all.outputDataDir="%OUTPUT_DIR_NO_L10N%" ^
  -x l10n.convertTextKeyToValue=0

rem Negative cases are isolated by group "t" (see their B1 metadata), which the
rem "test" target already filters on. Do NOT additionally restrict
rem tableImporter.scanPath to the negatives folder: schema definitions are loaded
rem globally, so importing only that folder leaves cross-table refs dangling
rem (e.g. ai.Blackboard.parent_name ref ai.TbBlackboard) and the run aborts on
rem that unrelated error before ever reaching the validators under test.
if exist "%NEGATIVE_DIR%" (
  echo [EXAMPLE] negative tests - log only
  dotnet "%LUBAN_DLL%" ^
    -t test ^
    -d json ^
    --conf "%CONF_FILE%" ^
    -x outputDataDir="%NEGATIVE_OUTPUT_DIR%" ^
    -x test.outputDataDir="%NEGATIVE_OUTPUT_DIR%" > "%NEGATIVE_LOG%" 2>&1
  echo [EXAMPLE] negative log saved: %NEGATIVE_LOG%
) else (
  echo [EXAMPLE] negatives not found: %NEGATIVE_DIR%
)

if exist "%BASELINE_DIR_CORE%" echo [EXAMPLE] compare no-l10n outputs with pristine baseline (core)
if exist "%BASELINE_DIR_CORE%" powershell -NoProfile -Command "$base=[System.IO.Path]::GetFullPath($env:BASELINE_DIR_CORE); $out=[System.IO.Path]::GetFullPath($env:OUTPUT_DIR_NO_L10N); $report=$env:COMPARE_REPORT_CORE; function GetHash([string]$p){ $sha=[System.Security.Cryptography.SHA256]::Create(); $bytes=[System.IO.File]::ReadAllBytes($p); return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLower(); } $baseFiles=Get-ChildItem -File -Recurse $base | ForEach-Object { $_.FullName.Substring($base.Length+1) }; $outFiles=Get-ChildItem -File -Recurse $out | ForEach-Object { $_.FullName.Substring($out.Length+1) }; $missing=@($baseFiles | Where-Object { $outFiles -notcontains $_ }); $diff=@(); foreach ($f in $baseFiles) { if ($outFiles -contains $f) { $h1=GetHash (Join-Path $base $f); $h2=GetHash (Join-Path $out $f); if ($h1 -ne $h2) { $diff += $f } } }; $summary=[PSCustomObject]@{ base_count=$baseFiles.Count; out_count=$outFiles.Count; missing=$missing; extra=@(); diff=$diff }; $summary | ConvertTo-Json -Depth 3 | Set-Content -Encoding UTF8 $report"
if not exist "%BASELINE_DIR_CORE%" echo [EXAMPLE] pristine baseline not found: %BASELINE_DIR_CORE%

if exist "%BASELINE_DIR_COVERAGE%" echo [EXAMPLE] compare no-l10n outputs with coverage baseline
if exist "%BASELINE_DIR_COVERAGE%" powershell -NoProfile -Command "$base=[System.IO.Path]::GetFullPath($env:BASELINE_DIR_COVERAGE); $out=[System.IO.Path]::GetFullPath($env:OUTPUT_DIR_NO_L10N); $report=$env:COMPARE_REPORT_COVERAGE; function GetHash([string]$p){ $sha=[System.Security.Cryptography.SHA256]::Create(); $bytes=[System.IO.File]::ReadAllBytes($p); return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLower(); } $baseFiles=Get-ChildItem -File -Recurse $base | ForEach-Object { $_.FullName.Substring($base.Length+1) }; $outFiles=Get-ChildItem -File -Recurse $out | ForEach-Object { $_.FullName.Substring($out.Length+1) }; $missing=@($baseFiles | Where-Object { $outFiles -notcontains $_ }); $extra=@($outFiles | Where-Object { $baseFiles -notcontains $_ }); $diff=@(); foreach ($f in $baseFiles) { if ($outFiles -contains $f) { $h1=GetHash (Join-Path $base $f); $h2=GetHash (Join-Path $out $f); if ($h1 -ne $h2) { $diff += $f } } }; $summary=[PSCustomObject]@{ base_count=$baseFiles.Count; out_count=$outFiles.Count; missing=$missing; extra=$extra; diff=$diff }; $summary | ConvertTo-Json -Depth 3 | Set-Content -Encoding UTF8 $report"
if not exist "%BASELINE_DIR_COVERAGE%" echo [EXAMPLE] coverage baseline not found: %BASELINE_DIR_COVERAGE%

popd
