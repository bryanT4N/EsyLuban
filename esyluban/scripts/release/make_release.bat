@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ---------------------------------------------------------------
rem Assemble a distributable EsyLuban package.
rem
rem Usage: make_release.bat [version] [--self-contained]
rem        version defaults to the <Version> in src/Luban/Luban.csproj
rem
rem   (default)         packages esyluban/runtime      -> ~2 MB zip, needs .NET 8
rem   --self-contained  packages esyluban/runtime-sc   -> ~30 MB zip, no install
rem
rem Build the matching runtime first:
rem   scripts\build.bat                    (framework-dependent)
rem   scripts\build.bat --self-contained   (bundled runtime)
rem
rem The staged folder is laid out exactly like the recommended project
rem structure, so a user can copy Tools\ and DataTables\ straight into
rem their game project. It also runs as-is: unzip, double-click gen.bat,
rem and outputs appear under Generated\ -- proof the toolchain works
rem before any path is edited.
rem
rem NOTE: keep this file ASCII-only. cmd parses .bat using the system
rem ANSI code page, so UTF-8 non-ASCII comments break execution.
rem ---------------------------------------------------------------

set SCRIPT_DIR=%~dp0
set ESY_ROOT=%SCRIPT_DIR%..\..
set REPO_ROOT=%ESY_ROOT%\..
set DIST_ROOT=%ESY_ROOT%\dist

set RUNTIME_DIR=%ESY_ROOT%\runtime
set PKG_SUFFIX=
set BUILD_HINT=scripts\build.bat
if /i "%~1"=="--self-contained" goto :SC
if /i "%~2"=="--self-contained" goto :SC
goto :NOSC
:SC
set RUNTIME_DIR=%ESY_ROOT%\runtime-sc
set PKG_SUFFIX=-standalone
set BUILD_HINT=scripts\build.bat --self-contained
:NOSC

set VERSION=%~1
if /i "%VERSION%"=="--self-contained" set VERSION=
if "%VERSION%"=="" (
  rem Select-Object -First 1, not [0]: a single matching PropertyGroup makes
  rem .Version a bare string, and [0] would index into it and yield one char.
  for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
    "$p=[xml](Get-Content '!REPO_ROOT!\src\Luban\Luban.csproj');" ^
    "$p.Project.PropertyGroup.Version | Where-Object { $_ } | Select-Object -First 1"`) do set VERSION=%%A
)
if "%VERSION%"=="" (
  echo [ERROR] Could not determine version. Pass it explicitly:
  echo         make_release.bat 4.10.2
  exit /b 1
)

set PKG_NAME=EsyLuban-%VERSION%-win-x64%PKG_SUFFIX%
set STAGE=%DIST_ROOT%\%PKG_NAME%

if not exist "%RUNTIME_DIR%\Luban.exe" (
  echo [ERROR] Runtime not built: !RUNTIME_DIR!\Luban.exe
  echo         Run: !BUILD_HINT!
  exit /b 1
)

echo [PACK] %PKG_NAME%

if exist "%STAGE%" rmdir /s /q "%STAGE%"
mkdir "%STAGE%\Tools\Luban\runtime" 2>nul
mkdir "%STAGE%\Tools\Luban\contextmenu" 2>nul
mkdir "%STAGE%\DataTables" 2>nul
mkdir "%STAGE%\docs" 2>nul

rem Runtime, minus debug symbols -- they are not useful to consumers
rem and account for roughly half a megabyte.
xcopy "%RUNTIME_DIR%\*" "%STAGE%\Tools\Luban\runtime\" /e /i /q /y /exclude:%SCRIPT_DIR%pack_exclude.txt >nul
if errorlevel 1 goto :FAIL

copy /y "%ESY_ROOT%\templates\luban.conf" "%STAGE%\Tools\Luban\" >nul || goto :FAIL
copy /y "%ESY_ROOT%\templates\gen.bat"    "%STAGE%\Tools\Luban\" >nul || goto :FAIL
copy /y "%ESY_ROOT%\templates\check.bat"  "%STAGE%\Tools\Luban\" >nul || goto :FAIL

copy /y "%ESY_ROOT%\scripts\contextmenu\*.bat" "%STAGE%\Tools\Luban\contextmenu\" >nul || goto :FAIL
copy /y "%ESY_ROOT%\templates\DataTables\*.xlsx" "%STAGE%\DataTables\" >nul || goto :FAIL

copy /y "%ESY_ROOT%\docs\esyluban_beginner_guide.md" "%STAGE%\docs\" >nul || goto :FAIL
copy /y "%SCRIPT_DIR%RELEASE_README.md" "%STAGE%\README.md" >nul || goto :FAIL

rem Smoke test: the package must work before it is zipped.
rem
rem Invoke gen.bat, NOT dotnet directly. gen.bat is what the README tells
rem users to run, so it is the only thing worth verifying -- calling the dll
rem behind it would skip the runtime lookup and argument handling that are
rem exactly where a packaging mistake shows up.
echo [TEST] exporting bundled samples via gen.bat
set LUBAN_NO_PAUSE=1
call "%STAGE%\Tools\Luban\gen.bat" -t client -d json
set GEN_ERR=%errorlevel%
set LUBAN_NO_PAUSE=
if not "%GEN_ERR%"=="0" (
  echo [ERROR] Smoke test failed: the package cannot export its own samples.
  exit /b 1
)
if not exist "%STAGE%\Generated\Data\demo_tbitem.json" (
  echo [ERROR] Smoke test produced no output. Expected Generated\Data\demo_tbitem.json
  exit /b 1
)

rem Discard the smoke-test output. Shipping it would rob the user of the
rem one check that proves their own setup works: README step 1 tells them
rem to run gen.bat and look for these files appearing.
rmdir /s /q "%STAGE%\Generated"

set ZIP_PATH=%DIST_ROOT%\%PKG_NAME%.zip
if exist "%ZIP_PATH%" del /q "%ZIP_PATH%"
powershell -NoProfile -Command ^
  "Compress-Archive -Path '%STAGE%' -DestinationPath '%ZIP_PATH%' -CompressionLevel Optimal" || goto :FAIL

echo.
echo [OK] %ZIP_PATH%
for %%F in ("%ZIP_PATH%") do echo      %%~zF bytes
echo      staged at: %STAGE%
endlocal
exit /b 0

:FAIL
echo [ERROR] Packaging failed.
exit /b 1
