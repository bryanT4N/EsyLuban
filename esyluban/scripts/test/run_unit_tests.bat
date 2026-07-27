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
rem Python is optional: without it these are skipped rather than failing the run,
rem since the tool itself is disabled and on nobody's critical path.
where python >nul 2>&1
if errorlevel 1 (
  echo [SKIP] migration tests: python not on PATH
) else (
  echo [TEST] migrate_xlsx
  python "%MIGRATE_TESTS%"
  if errorlevel 1 (
    echo [ERROR] Migration tests failed.
    exit /b 1
  )
)

echo.
echo [OK] Unit tests passed.
endlocal
