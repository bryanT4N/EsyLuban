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
l10n.languages=zh,en
l10n.convertTextKeyToValue=1
```

| 项 | 说明 |
|---|---|
| `provider` | 保持 `default`。换掉它需要自己实现接口，属于二次开发 |
| `textFile.path` | 文本表路径，相对 `luban.conf` 所在目录 |
| `keyFieldName` | 文本表里哪一列是 key |
| `languages` | 项目支持的语言，和文本表的列名一致，第一种是默认语言。每种语言各导出一份，见下面「每种语言导出一份」 |
| `textFile.languageFieldName` | 只有一种语言时写它，代替 `languages` |
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

- 游戏**不支持运行时切语言** → 用 `=1`。每种语言导出一份数据，运行时零开销，
  也不必把文本表打进包里。
- 游戏**要在运行时切语言** → 用 `=0`。产物里留 key，运行时按当前语言查表。

两种都是正常做法，区别只在于「语言在导出时确定，还是在运行时确定」。

## 校验

`text` 字段填了文本表里不存在的 key，会怎样取决于 `convertTextKeyToValue`：

| `convertTextKeyToValue` | 报什么 | 算不算校验失败 | 产物里 |
|---|---|---|---|
| `0` | `error.validator.text.invalid_key` | 算，`--strict` 与 `check.bat` 以退出码 1 结束 | key 原样 |
| `1` | `error.l10n.missing_text` | **不算**，只记一条 ERROR，退出码仍是 0 | **写错的 key 原样进产物** |

用 `1` 时，key 写错导出照样成功，`check.bat` 也拦不住。
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

## 每种语言导出一份

`languages` 写了几种语言，导出时就每种各出一份，不用每种语言手动导一次：

```
Generated/Data/       zh，默认语言
Generated/Data/en/    en
```

同一张业务表，`Data/` 里是「长剑」，`Data/en/` 里是「Sword」。每个目录都是完整的
一份，游戏按当前语言读对应的目录。代码只生成一份，各语言通用。`check.bat` 会把每种
语言都校验一遍。

用 `convertTextKeyToValue=0` 的话，产物里是 key，与语言无关，文案在运行时按语言查。
这时只有某种语言有翻译以外的差异（见下一节），才需要写 `languages`。

## 某种语言的版本有翻译以外的差异

只有英文版才有的活动、英文版单独定的价格、英文版独有的文本行，这些不是翻译，由策划
放进 `variant_en` 文件夹，怎么放见[写一张表](writing-tables.md#某种语言的版本要不一样的数据)。
导出时英文那一份带上这些差异，其它语言不受影响。

`variant_` 后面的名字必须是 `languages` 里写了的语言，写错了会报错。右键导出的范围由
选中的文件和它影响到的语言决定，不用另外配置。
