@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ---------------------------------------------------------------
rem Fail if any owned asset under esyluban/ is silently gitignored.
rem
rem The upstream .gitignore matches [Rr]elease/ at ANY depth. It has already
rem swallowed two directories without a word of warning:
rem   examples/release/   785 files
rem   scripts/release/      3 files
rem Both were only noticed by accident. git never reports what it ignored,
rem so the loss is invisible until someone clones and finds the files gone.
rem
rem This check enumerates the files we intend to track and asserts none of
rem them is ignored. It is cheap and catches the whole class, not one case.
rem
rem NOTE: keep this file ASCII-only. cmd parses .bat using the system
rem ANSI code page, so UTF-8 non-ASCII comments break execution.
rem ---------------------------------------------------------------

set ESY_ROOT=%~dp0..\..
set REPO_ROOT=%ESY_ROOT%\..
set FAILED=0

pushd "%REPO_ROOT%"

rem Directories whose contents must all be trackable.
for %%D in (
  "esyluban\scripts"
  "esyluban\templates"
  "esyluban\examples\dev\DataTables"
  "esyluban\examples\dev\Tools"
  "esyluban\examples\release\DataTables"
  "esyluban\examples\release\Tools"
  "esyluban\baselines"
  "esyluban\docs"
) do (
  if exist "%%~D" (
    for /f "usebackq delims=" %%F in (`git ls-files --others --ignored --exclude-standard "%%~D" 2^>nul`) do (
      echo [IGNORED] %%F
      set /a FAILED+=1
    )
  )
)

popd

if %FAILED% gtr 0 (
  echo.
  echo [FAIL] %FAILED% owned file^(s^) are silently gitignored.
  echo        Add a negation rule in esyluban\.gitignore, then re-run.
  echo        Diagnose one with:  git check-ignore -v ^<path^>
  exit /b 1
)

echo [OK] No owned file under esyluban/ is gitignored.
exit /b 0
