# Asserts that this fork's change surface against upstream Luban matches
# esyluban/upstream_boundary.txt exactly.
#
# NOTE: keep this file ASCII-only, like the other .ps1 here. Windows PowerShell
# 5.1 decodes .ps1 using the system ANSI code page unless the file carries a
# UTF-8 BOM, so non-ASCII comments turn into mojibake that can break the parser.
#
# "Only add to upstream, never modify it" is this fork's core constraint, and the
# only evidence a stranger has that nothing was quietly changed in upstream code.
# It used to live as a sentence in the README, maintained by memory -- and it had
# already gone stale: the README claimed "two modified files under src/" when
# there were three, while the line above it taught readers the very git command
# that disproves it. A promise a reader can refute on the spot is worse than none.
#
# Does not rely on an "upstream" remote: CI clones the fork, which has no such
# remote. The base commit is an ancestor of our history, so any full clone can
# diff against its SHA directly.
#
# The exit code is the conclusion: 0 = matches, 1 = drifted.

$ErrorActionPreference = 'Stop'
$esy      = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$repoRoot = Split-Path -Parent $esy
$listFile = Join-Path $esy 'upstream_boundary.txt'

# Every git call is pinned to the repo root with -C. The pathspec below is "."
# plus an exclude, and both are resolved relative to git's working directory --
# so without -C this guard quietly reports on whatever subtree it happened to be
# launched from instead of the whole repo. It would not error; it would answer a
# different question. The regression invokes it from the batch script's cwd,
# which is not the repo root, and that is exactly how this surfaced.

if (-not (Test-Path -LiteralPath $listFile)) {
    Write-Host "[FAIL] upstream boundary: cannot find $listFile"
    exit 1
}

# ---- read the manifest ------------------------------------------------------
$base     = $null
$expected = New-Object System.Collections.Generic.HashSet[string]
foreach ($line in Get-Content -LiteralPath $listFile -Encoding UTF8) {
    $t = $line.Trim()
    if ($t -eq '' -or $t.StartsWith('#')) { continue }
    $parts = $t -split "\s+", 2
    if ($parts.Count -ne 2) { continue }
    if ($parts[0] -eq 'BASE') { $base = $parts[1].Trim(); continue }
    [void]$expected.Add("$($parts[0])`t$($parts[1].Trim())")
}

if (-not $base) {
    Write-Host "[FAIL] upstream boundary: manifest has no BASE line"
    exit 1
}

# The base commit must actually be reachable, or the diff below means nothing.
& git -C $repoRoot cat-file -e "$base^{commit}" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] upstream boundary: base commit $base is not in this repository"
    Write-Host "       A shallow clone causes this; CI needs fetch-depth: 0"
    exit 1
}

# ---- actual change surface (excluding our own esyluban/ subtree) -------------
$raw    = & git -C $repoRoot diff --name-status $base -- . ':(exclude)esyluban'
$actual = New-Object System.Collections.Generic.HashSet[string]
foreach ($line in $raw) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    # First letter only: renames come through as R100 and friends.
    $cols   = $line -split "`t"
    $status = $cols[0].Substring(0, 1)
    [void]$actual.Add("$status`t$($cols[-1])")
}

# ---- compare ----------------------------------------------------------------
$missing = @($expected | Where-Object { -not $actual.Contains($_) })
$extra   = @($actual   | Where-Object { -not $expected.Contains($_) })

if ($missing.Count -eq 0 -and $extra.Count -eq 0) {
    Write-Host "[OK]   upstream boundary: $($expected.Count) change(s), manifest matches"
    exit 0
}

Write-Host "[FAIL] upstream boundary: drifted from esyluban/upstream_boundary.txt"
foreach ($e in $extra)   { Write-Host "         not in manifest : $e" }
foreach ($m in $missing) { Write-Host "         in manifest but not on disk: $m" }
Write-Host "       Touching an upstream file is allowed -- write it into the"
Write-Host "       manifest first, with the reason it could not be avoided."
exit 1
