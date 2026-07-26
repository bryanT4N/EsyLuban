@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ---------------------------------------------------------------
rem Build the Luban runtime from upstream src/ into esyluban/runtime/
rem
rem The runtime is NOT under version control, so this script must be
rem run once after cloning, before the context menu or any project's
rem gen.bat / check.bat can locate Luban.dll.
rem
rem src/Luban/Luban.csproj references all 22 plugin projects, so
rem publishing that single project yields the complete runtime
rem (including every language code generator).
rem
rem NOTE: keep this file ASCII-only. cmd parses .bat using the system
rem ANSI code page, so UTF-8 non-ASCII comments break execution.
rem ---------------------------------------------------------------

set ESY_ROOT=%~dp0..
set REPO_ROOT=%ESY_ROOT%\..
set PROJ=%REPO_ROOT%\src\Luban\Luban.csproj

rem Two runtime flavours:
rem   (default)         framework-dependent, ~6 MB, needs .NET 8 on the machine
rem   --self-contained  bundles the runtime, ~76 MB, runs with nothing installed
rem They go to separate directories so both can exist side by side and
rem make_release.bat can package either without rebuilding the other.
set OUT_DIR=%ESY_ROOT%\runtime
set PUB_ARGS=
set FLAVOUR=framework-dependent
if /i "%~1"=="--self-contained" (
  set OUT_DIR=!ESY_ROOT!\runtime-sc
  set PUB_ARGS=-r win-x64 --self-contained true
  set FLAVOUR=self-contained win-x64
)

if not exist "%PROJ%" (
  echo [ERROR] Main project not found: !PROJ!
  exit /b 1
)

echo [BUILD] Luban ^(%FLAVOUR%^)  --^>  %OUT_DIR%
dotnet publish "%PROJ%" -c Release %PUB_ARGS% -o "%OUT_DIR%" --nologo
if errorlevel 1 (
  echo [ERROR] Build failed.
  exit /b 1
)

rem Scripts invoke Luban.exe directly rather than going through the dotnet CLI,
rem so that one set of scripts works for both flavours.
if not exist "%OUT_DIR%\Luban.exe" (
  echo [ERROR] Build finished but Luban.exe was not produced.
  exit /b 1
)

echo.
echo [OK] Runtime ready: %OUT_DIR%\Luban.exe
endlocal
