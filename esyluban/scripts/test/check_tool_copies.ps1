# Asserts that the three copies of each Tools\Luban script stay identical.
#
# NOTE: ASCII-only, same reason as the other .ps1 here (Windows PowerShell 5.1
# decodes .ps1 with the ANSI code page unless the file has a UTF-8 BOM).
#
# gen.bat and check.bat exist three times:
#
#   templates/                        <- what make_release.bat ships to users
#   examples/dev/Tools/Luban/         <- what the regression actually exercises
#   examples/release/Tools/Luban/     <- what the release smoke test exercises
#
# So the copy that reaches users is the one copy no test ever runs. They are
# byte-identical today, but nothing enforced it: a sync script (
# scripts/sync_example_tools.bat) used to do that job, was deleted at some point,
# and the internal notes still describe it as if it existed. Since then the three
# copies have been held together by luck alone.
#
# Keeping them identical -- rather than letting the examples drift -- is what
# makes the regression meaningful: the script under test has to be the script
# that ships.
#
# The exit code is the conclusion: 0 = all copies match, 1 = drifted.

$ErrorActionPreference = 'Stop'
$esy = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# Get-FileHash is not available in every Windows PowerShell host this runs under,
# and its absence surfaced as a silent failure: the guard exited non-zero with no
# output at all. compare_baseline.ps1 hit the same wall and hashes via .NET, so
# do the same here rather than depend on the cmdlet.
function Get-Sha256([string] $path) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.IO.File]::ReadAllBytes($path)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLower()
    } finally { $sha.Dispose() }
}

$names = @('gen.bat', 'check.bat')
$dirs  = @(
    'templates',
    'examples\dev\Tools\Luban',
    'examples\release\Tools\Luban'
)

$failed = 0
foreach ($name in $names) {
    $hashes = @{}
    foreach ($d in $dirs) {
        $path = Join-Path $esy (Join-Path $d $name)
        if (-not (Test-Path -LiteralPath $path)) {
            Write-Host "[FAIL] tool copies: missing $d\$name"
            $failed++
            continue
        }
        $hashes[$d] = Get-Sha256 $path
    }

    $distinct = $hashes.Values | Sort-Object -Unique
    if ($distinct.Count -gt 1) {
        Write-Host "[FAIL] tool copies: $name differs between copies"
        foreach ($d in $dirs) {
            if ($hashes.ContainsKey($d)) {
                Write-Host ("         {0,-32} {1}" -f $d, $hashes[$d].Substring(0, 16))
            }
        }
        Write-Host "       The copy under templates/ is the one shipped to users."
        Write-Host "       Whichever you edited, copy it to the other two."
        $failed++
    }
}

if ($failed -eq 0) {
    Write-Host "[OK]   tool copies: gen.bat / check.bat identical across 3 locations"
    exit 0
}
exit 1
