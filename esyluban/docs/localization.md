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
不是一个有效的文本key
```

这条校验只在配置了 `l10n.textFile.path` 时才有意义 —— 没有文本表，Luban 无从
判断 key 是否存在。也就是说，**不配 l10n 就等于关掉了这项校验**，表里的 key
写错了不会有人告诉你。

## 一个容易漏掉的点

`languageFieldName` 是**导出时**的参数，不是表里的属性。同一份表配不同的语言列
重导，就得到不同语言的产物 —— 它们的文件名是一样的，所以要么分别导到不同目录，
要么导完就搬走。

按 target 分目录的做法见 [目标与输出](targets-and-output.md)。
