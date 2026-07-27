# 示例工程：出处与构成

## 数据来自哪里

本目录下**绝大部分配置表源自上游示例仓库**
[`focus-creative-games/luban_examples`](https://github.com/focus-creative-games/luban_examples)
—— 与 Luban 主仓库分开的独立仓库，采用 **MIT License, Copyright (c) 2020 focus creative games**。

| | |
|---|---|
| **取数自** | `luban_examples@879f5c5`（Luban v4.5.0 时期） |
| **取数时间** | 2026-01-22 / 23 |
| **许可证核实** | 2026-07-26 |
| **迁移记录** | `esyluban/docs/internal/archive/migration_report_20260122.json`，逐文件记录，共 215 项 |

> 这三个日期此前只写了一个「2026-07-26 clone 核实」，很容易被读成取数日期 ——
> 实际取数在半年前。而缺的那一项恰恰是最要紧的：**上游 commit hash**。
> `core` 基线的全部价值建立在「这份语料对应上游某个确切状态」之上，而那个状态
> 得有个 hash 才说得清。

**迁移做了什么**：把上游集中式的 `__tables__.xlsx` 表定义，改写为每张 Excel 自己的
`A1=##export` + `B1` 元数据。**数据内容基本未改，改的是「表定义写在哪里」。**

## 我们的 XML 与上游差在哪（完整清单）

`Defines/*.xml` 没有经过迁移脚本 —— `migrate_xlsx.py` 只处理 `xlsx/xls/xlsm/csv`。
所以这 7 个文件能跟上游逐字节对，差异是可以穷举的，不必靠信任。归一化掉格式噪音
后，**全部非 `<table>` 差异只有两类**：

| 类别 | 数量 | 性质 |
|---|---|---|
| XML 注释被整体丢弃 | 10 处（每个文件都归零） | **我方缺陷**，已处置，见下 |
| `alias= "换装场景"` → `alias="换装场景"` | 1 处 | 属性内空格归一，无语义 |
| 其它内容差异 | **0** | —— |

丢注释的原因是这批 XML 被解析后重新序列化过：`parse → serialize` 的往返默认不保留
注释节点，同时把 `/>` 规整成 ` />`、重排缩进。这也解释了为什么**每个文件的注释数都
恰好归零** —— 不是有人挑着删，是一次机械往返的副作用。

注释对导出零影响，所以全部基线一路绿灯，没有任何东西报警。这正是它能潜伏这么久的
原因，也是现在有 `scripts/test/check_xml_comments.ps1` 守着的原因。

### 恢复了三条

主体仍在 XML 里、能原样放回的：

| 文件 | 注释 |
|---|---|
| `ai.xml` | `<!--bean name="TickableTask">…` 被禁用的 bean 定义 |
| `common.xml` | `<!-- 背包相关 -->` 分节标题 |
| `test.xml` | `<!--var name="multi_rows3" …/-->` 被禁用的字段 |

### 另外七条不恢复，各有原因

它们的**主体是 `<table>` 声明**，而 EsyLuban 的全部要点就是把 `<table>` 搬进各表
自己的 B1。注释留在 XML 里就是在给不存在的东西写说明：

| 注释 | 不恢复的原因 |
|---|---|
| `test.xml` 两条 `index=` 写法说明 | 讲的是下一行 `<table index=…>` 怎么写，主体已迁走 —— **且内容是错的**，见下 |
| `test.xml` 三条被注释掉的 `<table>` 声明 | 集中式语法的禁用示例，放回等于示范已废弃的写法 |
| `tag.xml` `TagSwitch`、`test.xml` `TestJson2` | 注释块里 bean 与 `<table>` 声明混写，整段放回会把集中式语法带回来 |

### 那两条 index 说明本来就是错的

上游原文：

```xml
<!-- index="id1,id2,id3" index="id1+id2+id3" index="id1&id2&id3" 都可以表达是 (id1,id2,id3) 联合唯一索引 -->
<!-- index="id1|id2|id3" 表示这3个key分别都是唯一索引 -->
```

对照实现 `src/Luban.Core/Defs/DefTable.cs`：

```csharp
var indexs = Index.Split('+', ',')...                          // 分隔符只有 + 和 ,
IsUnionIndex = IndexList.Count > 1 && !Index.Contains(',');    // 不含逗号 -> 联合
MultiKey     = IndexList.Count > 1 &&  Index.Contains(',');    // 含逗号   -> 各自独立
```

三个说法全错：逗号是**各自独立**不是联合；`&` 和 `|` 根本不是分隔符，写了会被当成
一个叫 `id1&id2&id3` 的字段名，报 `index:'…' 字段不存在`。上游在 `879f5c5` 之后
把这两行删掉了 —— 大概率正因为它是错的。

正确的说法在 [表格式参考 · index 的语义随 mode 变](../docs/table-format.md)，
按实现写的，不是按注释写的。

### 另有三行错位的说明文字，已跟进上游的修正

`test.xml` 的 `DemoGroup` 里，`x1`–`x3` 后面跟着的说明文字整体错位了一格：

```xml
<var name="x1" … group="c" /> 默认属于所有分组c,s,e   ← 明明有 group="c"
<var name="x2" … group="s" />属于 c 分组              ← 明明是 s
<var name="x3" … group="e" />属于s分组                ← 明明是 e
```

这些是 `/>` 后面的**文本节点**，不是 XML 注释，所以没被序列化器吃掉，逐字节忠于
`879f5c5`。**不是我们加 `##export` 行时弄歪的** —— 它们来自紧邻的 `InnerGroup`，
在那里 `y1` 确实没有 group、`y2` 是 c、`y3` 是 s，四行都对；复制到 `DemoGroup`
后每个字段都多了一个 group，说明文字却没跟着改。

上游在 `879f5c5` 之后把这三行删掉了，本仓库跟进了这处修正。所以这是**语料相对
`879f5c5` 的唯一一处有意偏离**，记在这里以免下次复核时被当成意外。

## 为什么不跟进上游最新版

**因为"旧版有误导性内容"这个理由已经在上面被直接消掉了**，而不是靠换版本消掉的。
剩下的差异不值得重跑迁移：

- 上游 `879f5c5` → `725e280`（2026-07-19）对 `DataTables` 只有三个提交
- 绝大部分是 `Datas/` → `Data/` 目录改名，波及 128 个文件但内容不变 ——
  **而我们的语料早已不用上游的目录结构**
- `test.xml` 里 `InnerGroup` 与 `x5` 各加了一个 `group="c"`，实测对导出零影响：
  `core` 基线与当前输出逐字节一致
- 新增一个 `lite_types.lit`（Luban lite 格式的定义文件，与自包含路线无关）
- **没有新增任何表**

而代价是重跑一次迁移 —— 那个工具至今没有在复杂语料上验证过（见
`scripts/authoring/migrate_xlsx.py` 文件头）。所以语料停在 `879f5c5`。

上游若出现真正的新表或新特性语料，届时再评估。

### 复核方法

不必相信上面这张表。重跑一遍：

```bash
git clone https://github.com/focus-creative-games/luban_examples
git -C luban_examples checkout 879f5c5
# 逐文件比对 luban_examples/DataTables/Defines/*.xml 与本仓库同名文件，
# 归一化 `\s*/>` -> ` />` 和缩进后，差异应当只剩三类，别无其它：
#   1. <table> 声明行         —— 已搬进各表 B1
#   2. 上面列出的 7 条未恢复注释
#   3. DemoGroup x1-x3 的三行错位说明文字 —— 跟进了上游后来的删除
```

`scripts/test/check_xml_comments.ps1` 把其中可离线验证的部分接进了回归：三条恢复
的注释必须在、不许出现活的 `<table>` 声明、dev 与 release 两份副本必须逐字节一致。

正因为数据来自上游，回归测试的**核心基线**才有意义：
`esyluban/baselines/core` 的 53 个 json 是上游未迁移版本跑出来的输出，
用它逐字节比对，可以证明"换了定义方式，结果一字未变"。

## 哪些是 EsyLuban 自建的

`dev/DataTables` 约 139 个文件中，自建的只有 8 个：

| 路径 | 用途 |
|---|---|
| `matrix/`（3 个） | 功能覆盖矩阵测例，含 `group_fields.xlsx`：字段级 group 的三种写法及优先级 |
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
痛点之一（见 `docs/internal/archive/esyluban_complete_analysis_aborted.md`）。
现在的做法是：运行时全仓库共享一份，配置随工程走，再由右键菜单直接导出所选范围。
