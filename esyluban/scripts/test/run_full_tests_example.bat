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
set CONTEXTMENU_OUT=%EXAMPLE_ROOT%\TestOutputs\contextmenu
set OUTPUT_DIR_XML=%EXAMPLE_ROOT%\TestOutputs\xml
set OUTPUT_DIR_CODE=%EXAMPLE_ROOT%\TestOutputs\code_cs
set BASELINE_DIR_XML=%ESY_ROOT%\baselines\xml
set BASELINE_DIR_CODE=%ESY_ROOT%\baselines\code_cs
set BASELINE_DIR_L10N=%ESY_ROOT%\baselines\json_l10n
set RELEASE_ROOT=%ESY_ROOT%\examples\release
set RELEASE_ASSETS=%RELEASE_ROOT%\Projects\Csharp_Unity_json\Assets
set RELEASE_TMP=%RELEASE_ROOT%\TestOutputs\gen_all
set COMPARE_REPORT_L10N=%EXAMPLE_ROOT%\TestOutputs\compare_report_l10n.json
set COMPARE_REPORT_XML=%EXAMPLE_ROOT%\TestOutputs\compare_report_xml.json
set COMPARE_REPORT_CODE=%EXAMPLE_ROOT%\TestOutputs\compare_report_code.json
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
for %%D in ("!OUTPUT_DIR!" "!OUTPUT_DIR_NO_L10N!" "!NEGATIVE_OUTPUT_DIR!" "!OUTPUT_DIR_XML!" "!OUTPUT_DIR_CODE!") do (
  if exist "%%~D" rmdir /s /q "%%~D"
)

rem Exports go through gen.bat, not straight to Luban.exe.
rem
rem gen.bat is what the docs tell users to run, so it is the thing that has to
rem work. Calling the executable behind it skips runtime lookup, argument
rem handling and exit-code propagation -- precisely where breakage hides. The
rem release smoke test learned this the hard way: it bypassed gen.bat and
rem happily passed while `gen.bat` itself could not run at all.
set LUBAN_NO_PAUSE=1

echo [EXAMPLE] generate json outputs (with l10n) -- via gen.bat
call "!LUBAN_DIR!\gen.bat" ^
  -t all ^
  -d json ^
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

echo [EXAMPLE] generate json outputs (no l10n) -- via gen.bat
call "!LUBAN_DIR!\gen.bat" ^
  -t all ^
  -d json ^
  -x outputDataDir="!OUTPUT_DIR_NO_L10N!" ^
  -x l10n.convertTextKeyToValue=0 > "!MAIN_LOG!" 2>&1
if errorlevel 1 (
  echo [FAIL] export without l10n returned !errorlevel!
  set /a FAILED+=1
)
type "!MAIN_LOG!"

rem check.bat must FAIL here, and that is the assertion.
rem The dev corpus deliberately contains broken records (negatives/, plus
rem upstream's own test/path.xlsx). If this entry point ever reports success,
rem it has stopped validating -- which is exactly what it used to do before
rem --validationFailAsError was added.
echo [EXAMPLE] check.bat must reject the corpus (it contains deliberate negatives)
call "!LUBAN_DIR!\check.bat" -t all >nul 2>&1
if errorlevel 1 (
  echo [OK]   check.bat correctly rejected the corpus
) else (
  echo [FAIL] check.bat reported success on a corpus with known-bad records
  echo        it is no longer validating anything
  set /a FAILED+=1
)

pushd "!LUBAN_DIR!"

rem Assert the validator subsystem is still alive, by category.
rem
rem SHA256 baselines cannot see validators at all: if ref/path/range/set/regex
rem all degraded to no-ops tomorrow, every output byte would stay identical and
rem all four baselines would pass. Counting the errors this corpus is KNOWN to
rem produce is what catches that.
rem
rem Counted per source rather than as one total, so a drop tells you WHICH
rem validator family stopped running. A single number would let one family die
rem while another gained an error, and still add up to 8.
rem
rem Note on group filtering: the negatives carry group="t" and the "all" target
rem binds c/s/e, so their OUTPUT is correctly filtered out (no matrix_tbpathfail
rem in the baselines). But validation runs BEFORE that filtering, so they still
rem report here. That is expected -- it is also what keeps these validators
rem under observation on every run.
rem
rem --validationFailAsError is deliberately NOT used here: the corpus contains
rem records that are meant to fail. check.bat covers the "must reject" side.
set VALIDATOR_FAILED=0

call :CountErr "matrix.TbPathFail"       1 "negatives: path validator"
call :CountErr "matrix.TbValidatorsFail" 4 "negatives: regex/default/range/set"
call :CountErr "test.TbPath"             2 "upstream fixture test/path.xlsx"
call :CountErr "test.TbDataFromMisc"     1 "text key validator (invalid text id)"

if !VALIDATOR_FAILED! gtr 0 (
  echo [FAIL] validator check: !VALIDATOR_FAILED! categor^(ies^) off; see !MAIN_LOG!
  echo        fewer =^> that validator family stopped running
  echo        more  =^> a new failure appeared
  set /a FAILED+=1
) else (
  echo [OK]   validator check: all 4 error categories as expected
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

rem Formats other than json had zero coverage: 16 dataTargets, only json was
rem ever exercised -- while the real integration project uses xml. All 29
rem codeTargets were untested too, which also means B1's mode / index were
rem invisible to the baselines, since they shape generated code rather than
rem json data. Both outputs are deterministic (verified byte-identical across
rem consecutive runs), so they can be baselined like the json ones.
echo [EXAMPLE] generate xml outputs -- via gen.bat
call "!LUBAN_DIR!\gen.bat" -t all -d xml -x outputDataDir="!OUTPUT_DIR_XML!"
if errorlevel 1 (
  echo [FAIL] xml export returned !errorlevel!
  set /a FAILED+=1
)

echo [EXAMPLE] generate C# code -- via gen.bat
call "!LUBAN_DIR!\gen.bat" -t all -c cs-simple-json -x outputCodeDir="!OUTPUT_DIR_CODE!"
if errorlevel 1 (
  echo [FAIL] code generation returned !errorlevel!
  set /a FAILED+=1
)

rem The right-click chain: forwarder -> impl -> --listTables -> -o export.
rem
rem This is the entry point designers actually use, and until now nothing
rem exercised it -- which is how it stayed broken (runtime lookup from the wrong
rem root) and how it silently deleted every other table's output for months.
rem Exporting one folder must produce that folder's tables AND leave the rest
rem of the output directory alone.
echo [EXAMPLE] right-click chain -- menu_entry_data.bat
if exist "!CONTEXTMENU_OUT!" rmdir /s /q "!CONTEXTMENU_OUT!"
call "%~dp0..\contextmenu\menu_entry_data.bat" "!EXAMPLE_ROOT!\DataTables\item" >nul 2>&1
if errorlevel 1 (
  echo [FAIL] right-click export returned !errorlevel!
  set /a FAILED+=1
) else (
  set RC_FILES=0
  for /f %%N in ('dir /b /s "!CONTEXTMENU_OUT!\*.json" 2^>nul ^| find /c /v ""') do set RC_FILES=%%N
  if "!RC_FILES!"=="0" (
    echo [FAIL] right-click export produced no files under !CONTEXTMENU_OUT!
    set /a FAILED+=1
  ) else (
    echo [OK]   right-click chain produced !RC_FILES! file^(s^)
  )
)

rem examples/release is the project users are told to copy: a Unity project,
rem its own luban.conf, and three targets each wanting its own directory.
rem Nothing exported it, so it rotted -- the checked-in generated code was
rem produced from an older table set and an older SimpleJSON namespace, and the
rem handwritten Main.cs still referenced a namespace and a data path that this
rem conf has not produced for a long time. It could not have compiled.
rem
rem Exporting it here to a scratch directory and diffing against the checked-in
rem copy makes the shipped example's own output its baseline: it can no longer
rem drift from the conf that is supposed to produce it.
echo [RELEASE] export all targets -- via gen_all.bat
if exist "!RELEASE_TMP!" rmdir /s /q "!RELEASE_TMP!"
call "!RELEASE_ROOT!\Tools\Luban\gen_all.bat" "!RELEASE_TMP!" >nul 2>&1
if errorlevel 1 (
  echo [FAIL] release export returned !errorlevel!
  set /a FAILED+=1
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "!COMPARE_PS1!" ^
    -BaselineDir "!RELEASE_ASSETS!\GenData" -OutputDir "!RELEASE_TMP!\GenData" ^
    -ReportPath "!RELEASE_ROOT!\TestOutputs\compare_report_data.json" -Label "release data"
  if errorlevel 1 set /a FAILED+=1
  powershell -NoProfile -ExecutionPolicy Bypass -File "!COMPARE_PS1!" ^
    -BaselineDir "!RELEASE_ASSETS!\GenCode" -OutputDir "!RELEASE_TMP!\GenCode" ^
    -ReportPath "!RELEASE_ROOT!\TestOutputs\compare_report_code.json" -Label "release code"
  if errorlevel 1 set /a FAILED+=1
)

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

powershell -NoProfile -ExecutionPolicy Bypass -File "!COMPARE_PS1!" ^
  -BaselineDir "!BASELINE_DIR_XML!" -OutputDir "!OUTPUT_DIR_XML!" ^
  -ReportPath "!COMPARE_REPORT_XML!" -Label "xml baseline"
if errorlevel 1 set /a FAILED+=1

powershell -NoProfile -ExecutionPolicy Bypass -File "!COMPARE_PS1!" ^
  -BaselineDir "!BASELINE_DIR_CODE!" -OutputDir "!OUTPUT_DIR_CODE!" ^
  -ReportPath "!COMPARE_REPORT_CODE!" -Label "code baseline"
if errorlevel 1 set /a FAILED+=1

rem The with-l10n export ran on every regression but was never compared --
rem only the no-l10n copy went to a baseline. Text-key substitution therefore
rem had zero coverage: if it silently stopped converting, nothing noticed.
rem The two outputs differ in 8 files (e.g. "/apple" -> "苹果"), so this
rem baseline is what keeps that path honest.
powershell -NoProfile -ExecutionPolicy Bypass -File "!COMPARE_PS1!" ^
  -BaselineDir "!BASELINE_DIR_L10N!" -OutputDir "!OUTPUT_DIR!" ^
  -ReportPath "!COMPARE_REPORT_L10N!" -Label "l10n baseline"
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

rem ---- helpers ----------------------------------------------------------
rem %1 pattern, %2 expected count, %3 human label
:CountErr
setlocal EnableDelayedExpansion
set "PATTERN=%~1"
set "WANT=%~2"
set "LABEL=%~3"
for /f %%N in ('findstr /c:"!PATTERN!" "!MAIN_LOG!" ^^^| find /c /v ""') do set "GOT=%%N"
if not "!GOT!"=="!WANT!" (
  echo        [!LABEL!] expected !WANT!, got !GOT!
  endlocal & set /a VALIDATOR_FAILED+=1
  exit /b 0
)
endlocal
exit /b 0
