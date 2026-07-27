@echo off
rem Kept as a forwarder. refresh_baselines.bat now handles all four refreshable
rem sets, and two scripts that both mirror baselines is how one of them ends up
rem subtly different from the other.
rem
rem NOTE: keep this file ASCII-only. cmd parses .bat using the system ANSI code
rem page, so UTF-8 non-ASCII comments break execution.
echo [NOTE] This script now forwards to refresh_baselines.bat
echo        Use: refresh_baselines.bat [coverage ^| xml ^| code ^| l10n ^| all]
echo.
call "%~dp0refresh_baselines.bat" coverage
exit /b %errorlevel%
