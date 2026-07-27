# Verifies the checkable factual claims the documentation makes about the code.
#
# NOTE: ASCII-only, like the other .ps1 here. Windows PowerShell 5.1 decodes .ps1
# with the system ANSI code page unless the file carries a UTF-8 BOM, so a
# non-ASCII literal turns into mojibake that breaks the parser. That rules out
# matching Chinese prose directly -- every pattern below anchors on an ASCII
# token (an identifier, a path, a markdown fence) and reads the numbers near it.
#
# Why this guard exists: prose cannot be tested, but numbers and identifiers can,
# and this repo has already shipped several claims a reader could disprove on the
# spot:
#   - "src/ has two modified files" while there were three -- one line below the
#     git command that lists all three
#   - "Luban has 27 built-in codeTargets" while a table in the same document
#     listed all 29
#   - "two baselines", "coverage: 56 json" while there were five sets and 60 files
#
# Each of those was a reader's first opportunity to stop trusting the docs.
#
# The exit code is the conclusion: 0 = docs agree with the code, 1 = drifted.

$ErrorActionPreference = 'Stop'
$esy      = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$repoRoot = Split-Path -Parent $esy
$failed   = 0

function Read-Text([string] $relPath) {
    $p = Join-Path $repoRoot $relPath
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    return [System.IO.File]::ReadAllText($p)
}

# How many targets does the source actually register?
function Count-Attribute([string] $attr) {
    $names  = New-Object System.Collections.Generic.HashSet[string]
    $srcDir = Join-Path $repoRoot 'src'
    foreach ($f in Get-ChildItem -LiteralPath $srcDir -Recurse -Filter *.cs -File) {
        $text = [System.IO.File]::ReadAllText($f.FullName)
        foreach ($m in [regex]::Matches($text, "\[$attr\(""([^""]+)""")) {
            [void]$names.Add($m.Groups[1].Value)
        }
    }
    return $names.Count
}

$guide = Read-Text 'esyluban/docs/esyluban_beginner_guide.md'
if ($null -eq $guide) {
    Write-Host "[FAIL] doc facts: cannot find the manual"
    exit 1
}

# ---- target counts ----------------------------------------------------------
# The manual states both in its "three kinds of target" table. Anchor on the
# bold identifier, then read whatever number appears later on that same line.
foreach ($kind in @('codeTarget', 'dataTarget')) {
    $actual = Count-Attribute ($kind.Substring(0,1).ToUpper() + $kind.Substring(1))

    # The bold identifier appears in ordinary prose too, so pick the line that
    # both mentions it and states a number -- that is the table row.
    $line = ($guide -split "`n") |
        Where-Object { $_ -match "\*\*$kind\*\*" -and $_ -match '\d' } |
        Select-Object -First 1
    if (-not $line) {
        Write-Host "[FAIL] doc facts: manual has no **$kind** row stating a count"
        $failed++
        continue
    }
    # No \b around the digits: .NET word boundaries do not fire between a CJK
    # character and a digit (both are word characters), so \b(\d+)\b never
    # matches a number embedded in Chinese prose.
    $nums = [regex]::Matches($line, '(\d+)') | ForEach-Object { [int]$_.Groups[1].Value }
    if ($nums -notcontains $actual) {
        Write-Host "[FAIL] doc facts: source registers $actual ${kind}s, manual's row says $($nums -join '/')"
        $failed++
    }
}

# ---- every baseline set must be described -----------------------------------
$baselineDir = Join-Path $esy 'baselines'
$actualSets  = @(Get-ChildItem -LiteralPath $baselineDir -Directory | ForEach-Object { $_.Name })
$baseReadme  = Read-Text 'esyluban/baselines/README.md'
foreach ($set in $actualSets) {
    if ($baseReadme -notmatch [regex]::Escape("``$set/``")) {
        Write-Host "[FAIL] doc facts: baselines/$set exists but baselines/README.md never mentions it"
        $failed++
    }
}

# ---- documented paths must exist --------------------------------------------
# Catches the "moved a file, left the link" class of rot.
$docFiles = @('esyluban/README.md', 'esyluban/baselines/README.md', 'esyluban/examples/README.md')
foreach ($rel in $docFiles) {
    $text = Read-Text $rel
    if ($null -eq $text) { continue }
    foreach ($m in [regex]::Matches($text, '`(esyluban/[A-Za-z0-9_./-]+\.(?:bat|ps1|py|md|txt|conf))`')) {
        $claimed = $m.Groups[1].Value
        if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $claimed))) {
            Write-Host "[FAIL] doc facts: $rel points at $claimed, which does not exist"
            $failed++
        }
    }
}

if ($failed -eq 0) {
    Write-Host "[OK]   doc facts: target counts, baseline sets and referenced paths all agree"
    exit 0
}
exit 1
