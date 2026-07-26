@echo off
setlocal EnableExtensions

rem This script lives in esyluban\scripts\test\; two levels up is esyluban\
set ESY_ROOT=%~dp0..\..
set EXAMPLE_ROOT=%ESY_ROOT%\examples\dev
set OUTPUT_REPORT=%EXAMPLE_ROOT%\TestOutputs\coverage_matrix_report.json
set MATRIX_DIR=%EXAMPLE_ROOT%\DataTables\matrix
set NEGATIVE_DIR=%EXAMPLE_ROOT%\DataTables\negatives

powershell -NoProfile -Command "$report=$env:OUTPUT_REPORT; $matrix=$env:MATRIX_DIR; $neg=$env:NEGATIVE_DIR; $now=(Get-Date).ToString('s'); $items=@(); if (Test-Path $matrix) { $base=(Get-Item $matrix).FullName; $items += Get-ChildItem -File -Recurse $matrix | ForEach-Object { $rel=$_.FullName; if ($rel.StartsWith($base)) { $rel=$rel.Substring($base.Length); $rel=$rel.TrimStart([char[]]([char]92,[char]47)) } [PSCustomObject]@{ path=$rel; type='matrix'; modified=$_.LastWriteTime.ToString('s') } } } if (Test-Path $neg) { $base=(Get-Item $neg).FullName; $items += Get-ChildItem -File -Recurse $neg | ForEach-Object { $rel=$_.FullName; if ($rel.StartsWith($base)) { $rel=$rel.Substring($base.Length); $rel=$rel.TrimStart([char[]]([char]92,[char]47)) } [PSCustomObject]@{ path=$rel; type='negative'; modified=$_.LastWriteTime.ToString('s') } } } $matrixCount=0; $negativeCount=0; foreach ($i in $items) { if ($i.type -eq 'matrix') { $matrixCount++ } elseif ($i.type -eq 'negative') { $negativeCount++ } } $summary=[PSCustomObject]@{ generated_at=$now; matrix_dir=$matrix; negatives_dir=$neg; total_count=$items.Count; matrix_count=$matrixCount; negative_count=$negativeCount; items=$items }; $summary | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 $report"

echo Coverage matrix report: %OUTPUT_REPORT%
endlocal
