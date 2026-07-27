<#
.SYNOPSIS
  Fail if any owned source file under esyluban/ is silently gitignored.

.DESCRIPTION
  The upstream .gitignore matches [Rr]elease/ at ANY depth. It has already
  swallowed two directories without a word of warning:
    examples/release/   785 files
    scripts/release/      3 files
  Both were found by accident. git never reports what it ignored, so the loss
  stays invisible until someone clones and finds the files gone.

  Approach: enumerate the files we intend to track, then subtract everything
  git can actually see (`git ls-files --cached --others --exclude-standard`).
  Whatever remains is being ignored.

  Two rejected alternatives, both tried and discarded:
    - `git ls-files --ignored` walks every ignored file in the repo; with
      runtime/ and dist/ present that is tens of thousands of entries and
      times out.
    - `git check-ignore --stdin` silently returns nothing when fed from a
      PowerShell pipeline, so the check passed while the trap was armed.
      A guard that cannot fail is worse than no guard.

  Build artefacts and caches are SUPPOSED to be ignored; flagging them would
  train people to dismiss this check, which is exactly how the trap survived.

  Exit 0 = clean, 1 = something owned is being ignored.
#>
[CmdletBinding()]
param([string] $EsyRoot = (Join-Path $PSScriptRoot '..\..'))

$ErrorActionPreference = 'Stop'

$esy = [System.IO.Path]::GetFullPath($EsyRoot)
$repo = [System.IO.Path]::GetFullPath((Join-Path $esy '..'))

# Directories whose source files must all be trackable.
#
# Adding a corpus or a script directory here is part of adding it: examples\
# negatives_hard existed for a while without being listed, so the files that
# prove duplicate keys and mode="one" violations still abort were themselves
# unguarded -- exactly the gap this check exists to close.
$scanDirs = @(
    'scripts', 'templates', 'baselines', 'docs',
    'examples\dev\DataTables', 'examples\dev\Tools',
    'examples\release\DataTables', 'examples\release\Tools',
    'examples\negatives_hard'
)
$sourceExt = @('.bat', '.ps1', '.py', '.md', '.json', '.conf',
               '.xlsx', '.xlsm', '.csv', '.xml', '.cs', '.sbn', '.txt', '.sh')
# Genuinely-ignored things: caches and build output, not owned source.
#
# docs\internal is a deliberate exclusion, not a trap. Those are development
# notes kept in the working tree and out of the repository -- a public project
# should not carry a directory called "internal": if it is worth publishing it
# should not be named that, and if it is not, it should not be committed.
$skipPattern = '\\__pycache__\\|\\bin\\|\\obj\\|\\TestOutputs\\|\\docs\\internal\\|~\$'

$candidates = New-Object System.Collections.Generic.List[string]
foreach ($d in $scanDirs) {
    $full = Join-Path $esy $d
    if (-not (Test-Path -LiteralPath $full)) { continue }
    Get-ChildItem -LiteralPath $full -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $sourceExt -contains $_.Extension.ToLower() -and
                       $_.FullName -notmatch $skipPattern } |
        ForEach-Object { $candidates.Add($_.FullName.Substring($repo.Length + 1)) }
}

if ($candidates.Count -eq 0) {
    Write-Host '[FAIL] no candidate files found - is EsyRoot wrong?'
    exit 1
}

Push-Location $repo
$prevEncoding = [Console]::OutputEncoding
try {
    # Two encoding traps here, both of which made this check report 19 false
    # positives -- every table whose filename contains Chinese characters:
    #   core.quotepath=false  stops git from octal-escaping non-ASCII paths
    #   OutputEncoding=UTF8   stops PowerShell from decoding them as ANSI
    # Without both, the set difference never matches and the guard cries wolf.
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    # Everything git can see: tracked, plus untracked-but-not-ignored.
    $visible = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in (& git -c core.quotepath=false ls-files --cached --others --exclude-standard)) {
        if ($p) { [void]$visible.Add($p.Replace('\', '/')) }
    }
} finally {
    [Console]::OutputEncoding = $prevEncoding
    Pop-Location
}

if ($visible.Count -eq 0) {
    Write-Host '[FAIL] git listed no files at all - not a repository?'
    exit 1
}

$ignored = @($candidates | Where-Object { -not $visible.Contains($_.Replace('\', '/')) })

if ($ignored.Count -eq 0) {
    Write-Host "[OK] $($candidates.Count) owned files checked, none gitignored."
    exit 0
}

Write-Host "[FAIL] $($ignored.Count) owned file(s) silently gitignored:"
foreach ($f in ($ignored | Select-Object -First 20)) { Write-Host "         $f" }
Write-Host ''
Write-Host '       Add a negation rule in esyluban\.gitignore, then re-run.'
Write-Host '       Diagnose one with:  git check-ignore -v <path>'
exit 1
