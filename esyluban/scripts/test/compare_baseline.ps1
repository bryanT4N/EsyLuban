<#
.SYNOPSIS
  Compare an output directory against a baseline by SHA256, and FAIL on drift.

.DESCRIPTION
  Previously this logic was inlined in run_full_tests_example.bat as a single
  600-character line that only wrote a json report and always succeeded. The
  regression could therefore not fail: a run where Luban never started produced
  the same "all green" report as a correct one.

  Exit code is the whole point of this file:
    0  baseline and output match exactly
    1  drift detected (missing / extra / content differs)
    2  baseline or output directory not found
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $BaselineDir,
    [Parameter(Mandatory = $true)][string] $OutputDir,
    [Parameter(Mandatory = $true)][string] $ReportPath,
    [Parameter(Mandatory = $true)][string] $Label,

    # core/ holds output from the pristine upstream project, which has fewer
    # tables than we do -- EsyLuban adds its own fixtures (matrix/, minimal_b1).
    # Extra files are therefore expected there and only there. The old inline
    # comparer expressed this by hard-coding extra=@(), which silently disabled
    # the check for everyone instead of stating the exemption.
    [switch] $AllowExtra
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $BaselineDir)) {
    Write-Host "[FAIL] $Label : baseline not found: $BaselineDir"
    exit 2
}
if (-not (Test-Path -LiteralPath $OutputDir)) {
    Write-Host "[FAIL] $Label : output not found: $OutputDir"
    exit 2
}

$base = [System.IO.Path]::GetFullPath($BaselineDir)
$out = [System.IO.Path]::GetFullPath($OutputDir)

function Get-Sha256([string] $path) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.IO.File]::ReadAllBytes($path)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLower()
    } finally { $sha.Dispose() }
}

$baseFiles = @(Get-ChildItem -File -Recurse -LiteralPath $base |
    ForEach-Object { $_.FullName.Substring($base.Length + 1) })
$outFiles = @(Get-ChildItem -File -Recurse -LiteralPath $out |
    ForEach-Object { $_.FullName.Substring($out.Length + 1) })

$outSet = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]$outFiles, [System.StringComparer]::OrdinalIgnoreCase)
$baseSet = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]$baseFiles, [System.StringComparer]::OrdinalIgnoreCase)

$missing = @($baseFiles | Where-Object { -not $outSet.Contains($_) })
$extra = @($outFiles | Where-Object { -not $baseSet.Contains($_) })
$diff = @()
foreach ($f in $baseFiles) {
    if ($outSet.Contains($f)) {
        if ((Get-Sha256 (Join-Path $base $f)) -ne (Get-Sha256 (Join-Path $out $f))) {
            $diff += $f
        }
    }
}

# An empty output directory is always a failure, even against an empty
# baseline: it means the exporter produced nothing at all.
$emptyOutput = ($outFiles.Count -eq 0)

[PSCustomObject]@{
    base_count = $baseFiles.Count
    out_count  = $outFiles.Count
    missing    = $missing
    extra      = $extra
    diff       = $diff
} | ConvertTo-Json -Depth 3 | Set-Content -Encoding UTF8 -LiteralPath $ReportPath

$countedExtra = if ($AllowExtra) { 0 } else { $extra.Count }
$problems = $missing.Count + $countedExtra + $diff.Count
if ($problems -eq 0 -and -not $emptyOutput) {
    $note = if ($AllowExtra -and $extra.Count) { " (+$($extra.Count) extra, allowed)" } else { "" }
    Write-Host "[OK]   $Label : $($baseFiles.Count) files match$note"
    exit 0
}

Write-Host "[FAIL] $Label : missing=$($missing.Count) extra=$($extra.Count) diff=$($diff.Count)"
foreach ($f in ($missing | Select-Object -First 8)) { Write-Host "         missing: $f" }
foreach ($f in ($extra   | Select-Object -First 8)) { Write-Host "         extra:   $f" }
foreach ($f in ($diff    | Select-Object -First 8)) { Write-Host "         diff:    $f" }
if ($emptyOutput) { Write-Host "         output directory is EMPTY - exporter produced nothing" }
Write-Host "         report: $ReportPath"
exit 1
