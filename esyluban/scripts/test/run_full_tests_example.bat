@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ---------------------------------------------------------------
rem Regression: export examples/dev and compare against both baselines.
rem
rem This script used to have zero `if errorlevel` and zero `exit /b`: a run in
rem which Luban never started still printed an all-green report and returned 0.
rem That is why a pair of cancelling-out bugs survived every regression for
rem months. Three rules now hold, and must keep holding:
rem
rem   1. every external command is followed by an errorlevel check
rem   2. output directories are wiped before exporting, so "nothing generated"
rem      can never be masked by "nothing cleaned"
rem   3. the final exit code and the closing message are decided by the
rem      accumulated failure count, never hard-coded
rem
rem NOTE: keep this file ASCII-only. cmd parses .bat using the system
rem ANSI code page, so UTF-8 non-ASCII comments break execution.
rem ---------------------------------------------------------------

set ESY_ROOT=%~dp0..\..
set EXAMPLE_ROOT=%ESY_ROOT%\examples\dev
set LUBAN_DIR=%EXAMPLE_ROOT%\Tools\Luban
set LUBAN_EXE=%ESY_ROOT%\runtime\Luban.exe
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
set MAIN_LOG=%EXAMPLE_ROOT%\TestOutputs\main_export.log
set COMPARE_PS1=%~dp0compare_baseline.ps1

set FAILED=0

if not exist "!LUBAN_EXE!" (
  echo [FAIL] runtime not built: !LUBAN_EXE!
  echo        run esyluban\scripts\build.bat first
  exit /b 1
)

rem Wipe outputs first. Luban only touches the output directory at save time,
rem so a failure during schema/load leaves the previous run's files in place --
rem the baseline would then match yesterday's output and report success.
for %%D in ("!OUTPUT_DIR!" "!OUTPUT_DIR_NO_L10N!" "!NEGATIVE_OUTPUT_DIR!") do (
  if exist "%%~D" rmdir /s /q "%%~D"
)

pushd "!LUBAN_DIR!"

echo [EXAMPLE] generate json outputs (with l10n)
"!LUBAN_EXE!" ^
  -t all ^
  -d json ^
  --conf "!CONF_FILE!" ^
  -x outputDataDir="!OUTPUT_DIR!" ^
  -x l10n.provider=default ^
  -x l10n.textFile.path=!L10N_FILE! ^
  -x l10n.textFile.keyFieldName=key ^
  -x l10n.textFile.languageFieldName=zh ^
  -x l10n.convertTextKeyToValue=1
if errorlevel 1 (
  echo [FAIL] export with l10n returned !errorlevel!
  set /a FAILED+=1
)

echo [EXAMPLE] generate json outputs (no l10n)
"!LUBAN_EXE!" ^
  -t all ^
  -d json ^
  --conf "!CONF_FILE!" ^
  -x outputDataDir="!OUTPUT_DIR_NO_L10N!" ^
  -x l10n.convertTextKeyToValue=0 > "!MAIN_LOG!" 2>&1
if errorlevel 1 (
  echo [FAIL] export without l10n returned !errorlevel!
  set /a FAILED+=1
)
type "!MAIN_LOG!"

rem Assert the validator subsystem is still alive.
rem
rem SHA256 baselines cannot see validators at all: if ref/path/range/set/regex
rem all degraded to no-ops tomorrow, every output byte would stay identical and
rem both baselines would pass. Counting the errors this fixture set is KNOWN to
rem produce catches that -- a drop to 0 means the validators stopped running,
rem an increase means something new broke.
rem
rem --validationFailAsError is deliberately NOT used: the corpus intentionally
rem contains failing records (negatives/, plus test/path.xlsx which fails
rem upstream too and whose output is part of the core baseline).
rem
rem Expected 8, by category:
rem   4  negatives/validators_fail.xlsx  regex / not-default / range / set
rem   1  negatives/path_fail.xlsx        path points at a missing file
rem   2  test/path.xlsx                  upstream fixture, fails upstream as well
rem   1  l10n                            text id "   /apple" has no translation
set EXPECTED_ERRORS=8
for /f %%N in ('findstr /c:"|ERROR|" "!MAIN_LOG!" ^| find /c /v ""') do set ACTUAL_ERRORS=%%N
if not "!ACTUAL_ERRORS!"=="!EXPECTED_ERRORS!" (
  echo [FAIL] validator check: expected !EXPECTED_ERRORS! known errors, got !ACTUAL_ERRORS!
  echo        fewer  =^> validators may have stopped running
  echo        more   =^> a new failure appeared; see !MAIN_LOG!
  set /a FAILED+=1
) else (
  echo [OK]   validator check: !ACTUAL_ERRORS! known errors, as expected
)

rem Negative cases are isolated by group "t" (see their B1 metadata), which the
rem "test" target already filters on. Do NOT additionally restrict
rem tableImporter.scanPath to the negatives folder: schema definitions are loaded
rem globally, so importing only that folder leaves cross-table refs dangling
rem (e.g. ai.Blackboard.parent_name ref ai.TbBlackboard) and the run aborts on
rem that unrelated error before ever reaching the validators under test.
rem
rem These are EXPECTED to fail, so their exit code is deliberately not counted.
if exist "!NEGATIVE_DIR!" (
  echo [EXAMPLE] negative tests - log only, failure is expected
  "!LUBAN_EXE!" ^
    -t test ^
    -d json ^
    --conf "!CONF_FILE!" ^
    -x outputDataDir="!NEGATIVE_OUTPUT_DIR!" > "!NEGATIVE_LOG!" 2>&1
  echo [EXAMPLE] negative log saved: !NEGATIVE_LOG!
) else (
  echo [FAIL] negatives not found: !NEGATIVE_DIR!
  set /a FAILED+=1
)

popd

rem core/ is upstream's own output: we legitimately have more tables than it
rem (matrix/, minimal_b1). Missing or differing files are still failures --
rem only extras are exempt, and the exemption is stated rather than hidden.
powershell -NoProfile -ExecutionPolicy Bypass -File "!COMPARE_PS1!" ^
  -BaselineDir "!BASELINE_DIR_CORE!" -OutputDir "!OUTPUT_DIR_NO_L10N!" ^
  -ReportPath "!COMPARE_REPORT_CORE!" -Label "core baseline" -AllowExtra
if errorlevel 1 set /a FAILED+=1

powershell -NoProfile -ExecutionPolicy Bypass -File "!COMPARE_PS1!" ^
  -BaselineDir "!BASELINE_DIR_COVERAGE!" -OutputDir "!OUTPUT_DIR_NO_L10N!" ^
  -ReportPath "!COMPARE_REPORT_COVERAGE!" -Label "coverage baseline"
if errorlevel 1 set /a FAILED+=1

rem Owned files silently swallowed by .gitignore are invisible until someone
rem clones. Cheap to check, and it has already caught two real losses.
call "%~dp0check_gitignore_traps.bat"
if errorlevel 1 set /a FAILED+=1

echo.
if !FAILED! gtr 0 (
  echo ==========================================
  echo   REGRESSION FAILED - !FAILED! check^(s^) failed
  echo ==========================================
  exit /b 1
)
echo ==========================================
echo   REGRESSION PASSED
echo ==========================================
exit /b 0
