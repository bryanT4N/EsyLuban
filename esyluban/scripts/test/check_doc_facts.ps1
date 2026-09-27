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

    # HTML <img src="..."> too. Markdown image syntax is caught by the pattern
    # above, but a screenshot needing a width attribute has to be written as raw
    # HTML -- and a broken image there is exactly as bad, while looking fine in
    # the source.
    foreach ($m in [regex]::Matches($text, '<img\s[^>]*src="([^"]+)"')) {
        $src = $m.Groups[1].Value
        if ($src -match '^[a-z]+:') { continue }
        $target = Join-Path $md.DirectoryName $src
        if (-not (Test-Path -LiteralPath $target)) {
            Write-Host "[FAIL] doc facts: $($md.Name) shows an image '$src', which does not exist"
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

# ---- VERSION must be the newest release in the CHANGELOG --------------------
# Two hand-maintained copies of the same number drift. This one matters because
# the package filename is built from VERSION while readers look up what changed
# in the CHANGELOG -- a mismatch means the release notes describe a build nobody
# can identify.
#
# The CHANGELOG follows Keep a Changelog: an unreleased section sits on top and
# names no version, so read the first heading that starts with one, bracketed
# or not ("## [0.3.0+luban5.1.0] - 2026-09-26").
$versionFile = Join-Path $esy 'VERSION'
$changelog   = Read-Text 'CHANGELOG.md'
if ((Test-Path -LiteralPath $versionFile) -and $null -ne $changelog) {
    $ver = ([System.IO.File]::ReadAllText($versionFile)).Trim()
    $firstEntry = [regex]::Match($changelog, '(?m)^##\s+\[?(\d[^\]\s]*)')
    if (-not $firstEntry.Success) {
        Write-Host "[FAIL] doc facts: CHANGELOG.md has no version heading"
        $failed++
    } elseif ($firstEntry.Groups[1].Value -notlike "$ver*") {
        Write-Host "[FAIL] doc facts: esyluban/VERSION says $ver, CHANGELOG's newest entry is $($firstEntry.Groups[1].Value)"
        $failed++
    }
}

# ---- targets that share a group must be explained ---------------------------
# The dev example has an "editor" target bound to the same group as "client".
# It looks like a typo -- and a reader asked whether it should be "e" -- but it
# is deliberate: identical data, different topModule, so a Unity editor assembly
# and a runtime assembly can each have their own config classes without the type
# names colliding.
#
# Anything that reads like a mistake but is not needs the reason written down, or
# the next person "fixes" it. This asserts the explanation is still there.
$devConf = Join-Path $esy 'examples\dev\Tools\Luban\luban.conf'
if (Test-Path -LiteralPath $devConf) {
    $conf = [System.IO.File]::ReadAllText($devConf)
    $clientGroups = [regex]::Match($conf, '"name"\s*:\s*"client".*?"groups"\s*:\s*\[([^\]]*)\]')
    $editorGroups = [regex]::Match($conf, '"name"\s*:\s*"editor".*?"groups"\s*:\s*\[([^\]]*)\]')
    if ($clientGroups.Success -and $editorGroups.Success -and
        $clientGroups.Groups[1].Value -eq $editorGroups.Groups[1].Value) {
        $config = Read-Text 'esyluban/docs/configuration.md'
        if ($config -notmatch 'topModule' -or $config -notmatch 'editor\.cfg') {
            Write-Host "[FAIL] doc facts: editor and client bind the same group in the dev conf,"
            Write-Host "         but configuration.md no longer explains why (the topModule trick)."
            Write-Host "         Without that, it reads as a typo and someone will 'fix' it."
            $failed++
        }
    }
}

# ---- error codes and error text quoted in the docs ------------------------
# Luban 5 prints its messages in the Windows display language, zh or en, so the
# docs name an error by its message key -- error.data.duplicate_key -- which is
# the same in every language. Two checks keep that honest.
#
# EsyLuban's own messages have codes too (esyluban.b1.bad_mode ...). They live
# in src/Luban.Core/Diagnostics/EsyMessages.cs as new("code", "zh", "en")
# entries rather than in upstream's catalogs, and are read into the same lookup,
# so everything below treats the two kinds of code alike.
#
# 1. Every key the docs quote must exist in both languages. A key that upstream
#    renamed or dropped is a dead reference nobody would notice.
#
# 2. troubleshooting.md is where readers search with the text on their screen,
#    so its rows list the message in both languages next to the key. For a row
#    with a key, the zh fragment must match that key's zh message and the en
#    fragment its en message. For a row without one, the text must be something
#    only EsyLuban prints and that has no code: a C# literal under src/ (minus
#    src/Luban.Tests, which holds expectations, and EsyMessages.cs) or a
#    non-comment line of a shipped .bat. Neither catalog is a candidate there --
#    a coded message quoted without its code would be a quote in one language
#    only.
#
# A fragment is split on the page's placeholder spellings -- x, y, N, xxx, a+b,
# <...>, key=..., ..., and interface names such as ITableImporter, which the page
# spells out because readers search for them while the catalog holds a {1}
# there. Quotes and spaces around a placeholder stay literal: the screen shows
# 'sep' with a space on each side, and a reader pasting that into Ctrl+F finds
# nothing if the page wrote it without. The literal runs left over must occur,
# in order, inside ONE message.
#
# A missing catalog is a failure, not a skip: an upstream sync that moves the
# file would otherwise switch these checks off without a word.
$zhPath = Join-Path $repoRoot 'src\Luban.Core\Resources\messages_zh.json'
$enPath = Join-Path $repoRoot 'src\Luban.Core\Resources\messages_en.json'
if (-not (Test-Path -LiteralPath $zhPath) -or -not (Test-Path -LiteralPath $enPath)) {
    Write-Host "[FAIL] doc facts: src/Luban.Core/Resources/messages_zh.json or messages_en.json is gone, so the error-code checks cannot run"
    $failed++
} else {
    $zh = @{}; $en = @{}
    foreach ($p in ([System.IO.File]::ReadAllText($zhPath) | ConvertFrom-Json).PSObject.Properties) { $zh[$p.Name] = [string]$p.Value }
    foreach ($p in ([System.IO.File]::ReadAllText($enPath) | ConvertFrom-Json).PSObject.Properties) { $en[$p.Name] = [string]$p.Value }

    # Every "esyluban. in the file must come out of the pattern; an entry written
    # some other way (concatenated, interpolated) would silently drop out of
    # every check below.
    $esyMessages = Read-Text 'src/Luban.Core/Diagnostics/EsyMessages.cs'
    if ($null -eq $esyMessages) {
        Write-Host "[FAIL] doc facts: src/Luban.Core/Diagnostics/EsyMessages.cs is gone, so EsyLuban's own codes cannot be checked"
        $failed++
    } else {
        $literal = '"((?:[^"\\\r\n]|\\.)*)"'
        $entries = [regex]::Matches($esyMessages, "new\(""(esyluban\.[a-z0-9_.]+)"",\s*$literal,\s*$literal\)")
        $declared = [regex]::Matches($esyMessages, '"esyluban\.').Count
        if ($entries.Count -ne $declared) {
            Write-Host "[FAIL] doc facts: EsyMessages.cs declares $declared codes, but only $($entries.Count) are in the new(""code"", ""zh"", ""en"") form this check reads"
            $failed++
        }
        foreach ($e in $entries) {
            $zh[$e.Groups[1].Value] = $e.Groups[2].Value -replace '\\(["\\])', '$1'
            $en[$e.Groups[1].Value] = $e.Groups[3].Value -replace '\\(["\\])', '$1'
        }
    }

    $codePattern = '`((?:error|warn|esyluban)\.[a-z0-9_]+(?:\.[a-z0-9_]+)+)`'
    foreach ($f in Get-ChildItem -LiteralPath $docsDir -Filter *.md -File) {
        $i = 0
        foreach ($line in [System.IO.File]::ReadAllLines($f.FullName)) {
            $i++
            foreach ($m in [regex]::Matches($line, $codePattern)) {
                $key = $m.Groups[1].Value
                if (-not $zh.ContainsKey($key) -or -not $en.ContainsKey($key)) {
                    Write-Host "[FAIL] doc facts: $($f.Name):$i names error code $key, which neither the message catalogs nor EsyMessages.cs define in both languages"
                    $failed++
                }
            }
        }
    }

    $esyOnly = New-Object System.Collections.Generic.List[string]
    foreach ($f in Get-ChildItem -LiteralPath (Join-Path $repoRoot 'src') -Recurse -Filter *.cs -File) {
        if ($f.FullName -match '[\\/]Luban\.Tests[\\/]') { continue }
        if ($f.Name -eq 'EsyMessages.cs') { continue }
        $text = [System.IO.File]::ReadAllText($f.FullName)
        foreach ($m in [regex]::Matches($text, '"(?:[^"\\\r\n]|\\.)*"')) { $esyOnly.Add($m.Value) }
    }
    foreach ($dir in @('templates', 'scripts\contextmenu')) {
        foreach ($f in Get-ChildItem -LiteralPath (Join-Path $esy $dir) -Filter *.bat -File) {
            foreach ($line in [System.IO.File]::ReadAllLines($f.FullName)) {
                if ($line -match '^\s*(rem\b|::)') { continue }
                $esyOnly.Add($line)
            }
        }
    }

    # Non-capturing groups only: .NET's Regex.Split copies captured text into
    # the result, which would turn every x and N back into a required run.
    # Interface names need a lowercase third letter so INFO or IOException stay text.
    $placeholder = '<[^>]*>|\w+=\.\.\.|\.\.\.|a\+b(?:\+c)?|\bI[A-Z][a-z]\w*|\b(?:xxx|x|y|X|Y|N)\b'
    function Test-Fragment([string] $fragment, [string] $message) {
        # A quote that is nothing but placeholders leaves no literal to compare,
        # and would otherwise match every message.
        $runs = @([regex]::Split($fragment, $placeholder) | Where-Object { $_ })
        if ($runs.Count -eq 0) { return $false }
        $at = 0
        foreach ($run in $runs) {
            $i = $message.IndexOf($run, $at, [System.StringComparison]::Ordinal)
            if ($i -lt 0) { return $false }
            $at = $i + $run.Length
        }
        return $true
    }

    $trouble = Read-Text 'esyluban/docs/troubleshooting.md'
    $escapedTick = [string][char]1
    $lineNo = 0
    foreach ($line in ($trouble -split "`n")) {
        $lineNo++
        $row = [regex]::Match($line, '^\| (`.+?) \| (.*?) \|')
        if (-not $row.Success) { continue }
        $fragments = @([regex]::Matches($row.Groups[1].Value.Replace('\`', $escapedTick), '`([^`]+)`') |
            ForEach-Object { $_.Groups[1].Value.Replace($escapedTick, '`') })
        $code = [regex]::Match($row.Groups[2].Value.Trim(), "^$codePattern$")
        if ($code.Success) {
            $key = $code.Groups[1].Value
            if (-not $zh.ContainsKey($key) -or -not $en.ContainsKey($key)) { continue }
            $zhHit = @($fragments | Where-Object { Test-Fragment $_ $zh[$key] }).Count
            $enHit = @($fragments | Where-Object { Test-Fragment $_ $en[$key] }).Count
            $stray = @($fragments | Where-Object { -not (Test-Fragment $_ $zh[$key]) -and -not (Test-Fragment $_ $en[$key]) }).Count
            if ($zhHit -eq 0 -or $enHit -eq 0 -or $stray -gt 0) {
                Write-Host "[FAIL] doc facts: troubleshooting.md:$lineNo does not quote both the zh and the en text of $key"
                $failed++
            }
        } else {
            foreach ($fragment in $fragments) {
                if (-not @($esyOnly | Where-Object { Test-Fragment $fragment $_ }).Count) {
                    Write-Host "[FAIL] doc facts: troubleshooting.md:$lineNo quotes text without an error code, and it is not uncoded text from src/ or a shipped .bat (a message that has a code must be listed with it)"
                    $failed++
                }
            }
        }
    }
}

if ($failed -eq 0) {
    Write-Host "[OK]   doc facts: target counts, baselines, paths and mechanisms all agree"
    exit 0
}
exit 1
