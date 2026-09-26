# 本地化

**给谁看**：要做多语言的程序员。

**读完你能做什么**：把 `text` 字段接上文本表，并决定导出的是 key 还是文案。

**不该在这里找**：报错查询在 [出错了怎么办](troubleshooting.md)。

---

## 它解决什么

表里填的不是文案，而是**文本 key**：

| id | name | desc |
|---|---|---|
| 1001 | 长剑 | `/item_1001` |

`desc` 的类型是 `text`。真正的文案放在一张单独的文本表里，按语言分列。策划改文案
时只动那一张表，不必翻遍所有配置表。

## 文本表

一张普通的 Excel 表，一列 key、每种语言一列：

| | A | B | C | D |
|---|---|---|---|---|
| **1** | `##export` | | | |
| **2** | `##var` | `key` | `zh` | `en` |
| **3** | `##type` | `string` | `string` | `string` |
| **4** | | `/item_1001` | 长剑 | Sword |
| **5** | | `/item_1002` | 盾牌 | Shield |

列名可以自己定，只要和下面的配置对上。

## 配置

写在 `luban.conf` 的 `xargs` 里：

```
l10n.provider=default
l10n.textFile.path=../../DataTables/l10n/texts.xlsx
l10n.textFile.keyFieldName=key
l10n.textFile.languageFieldName=zh
l10n.convertTextKeyToValue=1
```

| 项 | 说明 |
|---|---|
| `provider` | 保持 `default`。换掉它需要自己实现接口，属于二次开发 |
| `textFile.path` | 文本表路径，相对 `luban.conf` 所在目录 |
| `keyFieldName` | 文本表里哪一列是 key |
| `languageFieldName` | 导出**哪种语言**。要出另一种语言就换成 `en`，重导一次 |
| `convertTextKeyToValue` | 见下 |

## `convertTextKeyToValue` 决定产物里是什么

这是唯一需要你做决定的一项。

**`=1`（替换）**：产物里直接是文案。

```json
{ "id": 1001, "desc": "长剑" }
```

**`=0`（保留 key）**：产物里还是 key，运行时自己查表。

```json
{ "id": 1001, "desc": "/item_1001" }
```

怎么选：

- 游戏**不支持运行时切语言** → 用 `=1`。每种语言导一份数据包，运行时零开销，
  也不必把文本表打进包里。
- 游戏**要在运行时切语言** → 用 `=0`。产物里留 key，运行时按当前语言查表。

两种都是正常做法，区别只在于「语言在导出时确定，还是在运行时确定」。

## 校验

`text` 字段填了文本表里不存在的 key，会怎样取决于 `convertTextKeyToValue`：

| `convertTextKeyToValue` | 报什么 | 算不算校验失败 | 产物里 |
|---|---|---|---|
| `0` | `error.validator.text.invalid_key` | 算，`--strict` 与 `check.bat` 以退出码 1 结束 | key 原样 |
| `1` | `error.l10n.missing_text` | **不算**，只记一条 ERROR，退出码仍是 0 | **写错的 key 原样进产物** |

按本页的做法分语言出包用的是 `1`，所以 key 写错时导出照样成功，`check.bat` 也拦不住。
要在提交前拦下，就让 `check.bat` 临时换成 `0` 再跑一次：

```bat
check.bat -t client -x l10n.convertTextKeyToValue=0
```

中英文原文见[排错](troubleshooting.md)。

这条校验只在配置了 `l10n.textFile.path` 时才有意义 —— 没有文本表，Luban 无从
判断 key 是否存在。也就是说，**不配 l10n 就等于关掉了这项校验**，表里的 key
写错了不会有人告诉你。

## 一个容易漏掉的点

`languageFieldName` 是**导出时**的参数，不是表里的属性。同一份表配不同的语言列
重导，就得到不同语言的产物 —— 它们的文件名是一样的，所以必须分别导到不同目录。

## 按语言分目录出包

每种语言导一次，换 `languageFieldName`，换 `outputDataDir`：

```bat
gen.bat -t client -d json -c cs-simple-json ^
  -x l10n.textFile.languageFieldName=zh ^
  -x outputDataDir=..\Client\Conf\zh

gen.bat -t client -d json ^
  -x l10n.textFile.languageFieldName=en ^
  -x outputDataDir=..\Client\Conf\en
```

同一张业务表，`zh` 目录里是「长剑」，`en` 目录里是「Sword」。发行时按语言挑一个
目录打进包，运行时不需要任何查表逻辑。

**代码只生成一次** —— 各语言的数据结构完全相同，所以第二条命令不带 `-c`。

这套做法要配 `convertTextKeyToValue=1`；用 `=0` 的话产物里是 key，本来就与语言
无关，不需要分目录。

## 表变体：按地区换整张表

Luban 5.1 起多了一种按语言或地区出数据的办法，叫表变体。同一张表可以有几份定义，
导出时用 `--variant` 选一份。上游的
[变体文档](https://www.datable.cn/docs/quality/variants)讲了三种办法的分工。
字段变体管少量数值或短文案，表变体管整张表按地区、渠道换数据，长篇多语言文案
交给本页这套文本表。它还建议一个项目选定一种为主，别混着用。

**写法。** 再建一张 sheet，B1 写同一个 `full_name`，加上 `variant`：

```
items.xlsx      A1: ##export   B1: full_name="item.TbItem" & read_schema_from_file="true"
items_en.xlsx   A1: ##export   B1: full_name="item.TbItem" & read_schema_from_file="true" & variant="en"
```

不写 `variant` 的那份是默认版，最多一份。一份也可以同时给几个变体用：`variant="en,jp"`。
几份放在同一个文件的不同 sheet 里，或者分开放，都行。

**导出时选。**

```bat
gen.bat -t client -d json --variant item.TbItem=en
gen.bat -t client -d json --variant default=en
```

`--variant 全名=en` 只切这一张表，也可以只写表名 `TbItem=en`；`default=en` 把所有带变体的
表一起切到 en。不加，或者这张表没有 en 那份，就用默认版，并给一句告警。只有变体、没留
默认版的表，不加 `--variant` 会直接中止（`error.def.table.variant_not_set`）。

**右键。** 导出哪一份由 `luban.conf` 里 `contextMenu` 的 `extraArgs` 决定，比如
`["--variant", "item.TbItem=en"]`，见[右键菜单](context-menu.md)。点哪个文件只决定导哪几张表：
右键 `items.xlsx` 还是 `items_en.xlsx`，导出的都是 `TbItem`，用的都是 `extraArgs` 选的那份。
没配 `--variant` 就是默认版。

**必须一致的：`output`、`mode`、`index`。** 不一致会报 `esyluban.b1.variant_mismatch`。
否则换一个变体，导出的文件名或生成的代码就变了，游戏里同一套代码读不了另一个地区的数据。
比的是写法，没写也算一种写法：一份写了 `index="id"`、另一份没写，也算不一致，哪怕没写的
那份默认也是 `id`。最省事的做法是复制默认版的 sheet，只在 B1 末尾加上 `& variant="en"`。
`mode` 例外，没写就是 `map`。

**最好一致的：表头**（`##var`、`##type` 那几行）。EsyLuban 不检查，因为导出时只读选中那份
的表头。结构不同，生成的代码就跟着变；没被选中的那份表头写坏了，也要等到导它那天才发现。
所以**每个变体都要单独校验一次**：

```bat
check.bat -t client
check.bat -t client --variant item.TbItem=en
```

**`default=` 也管字段变体。** 字段变体没有默认版可退，某个字段的 `variants` 里没有 en，
`--variant default=en` 就会中止（`error.def.field.variant_not_in_list`）。同时用了字段变体的
项目，表变体按表指定，别用 `default=`。

表变体也可以在 XML 或 `__tables__.xlsx` 里声明（`<table ... variant="en"/>`），和 B1 里的几份
混着用也行。上面那条一致性检查只看 B1 里的几份。
