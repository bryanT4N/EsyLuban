@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ---------------------------------------------------------------
rem Run EsyLuban unit tests.
rem
rem Luban.Tests is intentionally NOT added to the upstream Luban.sln:
rem the project targets that solution file, and keeping our test project
rem out of it avoids one more upstream file to reconcile on every rebase.
rem dotnet test accepts a project path directly, so a solution entry is
rem not needed.
rem
rem NOTE: keep this file ASCII-only. cmd parses .bat using the system
rem ANSI code page, so UTF-8 non-ASCII comments break execution.
rem ---------------------------------------------------------------

set ESY_ROOT=%~dp0..\..
set REPO_ROOT=%ESY_ROOT%\..
set TEST_PROJ=%REPO_ROOT%\src\Luban.Tests\Luban.Tests.csproj
set MIGRATE_TESTS=%ESY_ROOT%\scripts\authoring\test_migrate_xlsx.py

if not exist "%TEST_PROJ%" (
  echo [ERROR] Test project not found: !TEST_PROJ!
  exit /b 1
)

echo [TEST] B1Parser
dotnet test "%TEST_PROJ%" --nologo
if errorlevel 1 (
  echo [ERROR] Unit tests failed.
  exit /b 1
)

rem The migration tool's tests, when Python is available.
rem
rem migrate_xlsx.py rewrites spreadsheets in place -- no backup, no dry run. Its
rem tests were sitting in the tree with nothing running them, which for a tool
rem that destructive is the wrong thing to leave to someone remembering.
rem
rem These are optional: without the toolchain they are skipped rather than
rem failing the run, since the tool itself is disabled and on nobody's critical
rem path.
rem
rem Probe for what is ACTUALLY required (openpyxl), not for a proxy. The first
rem cut checked `where python` and skipped on that -- which held on a machine
rem with no Python at all, and broke on GitHub's Windows runner, where Python is
rem present but openpyxl is not. CI then failed here every run, and because this
rem step gates the one after it, the full regression never executed at all.
rem Both python invocations go through `call`. Without it, a `python` that
rem resolves to a .bat shim -- which is how pyenv-win and several conda wrappers
rem provide it -- would transfer control and never come back, silently ending
rem this script mid-run. `call` is correct for a real .exe too.
call python -c "import openpyxl" >nul 2>&1
if errorlevel 1 (
  echo [SKIP] migration tests: python with openpyxl not available
  echo        install with: pip install openpyxl
) else (
  echo [TEST] migrate_xlsx
  call python "%MIGRATE_TESTS%"
  if errorlevel 1 (
    echo [ERROR] Migration tests failed.
    exit /b 1
  )
)

echo.
echo [OK] Unit tests passed.
endlocal
