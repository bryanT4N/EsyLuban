@echo off
setlocal EnableExtensions

rem ---------------------------------------------------------------
rem Run EsyLuban unit tests (B1Parser).
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

if not exist "%TEST_PROJ%" (
  echo [ERROR] Test project not found: %TEST_PROJ%
  exit /b 1
)

echo [TEST] %TEST_PROJ%
dotnet test "%TEST_PROJ%" --nologo
if errorlevel 1 (
  echo [ERROR] Unit tests failed.
  exit /b 1
)

echo.
echo [OK] Unit tests passed.
endlocal
