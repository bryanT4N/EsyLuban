@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Usage: uninstall_luban_context_menu.bat [suite]
rem
rem   Pass the same suite name that was used to install, so the matching
rem   entries are removed. Omit it to remove the default install.

set SUITE=%~1

set MENU_NAME_DATA=LubanExportData
set MENU_NAME_CODE=LubanExportCode
set GLOBAL_DIR=%ProgramData%\EsyLuban

if not "%SUITE%"=="" (
  set MENU_NAME_DATA=LubanExportData_!SUITE!
  set MENU_NAME_CODE=LubanExportCode_!SUITE!
  set GLOBAL_DIR=%ProgramData%\EsyLuban\!SUITE!
)
rem Current installs place the forwarders here. The run_* names are what older
rem versions installed (full export scripts); remove those too.
set SCRIPT_DATA=%GLOBAL_DIR%\menu_entry_data.bat
set SCRIPT_CODE=%GLOBAL_DIR%\menu_entry_code.bat
set SCRIPT_LEGACY_DATA=%GLOBAL_DIR%\run_luban_context_menu_data.bat
set SCRIPT_LEGACY_CODE=%GLOBAL_DIR%\run_luban_context_menu_code.bat
set SCRIPT_OLD=%GLOBAL_DIR%\run_luban_context_menu.bat

reg delete "HKLM\Software\Classes\Directory\shell\%MENU_NAME_DATA%" /f >nul 2>nul
reg delete "HKLM\Software\Classes\*\shell\%MENU_NAME_DATA%" /f >nul 2>nul
reg delete "HKLM\Software\Classes\Directory\Background\shell\%MENU_NAME_DATA%" /f >nul 2>nul
reg delete "HKLM\Software\Classes\Directory\shell\%MENU_NAME_CODE%" /f >nul 2>nul
reg delete "HKLM\Software\Classes\*\shell\%MENU_NAME_CODE%" /f >nul 2>nul
reg delete "HKLM\Software\Classes\Directory\Background\shell\%MENU_NAME_CODE%" /f >nul 2>nul
rem Legacy single-menu key from early versions. Only the default (suite-less)
rem uninstall should clear it -- a suite uninstall must not touch other installs.
if "%SUITE%"=="" (
  reg delete "HKLM\Software\Classes\Directory\shell\LubanExport" /f >nul 2>nul
  reg delete "HKLM\Software\Classes\*\shell\LubanExport" /f >nul 2>nul
)

if exist "%SCRIPT_DATA%" del /f /q "%SCRIPT_DATA%" >nul 2>nul
if exist "%SCRIPT_CODE%" del /f /q "%SCRIPT_CODE%" >nul 2>nul
if exist "%SCRIPT_LEGACY_DATA%" del /f /q "%SCRIPT_LEGACY_DATA%" >nul 2>nul
if exist "%SCRIPT_LEGACY_CODE%" del /f /q "%SCRIPT_LEGACY_CODE%" >nul 2>nul
if exist "%SCRIPT_OLD%" del /f /q "%SCRIPT_OLD%" >nul 2>nul
if exist "%GLOBAL_DIR%" rmdir "%GLOBAL_DIR%" >nul 2>nul

echo Context menus removed (global). (HKLM)
pause
