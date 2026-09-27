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
set CODE_DIR_GROUP_C=%EXAMPLE_ROOT%\TestOutputs\group_code_client
set CODE_DIR_GROUP_S=%EXAMPLE_ROOT%\TestOutputs\group_code_server
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
set LIST_ROOT=%ESY_ROOT%\examples\listing_scope
set LANG_ROOT=%ESY_ROOT%\examples\languages
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
rem the strict flag was added.
rem
rem A non-zero exit alone proves nothing. When Luban 5 renamed that flag to
rem --strict, check.bat kept passing the old name, every run died on "unknown
rem option" before loading a single table, and this check stayed green. So it
rem also demands the path validator's complaint about the negatives corpus,
rem which only a run that actually validated can print.
set CHECK_LOG=%EXAMPLE_ROOT%\TestOutputs\check_bat.log
echo [EXAMPLE] check.bat must reject the corpus (it contains deliberate negatives)
call "!LUBAN_DIR!\check.bat" -t all > "!CHECK_LOG!" 2>&1
if errorlevel 1 (
  findstr /c:"matrix.TbPathFail" "!CHECK_LOG!" >nul
  if errorlevel 1 (
    echo [FAIL] check.bat exited non-zero, but not because validation failed
    echo        see !CHECK_LOG!
    set /a FAILED+=1
  ) else (
    echo [OK]   check.bat correctly rejected the corpus
    set /a CHECKS+=1
  )
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
rem --strict is deliberately NOT used here: the corpus contains
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
set EXPECTED_CHECKS=21
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
rem with the right error rather than for some unrelated reason.
rem
rem Duplicate primary key is the single most common mistake a designer makes in
rem Excel, so "Luban stops loudly" is worth holding in place with a test.
rem
rem same_name holds two B1 tables with one full_name, which EsyLuban reports
rem with every place named (upstream names one).
rem
rem The rest guard multi-language projects: l10n.languages plus variant_<lang>
rem folders. b1_variant and variants_key write variant= / variants= in B1, which
rem the folders replaced; ignored silently, the designer would never learn why
rem the English data does not show. variant_dup repeats a key inside one
rem language's variant, which upstream's patch merge rejects. Then EsyLuban's
rem own checks on the layout: a variant whose mode differs from the default's,
rem a variant table with no default version, a folder for an undeclared
rem language, a variant_ folder inside another, and a folder for the default
rem language -- never read, so edits there would vanish without a word.
rem duplicate_language lists a language twice. forgot_languages has a variant_en
rem folder but no l10n.languages: a project that never declared languages must
rem see variant_ folders as ordinary folders (so upgrading changes nothing for
rem it), which makes the copy collide with the default; the unit tests pin that
rem this error tells them to declare the language. strict_en fails validation in
rem the English run only: --strict must fail the export although the default
rem run was clean, and so must check.bat's -f --strict, which exports nothing
rem and once validated the default language alone. Matching the esyluban.*
rem codes also proves those codes reach the JSON report instead of being
rem swallowed.
set HARD_FAILED=0
set HARD_TOTAL=0
call :ExpectFail dup_key             "error.data.duplicate_key"             "hard: duplicate primary key"
call :ExpectFail mode_one            "error.data.singleton_count"           "hard: mode=one with 2 rows"
call :ExpectFail same_name           "esyluban.b1.duplicate_full_name"      "hard: two B1 tables with one name"
call :ExpectFail b1_variant          "esyluban.b1.variant_key"              "hard: variant= in B1"
call :ExpectFail variants_key        "esyluban.b1.variant_key"              "hard: variants= in B1"
call :ExpectFail variant_dup         "error.data.patch_override_multiple"   "hard: one key twice in a variant"
call :ExpectFail variant_mismatch    "esyluban.b1.variant_mismatch"         "hard: variant with another mode"
call :ExpectFail no_default          "esyluban.variant.no_default"          "hard: variant without a default"
call :ExpectFail undeclared_language "esyluban.variant.undeclared_language" "hard: variant_fr not declared"
call :ExpectFail nested              "esyluban.variant.nested"              "hard: variant_ inside variant_"
call :ExpectFail default_language    "esyluban.variant.default_language"    "hard: variant_ of the default language"
call :ExpectFail duplicate_language  "esyluban.l10n.duplicate_language"     "hard: a language listed twice"
call :ExpectFail forgot_languages    "esyluban.b1.duplicate_full_name"      "hard: variant_en without l10n.languages"
call :ExpectFail strict_en           "error.cli.validation_fail"            "hard: --strict, only en invalid" "-d json --strict"
call :ExpectFail strict_en           "error.cli.validation_fail"            "hard: check.bat, only en invalid" "-f --strict"
if !HARD_FAILED! gtr 0 (
  echo [FAIL] hard-failure negatives: !HARD_FAILED! of !HARD_TOTAL! case^(s^) did not abort as expected
  set /a FAILED+=1
) else (
  echo [OK]   hard-failure negatives: all !HARD_TOTAL! aborted with the expected error
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

rem Every baseline above comes from "-t all", which binds c/s/e -- so it filters
rem nothing but group "t", and group's actual job was never compared against
rem anything. Export two single-group targets, data AND code, and look inside.
rem
rem Code as well as data, because group shapes both and they are separate code
rem paths: the data side drops fields from the json, the code side drops whole
rem table classes and the matching members from the bean classes.
echo [EXAMPLE] generate single-group outputs -- via gen.bat
call "!LUBAN_DIR!\gen.bat" -t client -d json -c cs-simple-json ^
  -x outputDataDir="!OUTPUT_DIR_GROUP_C!" -x outputCodeDir="!CODE_DIR_GROUP_C!"
if errorlevel 1 (
  echo [FAIL] client export returned !errorlevel!
  set /a FAILED+=1
)
call "!LUBAN_DIR!\gen.bat" -t server -d json -c cs-simple-json ^
  -x outputDataDir="!OUTPUT_DIR_GROUP_S!" -x outputCodeDir="!CODE_DIR_GROUP_S!"
if errorlevel 1 (
  echo [FAIL] server export returned !errorlevel!
  set /a FAILED+=1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check_group_filtering.ps1" ^
  "!OUTPUT_DIR_GROUP_C!" "!OUTPUT_DIR_GROUP_S!" ^
  "!CODE_DIR_GROUP_C!" "!CODE_DIR_GROUP_S!"
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
rem Matched on its [empty B1] tag: the text follows the Windows display language.
findstr /c:"__beans__" /c:"__enums__" "!MAIN_LOG!" | findstr /c:"[empty B1]" >nul
if errorlevel 1 (
  findstr /c:"[empty B1]" "!MAIN_LOG!" >nul
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

rem --listTables must answer "which tables are in this selection" and nothing
rem more. It used to resolve table variants on a partial view -- B1 tables from
rem the selection, XML tables from everywhere -- which broke the workaround the
rem docs recommend for per-region tables (default version in B1, the others in
rem XML with variant=). Right-clicking any other folder then aborted with "no
rem fallback", because the B1 default was outside the selection; with --variant
rem set, the XML table leaked into every right-click instead. A half-migrated
rem project had the same leak: its XML / __tables__ tables were exported on
rem every right-click, whatever was selected.
rem examples/listing_scope holds that layout: TbItem (B1 default + XML en),
rem TbOther (B1, own folder), TbLegacy (XML only). Run without --variant, the
rem case that used to abort.
set LIST_FAILED=0
pushd "!LIST_ROOT!\Tools\Luban"
call :ExpectListing "../../DataTables/other"         "scope.TbOther"  LIST_FAILED
call :ExpectListing "../../DataTables/items.xlsx"    "scope.TbItem"   LIST_FAILED
call :ExpectListing "../../DataTables/items_en.xlsx" "scope.TbItem"   LIST_FAILED
call :ExpectListing "../../DataTables/legacy"        "scope.TbLegacy" LIST_FAILED
rem Skipping variant resolution must not also skip the duplicate checks that
rem come with it: dup.conf adds a second TbLegacy with no variant. Caught only
rem at export, it would fail once per target under a hint about groups.
set "LDUP=!LIST_ROOT!\TestOutputs\listing_dup.log"
"!LUBAN_EXE!" --conf dup.conf -t all --listTables "../../DataTables/other" --errorFormat json > "!LDUP!" 2>&1
if errorlevel 1 (
  findstr /c:"error.def.table.variant_fallback_duplicate" "!LDUP!" >nul
  if errorlevel 1 (
    echo        [listing duplicate] aborted, but not for the duplicate; see !LDUP!
    set /a LIST_FAILED+=1
  )
) else (
  echo        [listing duplicate] a second TbLegacy without variant was not reported
  set /a LIST_FAILED+=1
)
popd
if !LIST_FAILED! gtr 0 (
  echo [FAIL] listing scope: !LIST_FAILED! case^(s^) wrong
  set /a FAILED+=1
) else (
  echo [OK]   listing scope: each selection lists only its own tables; duplicates still stop it
  set /a CHECKS+=1
)

rem Multi-language projects. examples/languages declares l10n.languages=zh,en
rem and keeps what English does differently in variant_en folders: rows that
rem override by primary key (TbItem 2) or add keys (TbItem 9001), a singleton
rem (TbMotd) and a list table (TbNews) replaced whole, a table only English
rem fills (TbEvent, empty by default), and a text table whose variant_en
rem overrides one key and adds another. TbDrop's English row refers to the
rem English-only item, so passing --strict proves validation saw the merged
rem table. One export writes TestOutputs\data (zh) and TestOutputs\data\en.
rem
rem The second export plants a stale file in each directory, and both must go.
rem Each language cleans its own directory; the default language's cleanup must
rem neither delete data\en nor refuse to run because of it. A refusal leaves
rem data\stale.json behind, a deletion makes the English run write [new] files.
set LANG_FAILED=0
if exist "!LANG_ROOT!\TestOutputs" rmdir /s /q "!LANG_ROOT!\TestOutputs"
mkdir "!LANG_ROOT!\TestOutputs"
set "LANG_DATA=!LANG_ROOT!\TestOutputs\data"
set "LANG_LOG=!LANG_ROOT!\TestOutputs\export.log"
set "LANG_LOG2=!LANG_ROOT!\TestOutputs\export_again.log"
pushd "!LANG_ROOT!\Tools\Luban"
"!LUBAN_EXE!" --conf luban.conf -t all -d json -c cs-simple-json --strict > "!LANG_LOG!" 2>&1
if errorlevel 1 (
  echo        [languages] export failed; see !LANG_LOG!
  set /a LANG_FAILED+=1
)
popd
call :ExpectText "demo_tbitem.json"     "shield"            "lantern-en"
call :ExpectText "en\demo_tbitem.json"  "buckler-en"        "shield"
call :ExpectText "en\demo_tbitem.json"  "lantern-en"        ""
call :ExpectText "demo_tbmotd.json"     "welcome"           ""
call :ExpectText "en\demo_tbmotd.json"  "hello-en"          "welcome"
call :ExpectText "demo_tbnews.json"     "news-a"            "headline-en"
call :ExpectText "en\demo_tbnews.json"  "headline-en"       "news-a"
call :ExpectText "demo_tbevent.json"    ""                  "event-en"
call :ExpectText "en\demo_tbevent.json" "event-en"          ""
call :ExpectText "demo_tbnamed.json"    "text-shield-zh"    "text-lantern-en"
call :ExpectText "en\demo_tbnamed.json" "text-sword-en"     "text-shield-en"
call :ExpectText "en\demo_tbnamed.json" "special-shield-en" ""
call :ExpectText "en\demo_tbnamed.json" "text-lantern-en"   ""
rem Code does not depend on the language: begin + end of one code target.
set LANG_CODE_LINES=0
for /f %%N in ('findstr /l /c:"process code target" "!LANG_LOG!" ^| find /c /v ""') do set LANG_CODE_LINES=%%N
if not "!LANG_CODE_LINES!"=="2" (
  echo        [languages] code target logged !LANG_CODE_LINES! lines instead of 2; code must be generated once
  set /a LANG_FAILED+=1
)
if exist "!LANG_DATA!\en" (
  echo stale> "!LANG_DATA!\stale.json"
  echo stale> "!LANG_DATA!\en\stale.json"
)
pushd "!LANG_ROOT!\Tools\Luban"
"!LUBAN_EXE!" --conf luban.conf -t all -d json > "!LANG_LOG2!" 2>&1
if errorlevel 1 (
  echo        [languages] second export failed; see !LANG_LOG2!
  set /a LANG_FAILED+=1
)
popd
if exist "!LANG_DATA!\stale.json" (
  echo        [languages] data\stale.json survived: the default language did not clean up
  set /a LANG_FAILED+=1
)
if exist "!LANG_DATA!\en\stale.json" (
  echo        [languages] data\en\stale.json survived: English did not clean up
  set /a LANG_FAILED+=1
)
findstr /l /c:"[new]" "!LANG_LOG2!" >nul
if not errorlevel 1 (
  echo        [languages] the second export wrote new files: the default language deleted data\en; see !LANG_LOG2!
  set /a LANG_FAILED+=1
)
rem One text table per language instead of one column per language: the
rem default text table has only a zh column and English keeps its whole table
rem in variant_en, so the English run must not demand an en column from it.
set "LANG_DATA=!LANG_ROOT!\TestOutputs\per_language_text"
pushd "!LANG_ROOT!\Tools\Luban"
"!LUBAN_EXE!" --conf per_language_text.conf -t all -d json > "!LANG_DATA!.log" 2>&1
if errorlevel 1 (
  echo        [languages] export with one text table per language failed; see !LANG_DATA!.log
  set /a LANG_FAILED+=1
)
popd
call :ExpectText "demo_tbnamed.json"    "per-sword-zh" "per-sword-en"
call :ExpectText "en\demo_tbnamed.json" "per-sword-en" "per-sword-zh"
set "LANG_DATA=!LANG_ROOT!\TestOutputs\data"
if !LANG_FAILED! gtr 0 (
  echo [FAIL] languages: !LANG_FAILED! case^(s^) wrong
  set /a FAILED+=1
) else (
  echo [OK]   languages: data and data\en from one export, variants merged, code once, each cleans its own, text per column or per table
  set /a CHECKS+=1
)

rem What one right-click exports in a multi-language project: what is selected
rem or inside the clicked folder, in every language it affects. A default table
rem affects every language, a table in variant_en only English, and a text
rem table every table (texts are replaced at export). The listing writes these
rem as table, table@en and * -- a text table must not put hundreds of -o on the
rem command line.
set LCLICK_FAILED=0
pushd "!LANG_ROOT!\Tools\Luban"
call :ExpectListing "../../DataTables/item/variant_en" "demo.TbItem@en" LCLICK_FAILED
call :ExpectListing "../../DataTables/l10n/variant_en" "*@en"           LCLICK_FAILED
popd
call :ExpectLanguageClick "item\variant_en\items.xlsx" "en\demo_tbitem.json"                      "demo_tbitem.json en\demo_tbother.json"
call :ExpectLanguageClick "item"                       "demo_tbitem.json en\demo_tbitem.json"     "demo_tbother.json en\demo_tbother.json"
call :ExpectLanguageClick "l10n\variant_en\texts.xlsx" "en\demo_tbnamed.json en\demo_tbother.json" "demo_tbnamed.json demo_tbother.json"
if !LCLICK_FAILED! gtr 0 (
  echo [FAIL] languages right-click: !LCLICK_FAILED! case^(s^) wrong
  set /a FAILED+=1
) else (
  echo [OK]   languages right-click: selection and the languages it affects, nothing more
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
rem %1 conf base name under negatives_hard, %2 required error code, %3 label,
rem %4 arguments in place of the default -d json (optional).
rem Passing is a NON-ZERO exit plus that error code in the log. Checking only the
rem exit code would let any unrelated crash count as a pass.
rem
rem Match the code, not the message. Luban 5 localizes messages and reworded
rem them: the zh singleton message now puts a full-width comma after mode=one,
rem so the old ASCII fragment "mode=one," failed on a Chinese Windows while an
rem English runner sailed through. --errorFormat json reports the stable
rem message key, which is ASCII and the same in every language.
set /a HARD_TOTAL+=1
setlocal EnableDelayedExpansion
set "HCONF=%~1"
set "FRAG=%~2"
set "LABEL=%~3"
set "HARGS=%~4"
if "!HARGS!"=="" set "HARGS=-d json"
set "HLOG=!HARD_ROOT!\TestOutputs\!HCONF!.log"
if not exist "!HARD_ROOT!\TestOutputs" mkdir "!HARD_ROOT!\TestOutputs"
pushd "!HARD_ROOT!\Tools\Luban"
"!LUBAN_EXE!" --conf "!HCONF!.conf" -t all --errorFormat json !HARGS! > "!HLOG!" 2>&1
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

:ExpectListing
rem Run from a corpus's Tools\Luban. %1 selection relative to it, %2 the one
rem table it must list, %3 the counter to bump on failure. Exit 0 and exactly
rem that line on stdout (logs go to stderr).
setlocal EnableDelayedExpansion
set "SEL=%~1"
set "WANT=%~2"
set "LDIR=%CD%\..\..\TestOutputs"
if not exist "!LDIR!" mkdir "!LDIR!"
set "LOUT=!LDIR!\listing.txt"
set "LERR=!LDIR!\listing_err.log"
"!LUBAN_EXE!" --conf luban.conf -t all --listTables "!SEL!" > "!LOUT!" 2> "!LERR!"
if errorlevel 1 (
  echo        [listing !SEL!] aborted, expected !WANT!; see !LERR!
  endlocal & set /a %~3+=1
  exit /b 0
)
set "GOT="
for /f "usebackq delims=" %%L in ("!LOUT!") do set "GOT=!GOT! %%L"
if not "!GOT!"==" !WANT!" (
  echo        [listing !SEL!] expected !WANT!, got!GOT!
  endlocal & set /a %~3+=1
  exit /b 0
)
endlocal
exit /b 0

:ExpectText
rem %1 file under languages\TestOutputs\data, %2 text it must contain (empty:
rem only that it was exported), %3 text it must not contain (empty to skip).
setlocal EnableDelayedExpansion
set "TFILE=!LANG_DATA!\%~1"
if not exist "!TFILE!" (
  echo        [languages] %~1 was not exported
  endlocal & set /a LANG_FAILED+=1
  exit /b 0
)
if not "%~2"=="" (
  findstr /l /c:"%~2" "!TFILE!" >nul
  if errorlevel 1 (
    echo        [languages] %~1 does not contain %~2
    endlocal & set /a LANG_FAILED+=1
    exit /b 0
  )
)
if not "%~3"=="" (
  findstr /l /c:"%~3" "!TFILE!" >nul
  if not errorlevel 1 (
    echo        [languages] %~1 still contains %~3
    endlocal & set /a LANG_FAILED+=1
    exit /b 0
  )
)
endlocal
exit /b 0

:ExpectLanguageClick
rem %1 file or folder under languages\DataTables to right-click, through the
rem same implementation script users run. %2 files that must come out, %3 files
rem that must not; space-separated, relative to the right-click output folder.
setlocal EnableDelayedExpansion
set "CDIR=!LANG_ROOT!\TestOutputs\contextmenu"
set "CLOG=!LANG_ROOT!\TestOutputs\click.log"
if exist "!CDIR!" rmdir /s /q "!CDIR!"
call "%~dp0..\contextmenu\run_luban_context_menu_data.bat" "!LANG_ROOT!\DataTables\%~1" > "!CLOG!" 2>&1
if errorlevel 1 (
  echo        [right-click %~1] export failed; see !CLOG!
  endlocal & set /a LCLICK_FAILED+=1
  exit /b 0
)
set "WRONG="
for %%F in (%~2) do if not exist "!CDIR!\%%F" set "WRONG=!WRONG! missing:%%F"
for %%F in (%~3) do if exist "!CDIR!\%%F" set "WRONG=!WRONG! extra:%%F"
if defined WRONG (
  echo        [right-click %~1]!WRONG!
  endlocal & set /a LCLICK_FAILED+=1
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
