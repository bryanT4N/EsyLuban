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

# The target-count claims now live in targets-and-output.md. Read the whole docs
# directory rather than one file: the split turned a single manual into ten
# documents, and a check pinned to one filename would quietly stop checking the
# moment content moved.
$docsDir = Join-Path $esy 'docs'
$guide = ''
foreach ($f in Get-ChildItem -LiteralPath $docsDir -Filter *.md -File) {
    $guide += [System.IO.File]::ReadAllText($f.FullName) + "`n"
}
if ($guide.Trim() -eq '') {
    Write-Host "[FAIL] doc facts: no documents found under esyluban/docs"
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

# ---- every relative markdown link must resolve ------------------------------
# Catches the "moved a file, left the link" class of rot, and the plain typo:
# this check was written right after a link in the docs index pointed at
# upstream_boundary.md when the file is a .txt.
$mdFiles = @(Get-ChildItem -LiteralPath $repoRoot -Filter *.md -File) +
           @(Get-ChildItem -LiteralPath (Join-Path $esy 'docs') -Filter *.md -File -ErrorAction SilentlyContinue)
foreach ($md in $mdFiles) {
    $text = [System.IO.File]::ReadAllText($md.FullName)
    foreach ($m in [regex]::Matches($text, '\]\(([^)#][^)]*)\)')) {
        $link = $m.Groups[1].Value
        if ($link -match '^[a-z]+:') { continue }        # external URL
        # GitHub resolves ../../releases and ../../issues against the repository
        # URL, not the file tree, so they have no on-disk counterpart to check.
        if ($link -match '^\.\./\.\./(releases|issues|pulls|wiki|discussions)') { continue }
        $link = ($link -split '#')[0]
        if ($link -eq '') { continue }
        $target = Join-Path $md.DirectoryName $link
        if (-not (Test-Path -LiteralPath $target)) {
            Write-Host "[FAIL] doc facts: $($md.Name) links to '$link', which does not exist"
            $failed++
        }
    }
}

# ---- documented paths must exist --------------------------------------------
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

# ---- claims the source can contradict ---------------------------------------
# These four all shipped as documented fact while the code said otherwise. Each
# would send a reader down a wrong path, and each is cheap to keep honest.
$srcCtx = ''
foreach ($n in @('run_luban_context_menu_data.bat', 'run_luban_context_menu_code.bat')) {
    $p = Join-Path $esy "scripts\contextmenu\$n"
    if (Test-Path -LiteralPath $p) { $srcCtx += [System.IO.File]::ReadAllText($p) }
}

# The right-click chain uses --listTables plus -o. The manual claimed for a long
# time that it "only overrides tableImporter.scanPath" -- in four places, one of
# them inside a section headed "must read".
if ($srcCtx -notmatch 'listTables') {
    Write-Host "[FAIL] doc facts: right-click scripts no longer use --listTables"
    Write-Host "         The manual documents that mechanism; one of them is now wrong."
    $failed++
}
if ($srcCtx -match 'scanPath') {
    Write-Host "[FAIL] doc facts: right-click scripts now set scanPath"
    Write-Host "         The manual says they deliberately do not; update both."
    $failed++
}

# The installer copies the thin forwarders, not the implementation scripts. The
# manual described the pre-fix behaviour for a long time -- the very bug this
# project fixed.
$installer = Join-Path $esy 'scripts\contextmenu\install_luban_context_menu.bat'
if (Test-Path -LiteralPath $installer) {
    $inst = [System.IO.File]::ReadAllText($installer)
    if ($inst -notmatch 'menu_entry_data\.bat') {
        Write-Host "[FAIL] doc facts: installer no longer deploys menu_entry_*.bat"
        $failed++
    }
    # Three registry roots; the manual once listed only two and readers with a
    # folder-background right-click found nothing there.
    foreach ($root in @('Directory\shell', 'Directory\Background\shell', '\*\shell')) {
        if ($inst -notmatch [regex]::Escape($root)) {
            Write-Host "[FAIL] doc facts: installer no longer registers $root"
            $failed++
        }
    }
}

# Every template the manual marks as copy-paste-ready must actually work. The one
# labelled that way was the only one missing read_schema_from_file, so the first
# designer to follow the instruction hit 'invalid type' on step one.
$guideLines = $guide -split "`n"
for ($i = 0; $i -lt $guideLines.Count; $i++) {
    if ($guideLines[$i] -match 'full_name=' -and $guideLines[$i] -match '##var') { continue }
    if ($guideLines[$i] -notmatch '##type') { continue }
    # Walk back to the nearest full_name= line, stopping at a blank line or a
    # heading. Without that stop the walk pairs unrelated fragments: a one-line
    # B1 syntax example and a ##var/##type snippet from the next subsection are
    # eleven lines apart, and flagging that pair is a false alarm. A guard that
    # cries wolf trains people to ignore it, which is worse than not having it.
    for ($j = $i; $j -ge 0 -and $j -gt $i - 12; $j--) {
        if ($guideLines[$j].Trim() -eq '' -or $guideLines[$j] -match '^\s*#{1,6}\s') { break }
        if ($guideLines[$j] -match 'full_name=') {
            if ($guideLines[$j] -notmatch 'read_schema_from_file') {
                Write-Host "[FAIL] doc facts: manual line $($j+1) declares a table with ##type rows"
                Write-Host "         but no read_schema_from_file - copying it yields 'invalid type'"
                $failed++
            }
            break
        }
    }
}

if ($failed -eq 0) {
    Write-Host "[OK]   doc facts: target counts, baselines, paths and mechanisms all agree"
    exit 0
}
exit 1
