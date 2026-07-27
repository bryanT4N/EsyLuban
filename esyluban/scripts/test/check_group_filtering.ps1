# Assert what `group` actually does, across every level it operates on.
#
# WHY THIS EXISTS
# ---------------
# Every baseline in this repo comes from `-t all`, which binds c/s/e. Under that
# target group filters nothing but the "t" group, so group's real behaviour was
# never compared against anything. The right-click chain does run client and
# server, but it only counts output files; it never looks inside them.
#
# Net effect: group filtering could have stopped working entirely -- every table
# and every field exported to every target -- and the whole regression would
# still have been green.
#
# WHAT IS COVERED
# ---------------
#   table level, both directions   test.TbDemoGroup_C / _S / _E
#   default:false                  test.TbDemoGroup_T -- group "t" is declared
#                                  default:false, so it must appear NOWHERE
#                                  except a target that binds "t" explicitly
#   field level (XML <var group=>) test.DemoGroup x1..x4
#   nested bean fields             test.InnerGroup, reached through x5 -- a
#                                  separate recursion path from top-level fields
#   field level (##group row)      matrix.TbGroupFields f_row_*
#   field level (&group= in cell)  matrix.TbGroupFields f_cell_*
#   precedence between those two   matrix.TbGroupFields f_conflict
#   ',' vs ';' separator           matrix.TbBasic, declared group="c;s"
#   generated code                 all of the above again on the code side,
#                                  which is a different path: it drops whole
#                                  table classes and bean members, not json keys
#   <bean group=> / <enum group=>  matrix.xml -- the one define file in this
#                                  repo that is ours, added because the corpus
#                                  had zero uses of either. They are referenced
#                                  by no table on purpose: type-level group is
#                                  decided in CollectRefTypes, independently of
#                                  whether anything points at the type
#   group="*"                      GroupAllBean -- expands to every declared
#                                  group, which is NOT the same as writing no
#                                  group (that means the default ones only).
#                                  It must therefore appear for every target
#
# Both directions matter everywhere. "x1 is present for client" passes just as
# well when filtering is off entirely; the absence assertions are what pin the
# behaviour down. Every check below therefore has a matching negative.
#
# NOTE: keep this file ASCII-only. Windows PowerShell 5.1 reads .ps1 using the
# system ANSI code page unless the file has a UTF-8 BOM, so non-ASCII comments
# break the parser outright.
#
# Usage: check_group_filtering.ps1 <clientData> <serverData> <clientCode> <serverCode>

param(
    [Parameter(Mandatory = $true)][string]$ClientDir,
    [Parameter(Mandatory = $true)][string]$ServerDir,
    [Parameter(Mandatory = $true)][string]$ClientCodeDir,
    [Parameter(Mandatory = $true)][string]$ServerCodeDir
)

$ErrorActionPreference = 'Stop'
$failed = 0

function Fail($title, $lines) {
    Write-Host "[FAIL] $title"
    foreach ($l in $lines) { Write-Host "       $l" }
    $script:failed++
}

$cases = @(
    @{ Name = 'client'; Dir = $ClientDir; CodeDir = $ClientCodeDir
       # test.DemoGroup: x1=c x2=s x3=e x4=c,s x5=(none, nested bean)
       Present = @('id', 'x1', 'x4', 'x5'); Absent = @('x2', 'x3')
       # test.InnerGroup: y1=(none) y2=c y3=s y4=c,s
       BeanPresent = @('y1', 'y2', 'y4'); BeanAbsent = @('y3')
       GroupFieldsPresent = @('id', 'f_none', 'f_row_c', 'f_cell_c', 'f_conflict')
       GroupFieldsAbsent  = @('f_row_s', 'f_cell_s')
       TablesPresent = @('test_tbdemogroup_c.json')
       TablesAbsent  = @('test_tbdemogroup_s.json', 'test_tbdemogroup_e.json',
                         'test_tbdemogroup_t.json')
       CodePresent = @('TbDemoGroup_C.cs', 'GroupClientBean.cs', 'EGroupClient.cs',
                       'GroupAllBean.cs')
       CodeAbsent  = @('TbDemoGroup_S.cs', 'TbDemoGroup_E.cs', 'TbDemoGroup_T.cs',
                       'GroupServerBean.cs', 'EGroupServer.cs')
       MemberPresent = @('X1'); MemberAbsent = @('X2', 'X3') },

    @{ Name = 'server'; Dir = $ServerDir; CodeDir = $ServerCodeDir
       Present = @('id', 'x2', 'x4', 'x5'); Absent = @('x1', 'x3')
       BeanPresent = @('y1', 'y3', 'y4'); BeanAbsent = @('y2')
       GroupFieldsPresent = @('id', 'f_none', 'f_row_s', 'f_cell_s')
       GroupFieldsAbsent  = @('f_row_c', 'f_cell_c', 'f_conflict')
       TablesPresent = @('test_tbdemogroup_s.json')
       TablesAbsent  = @('test_tbdemogroup_c.json', 'test_tbdemogroup_e.json',
                         'test_tbdemogroup_t.json')
       CodePresent = @('TbDemoGroup_S.cs', 'GroupServerBean.cs', 'EGroupServer.cs',
                       'GroupAllBean.cs')
       CodeAbsent  = @('TbDemoGroup_C.cs', 'TbDemoGroup_E.cs', 'TbDemoGroup_T.cs',
                       'GroupClientBean.cs', 'EGroupClient.cs')
       MemberPresent = @('X2'); MemberAbsent = @('X1', 'X3') }
)

function KeysOf($path) {
    if (-not (Test-Path $path)) { return $null }
    $records = Get-Content $path -Raw | ConvertFrom-Json
    if (-not $records -or $records.Count -eq 0) { return @() }
    return @($records[0].PSObject.Properties.Name)
}

foreach ($c in $cases) {
    $n = $c.Name

    # --- 1. table level -----------------------------------------------------
    $problems = @()
    foreach ($f in $c.TablesPresent) {
        if (-not (Test-Path (Join-Path $c.Dir $f))) { $problems += "missing table $f" }
    }
    foreach ($f in $c.TablesAbsent) {
        if (Test-Path (Join-Path $c.Dir $f)) { $problems += "leaked table $f" }
    }
    if ($problems.Count -eq 0) {
        Write-Host "[ok]   table-level group: $n"
    } else {
        # Only explain default:false when that is the check that actually broke;
        # printing it next to an unrelated leak sends the reader after the wrong
        # thing.
        $extra = @()
        if ("$problems" -match 'tbdemogroup_t') {
            $extra += "TbDemoGroup_T carries group 't', declared default:false in luban.conf,"
            $extra += "so it must not appear for any target that does not bind 't' by name."
        }
        Fail "table-level group: $n" ($problems + $extra)
    }

    # --- 2. field level, XML <var group=> + nested bean ----------------------
    $top = KeysOf (Join-Path $c.Dir 'test_tbdemogroup.json')
    if ($null -eq $top) {
        Fail "field-level group: $n" @("no test_tbdemogroup.json in $($c.Dir)")
    } else {
        $records = Get-Content (Join-Path $c.Dir 'test_tbdemogroup.json') -Raw | ConvertFrom-Json
        $bean = @()
        if ($records[0].x5) { $bean = @($records[0].x5.PSObject.Properties.Name) }

        $problems = @()
        foreach ($f in $c.Present)     { if ($top -notcontains $f)  { $problems += "missing top-level '$f'" } }
        foreach ($f in $c.Absent)      { if ($top -contains $f)     { $problems += "leaked top-level '$f'" } }
        foreach ($f in $c.BeanPresent) { if ($bean -notcontains $f) { $problems += "missing nested '$f'" } }
        foreach ($f in $c.BeanAbsent)  { if ($bean -contains $f)    { $problems += "leaked nested '$f'" } }

        if ($problems.Count -eq 0) {
            Write-Host "[ok]   field-level group (XML): $n -> $($top -join ',') / x5{$($bean -join ',')}"
        } else {
            Fail "field-level group (XML): $n" ($problems + @(
                "got top-level: $($top -join ',')", "got nested x5: $($bean -join ',')"))
        }
    }

    # --- 3. field level, ##group row vs &group= in the type cell ------------
    $got = KeysOf (Join-Path $c.Dir 'matrix_tbgroupfields.json')
    if ($null -eq $got) {
        Fail "field-level group (Excel): $n" @("no matrix_tbgroupfields.json in $($c.Dir)")
    } else {
        $problems = @()
        foreach ($f in $c.GroupFieldsPresent) { if ($got -notcontains $f) { $problems += "missing '$f'" } }
        foreach ($f in $c.GroupFieldsAbsent)  { if ($got -contains $f)    { $problems += "leaked '$f'" } }
        if ($problems.Count -eq 0) {
            Write-Host "[ok]   field-level group (Excel): $n -> $($got -join ',')"
        } else {
            $extra = @("got: $($got -join ',')")
            if ("$problems" -match 'f_conflict') {
                $extra += "f_conflict is the precedence case: its ##group row says c,"
                $extra += "its type cell says s. The row is documented to win."
            }
            Fail "field-level group (Excel): $n" ($problems + $extra)
        }
    }

    # --- 4. the same thing on the generated-code side -----------------------
    if (-not (Test-Path $c.CodeDir)) {
        Fail "group in generated code: $n" @("no code output at $($c.CodeDir)")
    } else {
        $files = @(Get-ChildItem $c.CodeDir -Recurse -Filter *.cs | ForEach-Object { $_.Name })
        $problems = @()
        foreach ($f in $c.CodePresent) { if ($files -notcontains $f) { $problems += "missing class file $f" } }
        foreach ($f in $c.CodeAbsent)  { if ($files -contains $f)    { $problems += "leaked class file $f" } }

        # Members of the bean class follow the field-level groups too.
        $beanFile = Join-Path $c.CodeDir 'test\DemoGroup.cs'
        if (-not (Test-Path $beanFile)) {
            $problems += "missing test\DemoGroup.cs"
        } else {
            $src = [System.IO.File]::ReadAllText($beanFile, [System.Text.Encoding]::UTF8)
            foreach ($m in $c.MemberPresent) {
                if ($src -notmatch "readonly\s+\w+\s+$m;") { $problems += "missing member $m" }
            }
            foreach ($m in $c.MemberAbsent) {
                if ($src -match "readonly\s+\w+\s+$m;") { $problems += "leaked member $m" }
            }
        }

        if ($problems.Count -eq 0) {
            Write-Host "[ok]   group in generated code: $n"
        } else {
            Fail "group in generated code: $n" $problems
        }
    }
}

# --- 5. ';' is a group separator, same as ',' -------------------------------
#
# matrix.TbBasic carries group="c;s" on purpose. Upstream splits group values on
# both ',' and ';' (SchemaLoaderUtil.CreateGroups), and B1's group= replaces the
# very attribute that goes through it. B1 once had its own copy that split on
# ',' alone, so group="c;s" became a single group named literally "c;s".
#
# Table groups ARE validated (DefTypeBase.PreCompile checks them against the
# declared set), so the failure mode was an abort with `group:c;s not found` --
# a message naming a group nobody wrote. Measured, not assumed: an unsplittable
# table group exits 1; it is FIELD-level groups that fail silently.
#
# Upstream's own corpus has no ';' in any group value, which is why nothing ever
# exercised this. The detection was never missing; the data was.
#
# This check therefore also covers the abort path: a regression here shows up as
# the whole export failing, not just this table going missing.
foreach ($c in $cases) {
    if (Test-Path (Join-Path $c.Dir 'matrix_tbbasic.json')) {
        Write-Host "[ok]   ';' separator: matrix.TbBasic present for $($c.Name)"
    } else {
        Fail "';' separator: matrix.TbBasic missing for $($c.Name)" @(
            'Its B1 says group="c;s". If ";" stopped being a separator, that is',
            'one group named "c;s" -- the export aborts with `group:c;s not found`.')
    }
}

if ($failed -gt 0) {
    Write-Host ""
    Write-Host "[FAIL] group: $failed check(s) wrong."
    exit 1
}
Write-Host "[OK] group: table level, field level, nested beans, precedence, ';' and generated code all correct."
exit 0
