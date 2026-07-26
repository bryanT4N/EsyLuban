@echo off
setlocal EnableExtensions

set SCRIPT_DIR=%~dp0
python "%SCRIPT_DIR%create_table_template.py" %*

endlocal
