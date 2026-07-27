# Assert that a target's `groups` actually filters FIELDS, not just tables.
#
# WHY THIS EXISTS
# ---------------
# Every data baseline in this repo comes from `-t all`, which binds c/s/e. Under
# that target nothing gets filtered except group "t", so field-level group
# filtering -- the thing test.DemoGroup exists to demonstrate -- was never
# compared against anything. The right-click chain does run client/server/editor,
# but it only counts output files; it never looks inside them.
#
# Net effect: group filtering could have started exporting every field to every
# target and the whole 17-check regression would have stayed green.
#
# The corpus makes this checkable without a new baseline set, because
# test.DemoGroup covers all four cases in one record:
#
#   x1  group="c"     client only
#   x2  group="s"     server only
#   x3  group="e"     neither (both targets bind a single group)
#   x4  group="c,s"   both
#   x5  no group      both -- and it is a nested bean whose OWN fields are
#                     filtered too (y2 is c, y3 is s), so this covers
#                     recursion into beans, which is a separate code path.
#
# Both directions matter. Asserting only "x1 is present for client" passes just
# as well when filtering is off entirely; the absence assertions are what
# actually pin the behaviour down.
#
# NOTE: keep this file ASCII-only. Windows PowerShell 5.1 reads .ps1 using the
# system ANSI code page unless the file has a UTF-8 BOM, so non-ASCII comments
# break the parser outright.
#
# Usage: check_group_filtering.ps1 <clientOutputDir> <serverOutputDir>

param(
    [Parameter(Mandatory = $true)][string]$ClientDir,
    [Parameter(Mandatory = $true)][string]$ServerDir
)

$ErrorActionPreference = 'Stop'
$failed = 0

# target -> dir, fields that must appear, fields that must NOT appear.
#
# GroupFields* covers matrix/group_fields.xlsx, which exercises the two
# field-level spellings the corpus never used before -- a `##group` row with
# actual values (all 51 in the corpus were bare markers), and `&group=` inside
# the `##type` cell (zero uses) -- plus the documented precedence between them.
#
# f_conflict is the precedence case: its `##group` row says c while its type
# cell says s. The docs say the row wins, so it must land in client and NOT in
# server. That assertion is only meaningful because f_cell_s proves the cell
# spelling works on its own; otherwise "row wins" and "cell ignored entirely"
# would look identical.
$cases = @(
    @{ Name = 'client'; Dir = $ClientDir
       Present = @('id', 'x1', 'x4', 'x5'); Absent = @('x2', 'x3')
       BeanPresent = @('y1', 'y2', 'y4'); BeanAbsent = @('y3')
       GroupFieldsPresent = @('id', 'f_none', 'f_row_c', 'f_cell_c', 'f_conflict')
       GroupFieldsAbsent  = @('f_row_s', 'f_cell_s') },
    @{ Name = 'server'; Dir = $ServerDir
       Present = @('id', 'x2', 'x4', 'x5'); Absent = @('x1', 'x3')
       BeanPresent = @('y1', 'y3', 'y4'); BeanAbsent = @('y2')
       GroupFieldsPresent = @('id', 'f_none', 'f_row_s', 'f_cell_s')
       GroupFieldsAbsent  = @('f_row_c', 'f_cell_c', 'f_conflict') }
)

foreach ($c in $cases) {
    $path = Join-Path $c.Dir 'test_tbdemogroup.json'
    if (-not (Test-Path $path)) {
        Write-Host "[FAIL] group filtering: $($c.Name) produced no test_tbdemogroup.json"
        Write-Host "       looked in: $($c.Dir)"
        $failed++
        continue
    }

    $records = Get-Content $path -Raw | ConvertFrom-Json
    if (-not $records -or $records.Count -eq 0) {
        Write-Host "[FAIL] group filtering: $($c.Name) exported an empty table"
        $failed++
        continue
    }

    $top = @($records[0].PSObject.Properties.Name)
    $bean = @()
    if ($records[0].x5) { $bean = @($records[0].x5.PSObject.Properties.Name) }

    $problems = @()
    foreach ($f in $c.Present)     { if ($top -notcontains $f)   { $problems += "missing top-level '$f'" } }
    foreach ($f in $c.Absent)      { if ($top -contains $f)      { $problems += "leaked top-level '$f'" } }
    foreach ($f in $c.BeanPresent) { if ($bean -notcontains $f)  { $problems += "missing nested '$f'" } }
    foreach ($f in $c.BeanAbsent)  { if ($bean -contains $f)     { $problems += "leaked nested '$f'" } }

    if ($problems.Count -eq 0) {
        Write-Host "[ok]   group filtering: $($c.Name) -> $($top -join ',') / x5{$($bean -join ',')}"
    } else {
        Write-Host "[FAIL] group filtering: $($c.Name)"
        foreach ($p in $problems) { Write-Host "       $p" }
        Write-Host "       got top-level: $($top -join ',')"
        Write-Host "       got nested x5: $($bean -join ',')"
        $failed++
    }
}

foreach ($c in $cases) {
    $path = Join-Path $c.Dir 'matrix_tbgroupfields.json'
    if (-not (Test-Path $path)) {
        Write-Host "[FAIL] field-level group: $($c.Name) produced no matrix_tbgroupfields.json"
        $failed++
        continue
    }
    $records = Get-Content $path -Raw | ConvertFrom-Json
    $got = @($records[0].PSObject.Properties.Name)

    $problems = @()
    foreach ($f in $c.GroupFieldsPresent) { if ($got -notcontains $f) { $problems += "missing '$f'" } }
    foreach ($f in $c.GroupFieldsAbsent)  { if ($got -contains $f)    { $problems += "leaked '$f'" } }

    if ($problems.Count -eq 0) {
        Write-Host "[ok]   field-level group: $($c.Name) -> $($got -join ',')"
    } else {
        Write-Host "[FAIL] field-level group: $($c.Name)"
        foreach ($p in $problems) { Write-Host "       $p" }
        if ($problems -match "f_conflict") {
            Write-Host "       f_conflict is the precedence case: its ##group row says c,"
            Write-Host "       its type cell says s. The row is documented to win."
        }
        Write-Host "       got: $($got -join ',')"
        $failed++
    }
}

# matrix.TbBasic carries group="c;s" -- a SEMICOLON, on purpose.
#
# B1's group= replaces the XML <table group="..."> attribute, and the XML side
# has always split on both ',' and ';'. B1 split on ',' only, so group="c;s"
# became one group literally named "c;s", which matches no target: the table
# vanished from every export without a word. The docs meanwhile described the
# XML behaviour, so following them produced a silently missing table.
#
# Asserting it appears under BOTH single-group targets pins the separator down.
# A regression here shows up as this table missing, not as a wrong field list.
foreach ($c in $cases) {
    $path = Join-Path $c.Dir 'matrix_tbbasic.json'
    if (Test-Path $path) {
        Write-Host "[ok]   semicolon group: matrix.TbBasic present for $($c.Name)"
    } else {
        Write-Host "[FAIL] semicolon group: matrix.TbBasic missing for $($c.Name)"
        Write-Host "       Its B1 says group=`"c;s`". If ';' stopped being a separator,"
        Write-Host "       the group is now one name -- `"c;s`" -- matching no target."
        $failed++
    }
}

if ($failed -gt 0) {
    Write-Host ""
    Write-Host "[FAIL] group filtering: $failed problem(s)."
    exit 1
}
Write-Host "[OK] group filtering: fields, nested bean fields, and ';' separator all correct."
exit 0
