@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Usage: install_luban_context_menu.bat [suite]
rem
rem   suite  optional name that keeps several tool sets side by side.
rem          It is appended to the registry key names, the menu captions and
rem          the ProgramData folder, so installing with different suite names
rem          never overwrites one another. Omit it for the default install.
rem
rem   install_luban_context_menu.bat            -> "Luban Export (Data)"
rem   install_luban_context_menu.bat MyGame     -> "Luban Export (Data) - MyGame"

set SCRIPT_DIR=%~dp0
set ROOT_DIR=%SCRIPT_DIR%..\..
set SUITE=%~1

set GLOBAL_DIR=%ProgramData%\EsyLuban
set MENU_NAME_DATA=LubanExportData
set MENU_NAME_CODE=LubanExportCode
set "MENU_LABEL_DATA=Luban Export (Data)"
set "MENU_LABEL_CODE=Luban Export (Code)"

if not "%SUITE%"=="" (
  set GLOBAL_DIR=!ProgramData!\EsyLuban\!SUITE!
  set MENU_NAME_DATA=LubanExportData_!SUITE!
  set MENU_NAME_CODE=LubanExportCode_!SUITE!
  set "MENU_LABEL_DATA=Luban Export (Data) - !SUITE!"
  set "MENU_LABEL_CODE=Luban Export (Code) - !SUITE!"
)

rem Only the forwarders get installed. They carry no export logic, just the
rem directory contract, so a project can upgrade its Tools\Luban and get the
rem new export behaviour without anyone re-running this installer.
set SCRIPT_DATA=%GLOBAL_DIR%\menu_entry_data.bat
set SCRIPT_CODE=%GLOBAL_DIR%\menu_entry_code.bat
set SOURCE_DATA=%SCRIPT_DIR%menu_entry_data.bat
set SOURCE_CODE=%SCRIPT_DIR%menu_entry_code.bat
if not exist "%SOURCE_DATA%" set SOURCE_DATA=%ROOT_DIR%\scripts\contextmenu\menu_entry_data.bat
if not exist "%SOURCE_CODE%" set SOURCE_CODE=%ROOT_DIR%\scripts\contextmenu\menu_entry_code.bat

set RUN_CMD_DATA="\"%SCRIPT_DATA%\" \"%%1\""
set RUN_CMD_CODE="\"%SCRIPT_CODE%\" \"%%1\""
set RUN_CMD_DATA_BG="\"%SCRIPT_DATA%\" \"%%V\""
set RUN_CMD_CODE_BG="\"%SCRIPT_CODE%\" \"%%V\""

if not exist "%GLOBAL_DIR%" (
  mkdir "!GLOBAL_DIR!" >nul 2>nul
)
if not exist "%SOURCE_DATA%" (
  echo Missing source script: !SOURCE_DATA!
  echo If nothing happens, run as Administrator.
  pause
  exit /b 1
)
if not exist "%SOURCE_CODE%" (
  echo Missing source script: !SOURCE_CODE!
  echo If nothing happens, run as Administrator.
  pause
  exit /b 1
)
copy /Y "%SOURCE_DATA%" "%SCRIPT_DATA%" >nul
if %errorlevel% neq 0 (
  echo Failed to copy: !SCRIPT_DATA!
  echo If nothing happens, run as Administrator.
  pause
  exit /b 1
)
copy /Y "%SOURCE_CODE%" "%SCRIPT_CODE%" >nul
if %errorlevel% neq 0 (
  echo Failed to copy: !SCRIPT_CODE!
  echo If nothing happens, run as Administrator.
  pause
  exit /b 1
)

rem Older installs put full export scripts here and pointed the registry at
rem them. Leaving those behind would be actively harmful: they predate the
rem cleanUpOutputDir fix, so exporting one table wiped every other table's
rem output. Delete them so nothing can invoke the stale copies.
del /q "%GLOBAL_DIR%\run_luban_context_menu_data.bat" >nul 2>nul
del /q "%GLOBAL_DIR%\run_luban_context_menu_code.bat" >nul 2>nul

rem cleanup old single menu
reg delete "HKLM\Software\Classes\Directory\shell\LubanExport" /f >nul 2>nul
reg delete "HKLM\Software\Classes\*\shell\LubanExport" /f >nul 2>nul

reg delete "HKLM\Software\Classes\Directory\shell\%MENU_NAME_DATA%" /f >nul 2>nul
reg delete "HKLM\Software\Classes\*\shell\%MENU_NAME_DATA%" /f >nul 2>nul
reg delete "HKLM\Software\Classes\Directory\shell\%MENU_NAME_CODE%" /f >nul 2>nul
reg delete "HKLM\Software\Classes\*\shell\%MENU_NAME_CODE%" /f >nul 2>nul

reg add "HKLM\Software\Classes\Directory\shell\%MENU_NAME_DATA%" /ve /d "%MENU_LABEL_DATA%" /f >nul
reg add "HKLM\Software\Classes\Directory\shell\%MENU_NAME_DATA%\command" /ve /d %RUN_CMD_DATA% /f >nul
reg add "HKLM\Software\Classes\*\shell\%MENU_NAME_DATA%" /ve /d "%MENU_LABEL_DATA%" /f >nul
reg add "HKLM\Software\Classes\*\shell\%MENU_NAME_DATA%\command" /ve /d %RUN_CMD_DATA% /f >nul
reg add "HKLM\Software\Classes\Directory\Background\shell\%MENU_NAME_DATA%" /ve /d "%MENU_LABEL_DATA%" /f >nul
reg add "HKLM\Software\Classes\Directory\Background\shell\%MENU_NAME_DATA%\command" /ve /d %RUN_CMD_DATA_BG% /f >nul

reg add "HKLM\Software\Classes\Directory\shell\%MENU_NAME_CODE%" /ve /d "%MENU_LABEL_CODE%" /f >nul
reg add "HKLM\Software\Classes\Directory\shell\%MENU_NAME_CODE%\command" /ve /d %RUN_CMD_CODE% /f >nul
reg add "HKLM\Software\Classes\*\shell\%MENU_NAME_CODE%" /ve /d "%MENU_LABEL_CODE%" /f >nul
reg add "HKLM\Software\Classes\*\shell\%MENU_NAME_CODE%\command" /ve /d %RUN_CMD_CODE% /f >nul
reg add "HKLM\Software\Classes\Directory\Background\shell\%MENU_NAME_CODE%" /ve /d "%MENU_LABEL_CODE%" /f >nul
reg add "HKLM\Software\Classes\Directory\Background\shell\%MENU_NAME_CODE%\command" /ve /d %RUN_CMD_CODE_BG% /f >nul

echo Context menus installed (global). (HKLM)
echo If nothing happens, run as Administrator.
pause
