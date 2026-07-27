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
rem Single-group exports. Not baselined -- the assertion is about which fields
rem survive filtering, which a baseline would state far less legibly.
set OUTPUT_DIR_GROUP_C=%EXAMPLE_ROOT%\TestOutputs\group_client
set OUTPUT_DIR_GROUP_S=%EXAMPLE_ROOT%\TestOutputs\group_server
set BASELINE_DIR_XML=%ESY_ROOT%\baselines\xml
set BASELINE_DIR_CODE=%ESY_ROOT%\baselines\code_cs
set BASELINE_DIR_L10N=%ESY_ROOT%\baselines\json_l10n
set RELEASE_ROOT=%ESY_ROOT%\examples\release
set RELEASE_ASSETS=%RELEASE_ROOT%\Projects\Csharp_Unity_json\Assets
set RELEASE_TMP=%RELEASE_ROOT%\TestOutputs\gen_all
set COMPARE_REPORT_L10N=%EXAMPLE_ROOT%\TestOutputs\compare_report_l10n.json
set COMPARE_REPORT_XML=%EXAMPLE_ROOT%\TestOutputs\compare_report_xml.json
set COMPARE_REPORT_CODE=%EXAMPLE_ROOT%\TestOutputs\compare_report_code.json
set HARD_ROOT=%ESY_ROOT%\examples\negatives_hard
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
for %%D in ("!OUTPUT_DIR!" "!OUTPUT_DIR_NO_L10N!" "!NEGATIVE_OUTPUT_DIR!" "!OUTPUT_DIR_XML!" "!OUTPUT_DIR_CODE!" "!DEADX_OUT!") do (
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
  set /a CHECKS+=1
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
rem while another gained an error, and still add up to the same total.
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
set VALIDATOR_TOTAL=0
set RC_FAILED=0
set CHECKS=0
rem The count is asserted too: deleting an assertion cannot pass unnoticed.
rem
rem This counts decision points REACHED in a green run, not the total number of
rem assertions in the file -- a few failure-only paths (an export returning
rem non-zero, the negatives corpus missing) contribute nothing when everything
rem passes, which is the state this number is pinned to. Add or remove a check
rem and this number must move with it; the run reports INCONCLUSIVE until it does.
set EXPECTED_CHECKS=18
set DEADX_LOG=%EXAMPLE_ROOT%\TestOutputs\dead_xargs.log
set DEADX_OUT=%EXAMPLE_ROOT%\TestOutputs\dead_xargs_out

call :CountErr "matrix.TbPathFail"       1 "negatives: path validator"
call :CountErr "matrix.TbValidatorsFail" 4 "negatives: regex/default/range/set"
call :CountErr "matrix.TbCollectionsFail" 3 "negatives: ref/size/index"
call :CountErr "test.TbPath"             2 "upstream fixture test/path.xlsx"
call :CountErr "test.TbDataFromMisc"     1 "text key validator (invalid text id)"

rem Two failure classes that the shared corpus cannot host. The validators
rem above only LOG and let the run finish; a duplicate primary key or a
rem mode="one" table with more than one row THROWS and aborts everything, so
rem a single such record would take the whole regression down with it.
rem They live in examples/negatives_hard/, one tiny self-contained corpus each,
rem and are asserted the other way round: the run MUST fail, and it must fail
rem with the right message rather than for some unrelated reason.
rem
rem Duplicate primary key is the single most common mistake a designer makes in
rem Excel, so "Luban stops loudly" is worth holding in place with a test.
set HARD_FAILED=0
call :ExpectFail dup_key  "'hard.TbDupKey'" "hard: duplicate primary key"
call :ExpectFail mode_one "mode=one,"       "hard: mode=one with 2 rows"
if !HARD_FAILED! gtr 0 (
  echo [FAIL] hard-failure negatives: !HARD_FAILED! case^(s^) did not abort as expected
  set /a FAILED+=1
) else (
  echo [OK]   hard-failure negatives: both aborted with the expected message
  set /a CHECKS+=1
)

if !VALIDATOR_FAILED! gtr 0 (
  echo [FAIL] validator check: !VALIDATOR_FAILED! categor^(ies^) off; see !MAIN_LOG!
  echo        fewer =^> that validator family stopped running
  echo        more  =^> a new failure appeared
  set /a FAILED+=1
) else (
  echo [OK]   validator check: all !VALIDATOR_TOTAL! error categories as expected
  set /a CHECKS+=1
)

rem This run exports the negatives on purpose, under target "test" (group "t"),
rem so their output lands somewhere separate from the baselines. Note that the
rem group only isolates OUTPUT, not validation -- see the note above the
rem :CountErr calls. Do NOT additionally restrict
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

rem Every data baseline above comes from "-t all", which binds c/s/e -- so it
rem filters nothing but group "t", and field-level group filtering was never
rem compared against anything. Export two single-group targets and look inside.
echo [EXAMPLE] generate single-group outputs -- via gen.bat
call "!LUBAN_DIR!\gen.bat" -t client -d json -x outputDataDir="!OUTPUT_DIR_GROUP_C!"
if errorlevel 1 (
  echo [FAIL] client export returned !errorlevel!
  set /a FAILED+=1
)
call "!LUBAN_DIR!\gen.bat" -t server -d json -x outputDataDir="!OUTPUT_DIR_GROUP_S!"
if errorlevel 1 (
  echo [FAIL] server export returned !errorlevel!
  set /a FAILED+=1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check_group_filtering.ps1" ^
  "!OUTPUT_DIR_GROUP_C!" "!OUTPUT_DIR_GROUP_S!"
if errorlevel 1 set /a FAILED+=1
set /a CHECKS+=1

rem The right-click chain: forwarder -> impl -> --listTables -> -o export.
rem
rem This is the entry point designers actually use, and until now nothing
rem exercised it -- which is how it stayed broken (runtime lookup from the wrong
rem root) and how it silently deleted every other table's output for months.
rem Exporting one folder must produce that folder's tables AND leave the rest
rem of the output directory alone.
echo [EXAMPLE] right-click chain -- menu_entry_data.bat
rem Several folders, not one. Testing only item/ was how a real bug survived:
rem item's table carries no group, so it belongs to every group and exported
rem cleanly for every target -- the one folder in the corpus that could not
rem reveal the problem. Any folder whose tables DO carry a group (ai, matrix)
rem failed for the "test" target, whose group "t" excludes them, with a
rem confusing "referenced table was not exported" error.
set RC_TOTAL=0
call :RightClick item
call :RightClick ai
call :RightClick matrix
call :RightClick l10n

rem The impl script also runs standalone, without the forwarder passing it the
rem Tools\Luban directory -- it then searches upwards for luban.conf. That
rem branch is documented as the way to drive the export from a build script or
rem to debug it by hand, but nothing exercised it, so "documented" was the only
rem evidence it still worked. It does; this keeps it that way.
call :RightClickDirect item

rem Inline schema sheets (a __beans__ / __enums__ sheet living next to the data
rem in the same workbook) are the recommended way to declare a nested bean. They
rem carry ##export in A1 and nothing in B1, exactly like a table someone forgot
rem to fill in -- so the table importer used to warn once per such file. The
rem warning was pure noise on the recommended layout, which is the fastest way
rem to teach people to ignore warnings. Assert it stays quiet, while the same
rem warning still fires for the files it is actually meant for (l10n text tables,
rem XML-defined tables, continuation shards).
findstr /c:"__beans__" /c:"__enums__" "!MAIN_LOG!" | findstr /c:"no table metadata in B1" >nul
if errorlevel 1 (
  findstr /c:"no table metadata in B1" "!MAIN_LOG!" >nul
  if errorlevel 1 (
    echo [FAIL] inline-schema check: the B1 warning never fires at all now
    set /a FAILED+=1
  ) else (
    echo [OK]   inline-schema sheets silent, B1 warning still fires where it should
    set /a CHECKS+=1
  )
) else (
  echo [FAIL] inline-schema __beans__/__enums__ sheets still warn about missing B1
  set /a FAILED+=1
)

rem A xargs key prefixed with a TABLE target name never takes effect -- the
rem namespace comes from dataTarget/codeTarget. Luban used to accept such keys
rem in complete silence, which is exactly how ten dead lines survived in this
rem repo's own release example for months. Luban now warns; assert both
rem directions, because a warning that never fires and one that always fires
rem are equally useless.
rem Exports to its own directory on purpose. It used to reuse OUTPUT_DIR_NO_L10N,
rem which is exactly what the core and coverage baselines are compared against --
rem so those two baselines were silently verifying THIS probe's output rather than
rem the clean gen.bat export above. The parameters happened to be equivalent, so
rem nothing broke; changing one line here would have moved the goalposts of the
rem two most important baselines without a word of warning.
"!LUBAN_EXE!" --conf "!CONF_FILE!" -t all -d json ^
  -x outputDataDir="!DEADX_OUT!" ^
  -x client.outputDataDir="!DEADX_OUT!" > "!DEADX_LOG!" 2>&1
findstr /c:"[dead xargs]" "!DEADX_LOG!" >nul
if errorlevel 1 (
  echo [FAIL] dead-xargs warning did not fire for a table-target-prefixed key
  set /a FAILED+=1
) else (
  findstr /c:"[dead xargs]" "!MAIN_LOG!" >nul
  if errorlevel 1 (
    echo [OK]   dead-xargs warning: fires on a dead key, silent on a clean conf
    set /a CHECKS+=1
  ) else (
    echo [FAIL] dead-xargs warning fired on the normal export, which has no dead keys
    set /a FAILED+=1
  )
)
if !RC_FAILED! gtr 0 (
  echo [FAIL] right-click chain: !RC_FAILED! folder^(s^) failed
  set /a FAILED+=1
) else (
  echo [OK]   right-click chain: 4 folders + standalone entry, !RC_TOTAL! file^(s^) total
  set /a CHECKS+=1
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
  set /a CHECKS+=1
  powershell -NoProfile -ExecutionPolicy Bypass -File "!COMPARE_PS1!" ^
    -BaselineDir "!RELEASE_ASSETS!\GenCode" -OutputDir "!RELEASE_TMP!\GenCode" ^
    -ReportPath "!RELEASE_ROOT!\TestOutputs\compare_report_code.json" -Label "release code"
  if errorlevel 1 set /a FAILED+=1
  set /a CHECKS+=1
)

rem core/ is upstream's own output: we legitimately have more tables than it
rem (matrix/, minimal_b1). Missing or differing files are still failures --
rem only extras are exempt, and the exemption is stated rather than hidden.
powershell -NoProfile -ExecutionPolicy Bypass -File "!COMPARE_PS1!" ^
  -BaselineDir "!BASELINE_DIR_CORE!" -OutputDir "!OUTPUT_DIR_NO_L10N!" ^
  -ReportPath "!COMPARE_REPORT_CORE!" -Label "core baseline" -AllowExtra
if errorlevel 1 set /a FAILED+=1
set /a CHECKS+=1

powershell -NoProfile -ExecutionPolicy Bypass -File "!COMPARE_PS1!" ^
  -BaselineDir "!BASELINE_DIR_COVERAGE!" -OutputDir "!OUTPUT_DIR_NO_L10N!" ^
  -ReportPath "!COMPARE_REPORT_COVERAGE!" -Label "coverage baseline"
if errorlevel 1 set /a FAILED+=1
set /a CHECKS+=1

powershell -NoProfile -ExecutionPolicy Bypass -File "!COMPARE_PS1!" ^
  -BaselineDir "!BASELINE_DIR_XML!" -OutputDir "!OUTPUT_DIR_XML!" ^
  -ReportPath "!COMPARE_REPORT_XML!" -Label "xml baseline"
if errorlevel 1 set /a FAILED+=1
set /a CHECKS+=1

powershell -NoProfile -ExecutionPolicy Bypass -File "!COMPARE_PS1!" ^
  -BaselineDir "!BASELINE_DIR_CODE!" -OutputDir "!OUTPUT_DIR_CODE!" ^
  -ReportPath "!COMPARE_REPORT_CODE!" -Label "code baseline"
if errorlevel 1 set /a FAILED+=1
set /a CHECKS+=1

rem The with-l10n export ran on every regression but was never compared --
rem only the no-l10n copy went to a baseline. Text-key substitution therefore
rem had zero coverage: if it silently stopped converting, nothing noticed.
rem The two outputs differ in 8 files (e.g. "/apple" -> "苹果"), so this
rem baseline is what keeps that path honest.
powershell -NoProfile -ExecutionPolicy Bypass -File "!COMPARE_PS1!" ^
  -BaselineDir "!BASELINE_DIR_L10N!" -OutputDir "!OUTPUT_DIR!" ^
  -ReportPath "!COMPARE_REPORT_L10N!" -Label "l10n baseline"
if errorlevel 1 set /a FAILED+=1
set /a CHECKS+=1

rem Owned files silently swallowed by .gitignore are invisible until someone
rem clones. Cheap to check, and it has already caught two real losses.
rem Two guards that turn a promise into an assertion.
rem
rem The upstream boundary ("we only add to upstream, never modify it") was a
rem sentence in the README maintained by memory -- and it had already gone stale
rem by one file. The three copies of gen.bat were held together by nothing at all
rem after the sync script was deleted, and the copy that ships to users is the
rem one no test runs.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check_upstream_boundary.ps1"
if errorlevel 1 set /a FAILED+=1
set /a CHECKS+=1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check_tool_copies.ps1"
if errorlevel 1 set /a FAILED+=1
set /a CHECKS+=1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check_doc_facts.ps1"
if errorlevel 1 set /a FAILED+=1
set /a CHECKS+=1

rem The Defines XML files lost all 10 of their comments to a parse/serialize
rem round trip during the migration, and nothing noticed: comments do not affect
rem export, so every baseline stayed green. Three were restored; this asserts
rem they stay, and that no <table> declaration creeps back into these files.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check_xml_comments.ps1"
if errorlevel 1 set /a FAILED+=1
set /a CHECKS+=1


call "%~dp0check_gitignore_traps.bat"
if errorlevel 1 set /a FAILED+=1
set /a CHECKS+=1

echo.
if !FAILED! gtr 0 (
  echo ==========================================
  echo   REGRESSION FAILED - !FAILED! check^(s^) failed
  echo ==========================================
  exit /b 1
)
echo ==========================================
if not "!CHECKS!"=="!EXPECTED_CHECKS!" (
  echo   REGRESSION INCONCLUSIVE - ran !CHECKS! checks, expected !EXPECTED_CHECKS!
  echo   An assertion was added or removed without updating EXPECTED_CHECKS.
  echo   A regression whose size nobody tracks can lose a check silently.
  echo ==========================================
  exit /b 1
)
echo   REGRESSION PASSED - !CHECKS!/!EXPECTED_CHECKS! checks
echo ==========================================
exit /b 0

rem ---- helpers ----------------------------------------------------------
rem %1 pattern, %2 expected count, %3 human label
:RightClickDirect
rem Same as :RightClick but calls the implementation directly, with no second
rem argument, so the upward search for Tools\Luban is what has to find the conf.
setlocal EnableDelayedExpansion
if exist "!CONTEXTMENU_OUT!" rmdir /s /q "!CONTEXTMENU_OUT!"
call "%~dp0..\contextmenu\run_luban_context_menu_data.bat" "!EXAMPLE_ROOT!\DataTables\%~1" >nul 2>&1
if errorlevel 1 (
  echo        [standalone %~1] export returned a failure
  endlocal & set /a RC_FAILED+=1
  exit /b 0
)
set RC_N=0
for /f %%N in ('dir /b /s "!CONTEXTMENU_OUT!\*.json" 2^>nul ^| find /c /v ""') do set RC_N=%%N
if "!RC_N!"=="0" (
  echo        [standalone %~1] produced no files
  endlocal & set /a RC_FAILED+=1
  exit /b 0
)
endlocal & set /a RC_TOTAL+=%RC_N%
exit /b 0

:RightClick
rem %1 = folder under DataTables. Exporting it must succeed AND produce files.
setlocal EnableDelayedExpansion
set "FOLDER=%~1"
if exist "!CONTEXTMENU_OUT!" rmdir /s /q "!CONTEXTMENU_OUT!"
call "%~dp0..\contextmenu\menu_entry_data.bat" "!EXAMPLE_ROOT!\DataTables\!FOLDER!" >nul 2>&1
if errorlevel 1 (
  echo        [right-click !FOLDER!] export returned a failure
  endlocal & set /a RC_FAILED+=1
  exit /b 0
)
set RC_N=0
for /f %%N in ('dir /b /s "!CONTEXTMENU_OUT!\*.json" 2^>nul ^| find /c /v ""') do set RC_N=%%N
if "!RC_N!"=="0" (
  echo        [right-click !FOLDER!] produced no files
  endlocal & set /a RC_FAILED+=1
  exit /b 0
)
endlocal & set /a RC_TOTAL+=%RC_N%
exit /b 0

:ExpectFail
rem %1 conf base name under negatives_hard, %2 required ASCII fragment, %3 label
rem Passing is a NON-ZERO exit plus that fragment in the log. Checking only the
rem exit code would let any unrelated crash count as a pass.
setlocal EnableDelayedExpansion
set "HCONF=%~1"
set "FRAG=%~2"
set "LABEL=%~3"
set "HLOG=!HARD_ROOT!\TestOutputs\!HCONF!.log"
if not exist "!HARD_ROOT!\TestOutputs" mkdir "!HARD_ROOT!\TestOutputs"
pushd "!HARD_ROOT!\Tools\Luban"
"!LUBAN_EXE!" --conf "!HCONF!.conf" -t all -d json > "!HLOG!" 2>&1
set "HCODE=!errorlevel!"
popd
if "!HCODE!"=="0" (
  echo        [!LABEL!] expected a non-zero exit, got 0
  endlocal & set /a HARD_FAILED+=1
  exit /b 0
)
findstr /c:"!FRAG!" "!HLOG!" >nul
if errorlevel 1 (
  echo        [!LABEL!] aborted, but without the expected message; see !HLOG!
  endlocal & set /a HARD_FAILED+=1
  exit /b 0
)
endlocal
exit /b 0

:CountErr
setlocal EnableDelayedExpansion
set "PATTERN=%~1"
set "WANT=%~2"
set "LABEL=%~3"
for /f %%N in ('findstr /c:"!PATTERN!" "!MAIN_LOG!" ^^^| find /c /v ""') do set "GOT=%%N"
if not "!GOT!"=="!WANT!" (
  echo        [!LABEL!] expected !WANT!, got !GOT!
  endlocal & set /a VALIDATOR_FAILED+=1 & set /a VALIDATOR_TOTAL+=1
  exit /b 0
)
endlocal & set /a VALIDATOR_TOTAL+=1
exit /b 0
