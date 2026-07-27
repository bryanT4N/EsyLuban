# Assert the XML comments in examples/dev/DataTables/Defines survive.
#
# WHY THIS EXISTS
# ---------------
# Those files were run through an XML parse->serialize round trip at some point
# during the migration. That round trip drops comment nodes: all 10 comments
# upstream had were gone, silently. Nothing failed, because comments have zero
# effect on export -- every baseline stayed green while the corpus quietly lost
# its inline documentation.
#
# Three of the ten were restored (the ones whose subject still lives in the XML).
# The other seven were deliberately not restored -- their subject was a <table>
# declaration, which EsyLuban moves into each sheet's B1. See
# esyluban/examples/README.md for the per-comment reasoning.
#
# So this guard checks two directions:
#   - the restored three are present  (a future round trip would eat them again)
#   - no <table ...> declaration reappears outside a comment (the migration's
#     whole point is that table declarations do not live in these files)
#
# NOTE: keep this file ASCII-only. Windows PowerShell 5.1 reads .ps1 using the
# system ANSI code page unless the file has a UTF-8 BOM, so non-ASCII comments
# break the parser outright.

$ErrorActionPreference = 'Stop'

# dev and release each carry their own copy of these seven files, and they are
# byte-identical by intent. Checking only one would let the other rot -- the same
# trap the three gen.bat copies fell into.
$roots = @('dev', 'release') | ForEach-Object {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\examples\$_\DataTables\Defines"))
}

# Substring -> file it must appear in. Substrings, not whole blocks, so that
# re-indentation does not cause a false alarm; the point is presence, not layout.
$required = @(
    @{ File = 'ai.xml';     Text = '<!--bean name="TickableTask">' },
    @{ File = 'common.xml'; Text = '<!-- ' + [char]0x80CC + [char]0x5305 + [char]0x76F8 + [char]0x5173 + ' -->' },
    @{ File = 'test.xml';   Text = '<!--var name="multi_rows3" type="set,MultiRowType2"/-->' }
)

$failed = 0

foreach ($root in $roots) {
    $which = Split-Path (Split-Path (Split-Path $root -Parent) -Parent) -Leaf

    foreach ($r in $required) {
        $path = Join-Path $root $r.File
        if (-not (Test-Path $path)) {
            Write-Host "[FAIL] $which/$($r.File): missing file"
            $failed++
            continue
        }
        $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
        if ($text.Contains($r.Text)) {
            Write-Host "[ok]   $which/$($r.File): comment present"
        } else {
            Write-Host "[FAIL] $which/$($r.File): upstream comment lost -- an XML round trip drops comment nodes"
            Write-Host "       expected to find: $($r.Text)"
            $failed++
        }
    }

    # Second direction: no live <table> declaration in these files. Blank out
    # comment bodies first -- test.xml legitimately contains commented-out ones.
    foreach ($f in (Get-ChildItem $root -Filter *.xml)) {
        $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        $masked = [regex]::Replace($text, '<!--.*?-->', { ' ' * $args[0].Length }, 'Singleline')
        $hits = [regex]::Matches($masked, '<table\b')
        if ($hits.Count -gt 0) {
            Write-Host "[FAIL] $which/$($f.Name): $($hits.Count) live <table> declaration(s)"
            Write-Host "       EsyLuban moves these into each sheet's B1; one here means a"
            Write-Host "       table is declared twice, or an upstream file was copied back in."
            $failed++
        }
    }
}

# Third: the two copies must stay byte-identical. Get-FileHash is absent on the
# PowerShell builds this repo targets, hence the raw SHA256.
$sha = [System.Security.Cryptography.SHA256]::Create()
try {
    foreach ($f in (Get-ChildItem $roots[0] -Filter *.xml)) {
        $other = Join-Path $roots[1] $f.Name
        if (-not (Test-Path $other)) {
            Write-Host "[FAIL] release/$($f.Name): missing, but dev has it"
            $failed++
            continue
        }
        $a = [BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($f.FullName)))
        $b = [BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($other)))
        if ($a -ne $b) {
            Write-Host "[FAIL] $($f.Name): dev and release copies differ"
            Write-Host "       They are identical by intent -- edit one, copy to the other."
            $failed++
        }
    }
} finally {
    $sha.Dispose()
}

if ($failed -gt 0) {
    Write-Host ""
    Write-Host "[FAIL] Defines XML check: $failed problem(s)."
    exit 1
}
Write-Host "[OK] Defines XML comments intact, no live table declarations."
exit 0
