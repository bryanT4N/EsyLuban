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

`text` 类型的字段会被校验：填了文本表里不存在的 key，导出时会报

```
不是一个有效的文本 key
```

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

## 表变体：B1 表暂不支持

Luban 5.1 起多了一种按语言或地区出数据的办法，叫表变体。同一个表名可以有几份
定义，导出时用 `--variant` 选一份，连结构都可以不同。上游的
[变体文档](https://www.datable.cn/docs/quality/variants)讲了三种办法的分工。
字段变体管少量数值或短文案，表变体管整张表按地区、渠道换数据，长篇多语言文案
交给本页这套文本表。它还建议一个项目选定一种为主，别混着用。

B1 表目前不能声明表变体，B1 里写了 `variant` 会直接报错。多语言文本用本页的
文本表就够了。真要按地区换整张表，就把默认那份留在 B1，其余几份在 XML 里定义
同名表并标上 `variant`：

```xml
<table name="TbItem" value="Item" input="items_en.xlsx" readSchemaFromFile="1" variant="en"/>
```

导出时加 `--variant TbItem=en` 只切这一张表；`--variant default=en` 则把所有带变体的表
一起切到 en。不加就用 B1 那份，并给一句告警。右键
菜单不会自动带这个参数，要用的话在 `luban.conf` 的 `contextMenu` 里配
`extraArgs`，见[右键菜单](context-menu.md)。
