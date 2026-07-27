# 配置参考

**给谁看**：程序员。要写或改这个项目的 `luban.conf`，或者要弄清楚某个命令行参数覆盖了什么。

**读完你能做什么**：看懂 `luban.conf` 每一个字段和 `xargs` 每一个键，知道命令行怎么覆盖它们。

**不该在这里找什么**：选哪种数据格式、哪种生成语言、产物落在哪个目录 —— 那些在[目标与输出](targets-and-output.md)。表怎么填在[写一张表](writing-tables.md)，右键菜单的配置在[右键菜单](context-menu.md)。

---

## luban.conf 的五个字段

Luban 只读这五个：`groups`、`schemaFiles`、`dataDir`、`targets`、`xargs`。多写的字段被静默忽略 —— `contextMenu` 就是这样一个，Luban 不看它，右键脚本看。

能直接用的最小配置（`esyluban/templates/luban.conf` 的骨架，那份还多一段 `contextMenu`）：

```json
{
  "groups":      [ {"names":["c"], "default":true} ],
  "schemaFiles": [ ],
  "dataDir": "../../DataTables",
  "targets":     [ {"name":"client", "manager":"Tables", "groups":["c"], "topModule":"cfg"} ],
  "xargs": [
    "outputDataDir=../../Generated/Data",
    "outputCodeDir=../../Generated/Code"
  ]
}
```

所有相对路径都以 `luban.conf` 所在目录（即 `Tools/Luban/`）为基准。

### groups

声明有哪些分组、哪些是默认组。

```json
[ {"names":["c"], "default":true},
  {"names":["s"], "default":true},
  {"names":["t"], "default":false} ]
```

`##group` 留空的字段属于所有默认组。`default:false` 的组只有被 target 显式绑定时才会导出 —— 因此一个只绑 `t` 组的 target，配上一张 `##group` 全空的表，会导出**零张表**。零产物 + 默认开启的清理曾是静默清空输出目录的主要路径，现在有安全闸拦着，见[目标与输出 · 输出目录会被清空](targets-and-output.md#输出目录会被清空)。

### schemaFiles

schema 定义的入口。`type` 留空表示按文件内容自己声明，`bean` / `enum` 则明确指定：

```json
[ {"fileName":"../../DataTables/Defines",        "type":""},
  {"fileName":"../../DataTables/__beans__.xlsx", "type":"bean"},
  {"fileName":"../../DataTables/__enums__.xlsx", "type":"enum"} ]
```

给目录会被展开成目录下的全部文件。列出的路径不存在会直接报错（`failed to load schema file`）。

**结构写在表自己身上时，这里可以留空数组** —— 模板就是空的。那种表在 B1 加 `read_schema_from_file="true"`，结构从本表的 `##var`/`##type` 行读。

⚠ 不要把数据目录配进 `schemaFiles`。「扫描数据目录、发现哪些表要导出」是 tableImporter 的职责，`schemaFiles` 只处理显式列出的文件。

### dataDir

数据根目录。tableImporter 从这里往下扫。

### targets

表 target 的定义，这是 `-t` 的取值来源。

| 字段 | 作用 |
|---|---|
| `name` | `-t` 用的名字，你自己起 |
| `manager` | 生成的管理类名，通常 `Tables` |
| `groups` | 绑定哪些 group，决定这个 target 导出哪些表和字段 |
| `topModule` | 生成代码的顶层命名空间 |

一份常见的分工：

| target | groups | 用途 |
|---|---|---|
| client | c | 客户端运行数据 |
| server | s | 服务端运行数据 |
| editor | c（`topModule` 用 `editor.cfg`） | 编辑器或工具数据 |
| test | t | 仅测试或内部数据 |
| all | c/s/e | 全量导出 |

`targets` 里的名字与 `-d` / `-c` 的取值是三套不同的东西，混淆它们是配置踩坑的主要来源 —— 见[目标与输出 ·「target」是三个不同的东西](targets-and-output.md#target是三个不同的东西)。

### xargs

运行参数，字符串数组，每项 `key=value`。下一节展开。

### contextMenu（Luban 不读）

右键脚本从同一份 `luban.conf` 里读它，格式与含义见[右键菜单](context-menu.md)。

写在这个字段里的东西不影响命令行导出。

---

## xargs 参数

每项是 `key=value`，键可以带命名空间前缀 `namespace.key=value`。查找时先试带前缀的完整键，找不到就砍掉前缀的最后一段再试，直到全局键。

⚠ **前缀只认 dataTarget 与 codeTarget，不认 `targets` 里的表 target 名。** 写 `client.outputDataDir=` 既不报错也不生效。这一条写透在[目标与输出 · xargs 的前缀只认 dataTarget 与 codeTarget](targets-and-output.md#xargs-的前缀只认-datatarget-与-codetarget)，EsyLuban 会对这类键打 `[dead xargs]` 警告。

### 输出

| 键 | 作用 |
|---|---|
| `outputDataDir` | 数据输出目录 |
| `outputCodeDir` | 代码输出目录 |
| `{dataTarget}.outputDataDir` | 按数据格式细分，如 `json.outputDataDir` |
| `{codeTarget}.outputCodeDir` | 按代码语言细分，如 `cs-simple-json.outputCodeDir` |
| `{dataTarget}.fileExt` | 数据文件后缀 |
| `outputCodeExtension` | 代码文件后缀 |

解析只有两层：带前缀的键 → 全局键。详见[目标与输出 · 输出目录的解析规则](targets-and-output.md#输出目录的解析规则)。

### 清理

| 键 | 作用 |
|---|---|
| `cleanUpOutputDir` | 导出前删掉输出目录里不属于本次产物的文件。**默认开启** |
| `outputSaver.{dataTarget}.cleanUpOutputDir` | 同上，按格式细分 |
| `forceCleanUpOutputDir` | 绕过 EsyLuban 的安全闸，强行清理 |

⚠ **带命名空间的键会压过命令行的全局键。** 命令行 `-x` 只在**键完全相同**时覆盖 conf 里的同名键；而查找是先试带前缀的。所以 conf 里写死 `outputSaver.json.cleanUpOutputDir=1`，会让命令行的 `-x cleanUpOutputDir=0` 失效 —— 右键局部导表会重新变成「删光其他所有表」。右键脚本为此同时传了两层的关闭键。

不写这两个键最省事：默认值就是开启，写出来只带来上面这个风险。清理的危险与安全闸见[目标与输出](targets-and-output.md#输出目录会被清空)。

### 校验与本地化

| 键 | 作用 |
|---|---|
| `pathValidator.rootDir` | `path` 校验器的路径基准。指向**工程根**，不是 `Assets` 本身 |
| `l10n.provider` | 本地化提供者，内置为 `default` |
| `l10n.textFile.path` | 文案表路径 |
| `l10n.textFile.keyFieldName` | key 列的列名 |
| `l10n.textFile.languageFieldName` | 取哪一列作为译文 |
| `l10n.convertTextKeyToValue` | 导出时把 key 静态替换成文案 |
| `l10n.textListFile` | 文案清单输出 |

细节在[本地化](localization.md)。

### 代码风格

| 键 | 作用 | 例 |
|---|---|---|
| `codeStyle` | 命名风格套装 | `csharp-default` / `java-default` |
| `namingConvention.{codeTarget}.{位置}` | 单独覆盖某一处的命名 | `namingConvention.cs-bin.field=pascal` |
| `{code\|data}.lineEnding` | 换行符 | |
| `{codeTarget\|dataTarget}.fileEncoding` | 文件编码 | |

一个项目定一套，别按 target 各配一份 —— 生成代码是要被人读的。

### 数据格式

| 键 | 作用 |
|---|---|
| `json.compact` | `1` = 不缩进不换行。产物体积小，但 diff 不可读 |

### 扫描

| 键 | 作用 |
|---|---|
| `tableImporter.scanPath` | 限制扫描范围，只导这个文件或目录下的表 |

写死在 `xargs` 里会永久缩小全局扫描范围，全量导出就再也不全了。它的正常用法是命令行临时传入。

### 扩展点

`outputSaver`、`dataExporter`、`codePostprocess`、`dataPostprocess`、`schemaCollector`、`tableImporter`、类型映射（`{类型}.type` / `{类型}.constructor`）—— 保持默认，更换属于二次开发。

EsyLuban 自身就是用这套扩展点实现的（`outputSaver` 与 `tableImporter` 被 `Priority` 覆盖），换掉它们会连带丢掉安全闸与自包含表支持。

---

## 表扫描规则

tableImporter 默认扫 `dataDir` 全目录，自动跳过：

- 文件名为 `__tables__` / `__beans__` / `__enums__` 的表
- **路径中任意一段**以 `.` / `_` / `~` 开头的文件或目录（`FileUtil.IsIgnoreFile`）

⚠ `Defines` 目录**不在**忽略之列。它躲过扫描只是因为里面通常只有 `.xml`。在 `Defines/` 下放一个带 `##export` 的 xlsx，它同样会被当成数据表导入。

右键菜单不走 `scanPath`：它先用 `--listTables <所选路径>` 拿到范围内的表全名，再用 `-o` 逐个限定输出，同时保持 schema 全量加载，这样跨表引用仍能解析。

---

## 命令行参数

右键菜单内部就是命令行调用，`gen.bat` 也是。

| 参数 | 长名 | 作用 |
|---|---|---|
| | `--conf` | 配置文件路径。**必填** |
| `-t` | `--target` | 表 target，取自 `targets`。**必填** |
| `-d` | `--dataTarget` | 数据格式 |
| `-c` | `--codeTarget` | 生成语言 |
| `-o` | `--outputTable` | 只输出指定的表（可多次） |
| `-x` | `--xargs` | 运行参数，`-x key=val`，可多次 |
| `-f` | `--forceLoadTableDatas` | 没有 dataTarget 时也加载数据。纯校验用 |
| `-i` / `-e` | `--includeTag` / `--excludeTag` | 按记录 tag 过滤 |
| | `--variant` | 字段变体，如 `--variant Item.name=en` |
| | `--timeZone` | datetime 的时区 |
| | `--validationFailAsError` | 有校验失败就以退出码 1 结束 |
| | `--customTemplateDir` | 自定义模板目录 |
| | `--listTables` | 列出指定路径下的表全名后退出，不编译不校验 |
| `-s` | `--schemaCollector` | schema 收集器 |
| `-p` | `--pipeline` | 流水线 |
| `-l` | `--logConfig` | nlog 配置，缺省 `nlog.xml` |
| `-w` | `--watchDir` | 监视目录，变更即重新生成 |
| `-v` | `--verbose` | 详细日志 |

`--listTables` 把表名写到 stdout（每行一个），日志走 stderr，方便调用方按行读。

### 命令行与 conf 的覆盖关系

conf 的 `xargs` 与命令行 `-x` 合并成同一张表，**同名键**由命令行胜出。注意「同名」是字面相同：`-x cleanUpOutputDir=0` 覆盖不了 conf 里的 `outputSaver.json.cleanUpOutputDir=1`，因为那是两个不同的键，而查找时前缀那个先被找到。

把参数收敛到 `luban.conf`，命令行只放每次调用真正不同的东西（`-t`、`-o`、按 target 分的输出目录）。多个入口脚本各维护一套参数，最后总会漂移。

---

## 出错时会发生什么

两类失败的行为完全不同，别混：

| 类型 | 例子 | 行为 |
|---|---|---|
| **解析 / 结构错误** | 主键重复、类型转不过去、schema 找不到 | 抛异常，**整次导出中止**，退出码 1，一个文件都不产出 |
| **校验器失败** | `ref` 指向不存在的记录、`path` 找不到文件、`regex` 不匹配 | 记 ERROR 日志，**导出照常完成**，退出码 **0** |

也就是说，**校验失败默认不会让 CI 变红**。要它变红，加 `--validationFailAsError` —— 有任何校验器失败就以退出码 1 结束。

无论哪种，日志都会写出具体是哪张表、哪一行、哪个字段、来自哪个文件。查具体报错对应什么原因，见[出错了怎么办](troubleshooting.md)。

---

## 两个格式上的坑

**JSON 注释与尾逗号**：Luban 自己接受（解析时开了 `ReadCommentHandling.Skip` 与 `AllowTrailingCommas`），但右键脚本用 Windows PowerShell 5.1 的 `ConvertFrom-Json` 读同一份文件，两样都不接受。同一份 conf，Luban 读得了、右键读不了。需要写说明就写在项目文档里，别写进 `luban.conf`。

**编码**：`luban.conf` 按 UTF-8 读取。
