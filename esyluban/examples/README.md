# 示例工程：出处与构成

## 数据来自哪里

本目录下**绝大部分配置表源自上游示例仓库**
[`focus-creative-games/luban_examples`](https://github.com/focus-creative-games/luban_examples)
—— 与 Luban 主仓库分开的独立仓库，采用 **MIT License, Copyright (c) 2020 focus creative games**
（2026-07-26 clone 核实）。

- **迁移时间**：2026-01-22 / 23
- **迁移做了什么**：把上游集中式的 `__tables__.xlsx` 表定义，改写为每张 Excel 自己的
  `A1=##export` + `B1` 元数据。**数据内容基本未改，改的是"表定义写在哪里"。**
- **迁移记录**：`esyluban/docs/archive/migration_report_20260122.json`
  （逐文件记录，共处理 215 项）

正因为数据来自上游，回归测试的**核心基线**才有意义：
`esyluban/baselines/core` 的 53 个 json 是上游未迁移版本跑出来的输出，
用它逐字节比对，可以证明"换了定义方式，结果一字未变"。

## 哪些是 EsyLuban 自建的

`dev/DataTables` 约 138 个文件中，自建的只有 7 个：

| 路径 | 用途 |
|---|---|
| `matrix/`（2 个） | 功能覆盖矩阵测例 |
| `negatives/`（2 个） | 故意失败的负例（regex / range / set / not-default / path） |
| `Assets/`（1 个） | path 校验用的占位资源 |
| `test/inline_defs.xlsx` | 内联 `__enums__` / `__beans__` 子表测例 |
| `test/minimal_b1.xlsx` | 最简 B1 写法样例（仅 `full_name` + `read_schema_from_file`） |

其余目录（`ai` `blueprint` `bonus` `clothes` `common` `error` `item` `l10n` `mail`
`role` `tag_datas` `test` `Defines`）均来自上游。所以像 `test.TestExcelBean1`、
`ai.TbBlackboard`、`通用道具表` 这类看着突兀的表名，都是上游的测试资产。

## dev / release 的分法是 EsyLuban 自己的

**不是上游的划分。** 上游 `luban_examples` 按「目标语言 + 数据格式」分工程：

```
luban_examples/Projects/          （共 20+ 个，各自带一套 gen.bat）
├─ Csharp_Unity_json/  Csharp_Unity_bin/  Csharp_Unity_Editor_json/
├─ Csharp_DotNet_bin/  Csharp_DotNet_json/  Csharp_NewtonSoft_json/
├─ Cpp_rawptr_bin/  Cpp_sharedptr_bin/  Dart_json/  Flatbuffers_json/
└─ CfgValidator/  Csharp_Protobuf/  …
```

EsyLuban 改为**按用途分**，是 2026-01-24 从单一的 `EsyLuban_Example` 拆出来的
（可见 `esyluban/baselines/baseline_log.md` 的时间线：16:02 还是单一工程，
20:11 已变为 `_dev`）：

| | 回答的问题 | 特征 |
|---|---|---|
| `dev` | **生成结果对不对？** | 含 `matrix/`、`negatives/`、`Assets/`；输出到 `TestOutputs/`，与两份基线做 SHA256 逐文件比对 |
| `release` | **生成的东西真能用吗？** | 数据干净、无负例；输出进真实 Unity 工程 `Projects/Csharp_Unity_json` |

两者不可合并：给 `release` 加负例就没法当示例（满屏报错），给 `dev` 去掉负例
就失去负向覆盖。

上游那一堆按语言分的工程里，本仓库只保留了 `Csharp_Unity_json` 一个
（它本身仍是上游资产），其余未纳入。

## 顺带一提

上游"每个工程各有一套 `gen.bat`、要手动进目录去跑"，正是 EsyLuban 立项时记录的
痛点之一（见 `docs/archive/esyluban_complete_analysis_aborted.md`）。
现在的做法是：运行时全仓库共享一份，配置随工程走，再由右键菜单直接导出所选范围。
