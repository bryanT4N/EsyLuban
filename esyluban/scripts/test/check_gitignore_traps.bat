@echo off
setlocal EnableExtensions

rem ---------------------------------------------------------------
rem Thin wrapper. The logic lives in check_gitignore_traps.ps1 because this
rem check is all string handling, which is exactly what .bat is worst at --
rem the first cut used `findstr /e ".bat .ps1"` and silently matched nothing,
rem since '.' is a findstr metacharacter. A guard that cannot fail is worse
rem than no guard, so it moved to PowerShell.
rem
rem NOTE: keep this file ASCII-only. cmd parses .bat using the system
rem ANSI code page, so UTF-8 non-ASCII comments break execution.
rem ---------------------------------------------------------------

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check_gitignore_traps.ps1" -EsyRoot "%~dp0..\.."
exit /b %errorlevel%
