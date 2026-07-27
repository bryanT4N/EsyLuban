<div align="center">

# EsyLuban

**A game config table exporter built for designers**

[![license](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)
[![platform](https://img.shields.io/badge/platform-Windows-lightgrey.svg?style=flat-square)](#platform)
[![based on](https://img.shields.io/badge/based%20on-Luban%204.10.2-informational.svg?style=flat-square)](https://github.com/focus-creative-games/luban)

[中文](README.md)

</div>

---

A fork of [Luban](https://github.com/focus-creative-games/luban) that adds
**self-contained table definitions** and a **Windows context menu**.

Each spreadsheet declares itself on its own first row, so there is no central
`__tables__.xlsx` to maintain and no command line for designers to learn.

Data output is byte-identical to upstream, held in place by regression baselines.

## Quick start

Download a release, unzip, then:

```bat
Tools\Luban\gen.bat -t client -d json
```

json files appearing under `Generated\Data\` means the toolchain works on your machine.

Two packages, same features: `standalone` runs as-is; the small one needs
[.NET 8](https://dotnet.microsoft.com/download/dotnet/8.0).

## What a table looks like

|  | A | B | C | D |
|---|---|---|---|---|
| **1** | `##export` | `full_name="item.TbItem" & read_schema_from_file="true"` | | |
| **2** | `##var` | `id` | `name` | `price` |
| **3** | `##type` | `int` | `string` | `int` |
| **4** | | 1001 | Sword | 200 |

`full_name` is the only required field in B1.

## Differences from Luban

| | Luban | EsyLuban |
|---|---|---|
| How tables are discovered | registered in `__tables__.xlsx` | each table declares itself in A1/B1 |
| Where nested types live | schema XML | optionally a `__beans__` sheet in the same file |
| How designers export | command line | right-click menu |
| Output directory wiped by mistake | happens | refused, with the reason |
| Ineffective xargs keys | silently ignored | warned, with the correct form |

Both styles coexist — an existing `__tables__.xlsx` keeps working.

## Platform

The toolchain is Windows-only: the context menu is the point of this fork, and it
lives in the Windows registry. The library that parses spreadsheets is plain .NET
and runs anywhere — a Linux CI job exists to prove that rather than claim it.

## Documentation

**Documentation is Chinese-only.** The tool itself is language-neutral; if you read
code more comfortably than Chinese, these are the two things worth knowing:

- **Table format** — `A1` holds `##export`; `B1` holds `key="value"` pairs joined by
  `&`, of which only `full_name` is required. Add `read_schema_from_file="true"`
  when the structure is declared in this sheet's own `##var`/`##type` rows.
- **Upstream boundary** — every change this fork makes to upstream code is listed in
  [`upstream_boundary.txt`](esyluban/upstream_boundary.txt), and the regression
  asserts that list matches reality. Three upstream files are modified; everything
  else is additive, registered through Luban's `Priority` mechanism.

Full documentation: [esyluban/docs/](esyluban/docs/README.md) (Chinese).

MIT. Upstream Luban is Copyright (c) Code Philosophy Technology Ltd. — see [LICENSE](LICENSE).
