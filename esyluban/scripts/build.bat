@echo off
setlocal EnableExtensions

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
set OUT_DIR=%ESY_ROOT%\runtime

if not exist "%PROJ%" (
  echo [ERROR] Main project not found: %PROJ%
  exit /b 1
)

echo [BUILD] Luban  --^>  %OUT_DIR%
dotnet publish "%PROJ%" -c Release -o "%OUT_DIR%" --nologo
if errorlevel 1 (
  echo [ERROR] Build failed.
  exit /b 1
)

if not exist "%OUT_DIR%\Luban.dll" (
  echo [ERROR] Build finished but Luban.dll was not produced.
  exit /b 1
)

echo.
echo [OK] Runtime ready: %OUT_DIR%\Luban.dll
endlocal
