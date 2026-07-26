@echo off
setlocal

set MENU_NAME_DATA=LubanExportData
set MENU_NAME_CODE=LubanExportCode
set GLOBAL_DIR=%ProgramData%\EsyLuban
set SCRIPT_DATA=%GLOBAL_DIR%\run_luban_context_menu_data.bat
set SCRIPT_CODE=%GLOBAL_DIR%\run_luban_context_menu_code.bat
set SCRIPT_OLD=%GLOBAL_DIR%\run_luban_context_menu.bat

reg delete "HKLM\Software\Classes\Directory\shell\%MENU_NAME_DATA%" /f >nul 2>nul
reg delete "HKLM\Software\Classes\*\shell\%MENU_NAME_DATA%" /f >nul 2>nul
reg delete "HKLM\Software\Classes\Directory\Background\shell\%MENU_NAME_DATA%" /f >nul 2>nul
reg delete "HKLM\Software\Classes\Directory\shell\%MENU_NAME_CODE%" /f >nul 2>nul
reg delete "HKLM\Software\Classes\*\shell\%MENU_NAME_CODE%" /f >nul 2>nul
reg delete "HKLM\Software\Classes\Directory\Background\shell\%MENU_NAME_CODE%" /f >nul 2>nul
reg delete "HKLM\Software\Classes\Directory\shell\LubanExport" /f >nul 2>nul
reg delete "HKLM\Software\Classes\*\shell\LubanExport" /f >nul 2>nul

if exist "%SCRIPT_DATA%" del /f /q "%SCRIPT_DATA%" >nul 2>nul
if exist "%SCRIPT_CODE%" del /f /q "%SCRIPT_CODE%" >nul 2>nul
if exist "%SCRIPT_OLD%" del /f /q "%SCRIPT_OLD%" >nul 2>nul
if exist "%GLOBAL_DIR%" rmdir "%GLOBAL_DIR%" >nul 2>nul

echo Context menus removed (global). (HKLM)
pause
