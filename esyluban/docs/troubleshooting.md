# 出错了怎么办

**给谁看**：所有人。策划和程序员看到的报错在这里都能查到。

**读完你能做什么**：把屏幕上那句话对上原因，知道下一步动哪里。

按**你看到的现象**查，不按出错的模块分类 —— 出错的时候你只知道屏幕上写了什么。

---

## 表没导出来

| 现象 | 原因与处置 |
|---|---|
| 整张表没产物，**也没报错** | A1 写错了。只有恰好是 `##export` 才导出，`##Export` 这类大小写变体也接受，但 `##exportt`、`#export` 不行。日志里会有一条 `[bad A1]` 告警点出这张 sheet |
| 表没产物，A1 确实是 `##export` | B1 空着，日志里会有一条 `[empty B1]` 告警。B1 至少要有 `full_name="模块.表名"` |
| 表改了，产物没变 | 改的表不在右键选中的范围内；或 A1 被写成了 `##export=false` |
| `No exportable tables found under: ...` | 右键的范围里没有带 `##export` 的表 |
| 某个目录下的表全部被忽略 | 目录名以 `_`、`.` 或 `~` 开头。这是 Luban 的规则：这类路径段一律跳过。改名即可 |
| 改了 `variant_en` 里的表，输出目录里的产物没变 | `variant_<语言>` 里的差异只进那种语言的产物，在输出目录下以语言命名的子目录里，比如 `Data/en/` |

## 报了具体的错

报错语言跟随 Windows 界面语言，所以每条都列了中文和英文原文，照屏幕上的字搜哪种都能找到。
错误码是不随语言变的写法，其它文档提到报错时写的就是它。中止级的报错加 `--errorFormat json`
运行，能在输出里看到错误码；校验器的报错只输出文字。

| 报错原文（中文 / English） | 错误码 | 原因与处置 |
|---|---|---|
| `invalid type. module:'x' type:'Y'` | 无 | B1 少了 `read_schema_from_file="true"`。结构写在本表 `##var`/`##type` 行里时必须加它 —— 它的默认值是 `false`，意思是「结构在别处（schema XML 或 `__beans__`）」，于是 Luban 去找一个并不存在的定义 |
| `主键值:'x' 重复`<br>`primary key field:'x' value:'y' is duplicated` | `error.data.duplicate_key` | 同一张表里两条记录的主键相同。这是**中止级**错误，整次导出都不会产出 |
| `是单值表 mode=one，但数据个数:N != 1`<br>`is a singleton table mode=one, but record count:N != 1` | `error.data.singleton_count` | 标了 `mode="one"` 的表填了不止一行 |
| `在引用表:x 中不存在`<br>`does not exist in ref table:x` | `error.validator.ref.not_found` | `ref` 指向的记录不存在。检查拼写，以及被引用的表是否在同一次导出的范围内 |
| `找不到对应文件`<br>`corresponding file not found` | `error.validator.path.not_found` | `path` 校验器没找到那个资源。路径相对 `pathValidator.rootDir`，检查拼写与大小写 |
| `不符合正则表达式`<br>`does not match regex` | `error.validator.regex.mismatch` | 字段值不满足 `regex` 约束 |
| `值不在 set`<br>`value is not in set` | `error.validator.set.not_in_set` | `set` 校验器。报错里会写出允许的取值 |
| `size:N，但要求为`<br>`size:N, but required` | `error.validator.size.mismatch` | `size` 校验器。报错里会写出要求的个数 |
| `是一个默认值`<br>`is a default value` | `error.validator.not_default` | `not-default` 校验器，这个字段不许留默认值 |
| `不是一个有效的文本 key`<br>`is not a valid text key` | `error.validator.text.invalid_key` | `text` 字段填的 key 在本地化表里不存在 |
| `找不到文本 id:x 对应的目标语言文本`<br>`can't find target language text of text id:x` | `error.l10n.missing_text` | 同样是 key 不存在，但出在 `convertTextKeyToValue=1` 时。这条**不算校验失败**，写错的 key 会原样进产物，`check.bat` 也拦不住。见下面「产物里是 key，不是文案」 |
| bool 字段报错 |  | 只接受 `true`/`false`/`0`/`1`。`Yes`、`是`、`√` 都不行 |
| 枚举字段报错 |  | 填了不存在的枚举名。注意枚举名区分大小写 |
| `ref 引用的表:'x' 没有导出`<br>`ref table:'x' is not exported` | `error.validator.ref.not_exported` | 被引用的表不在当前 target 的 group 里。右键菜单常见这个 —— 见下面「右键菜单」一节 |
| `类型:x group:y 未找到`<br>`type:x group:y not found` | `error.def.type.group_not_found` | **表或类型**上的分组名不在 `luban.conf` 的 `groups` 里。注意报错里的分组名可能是你没写过的 —— 分隔符写错时（`group="c\|s"`，`\|` 不是分隔符）整串会被当成一个名字。分隔符只有 `,` 和 `;` |
| `target:x group:\`y\` 未定义`<br>`target:x group:\`y\` not defined` | `error.def.target.group_not_defined` | 上一条的另一头：`luban.conf` 里某个 **target 绑定**了一个没声明的分组。检查 `targets[].groups` 与 `groups[].names` 是否对得上 |
| `index:'a+b' 字段不存在`<br>`index:'a+b' field does not exist` | `error.def.table.index_not_exist` | `mode="map"` 的表只能有单个索引字段。联合索引 `a+b+c` 只在 `mode="list"` 下有效 |
| `属于 type 的属性，必须用 # 分割，尝试 '<类型>#ref=...'`<br>`belongs to type attributes and must be split with #, try '<type>#ref=...'` | `error.schema.title_type_attr` | 把 `ref` / `index` / `path` / `range` / `sep` / `regex` 写到了 `&` 后面。`&` 后面只接受 `group=`、`comment=`、`tags=` |
| `group 为保留属性，只能用于 table 或 var 定义`<br>`group is a reserved attribute and can only be used on table or var definitions` | `error.schema.group_reserved` | 把 `group` 写进了类型串（`#group=`）。报错自带修复提示：在 Excel 里应当写 `&group=xxx`，**且不带引号** |
| `字段切割应该用 'sep'，而不是 'seq'`<br>`field splitting should use 'sep', not 'seq'` | `error.schema.seq_typo` | 拼写错误，`sep` 不是 `seq` |
| `excel 标题头不再使用 '&' 作为分隔符`<br>`excel title no longer uses '&' as separator` | `error.excel.ampersand_separator` | 从旧版 Luban 迁过来的表。现在 `##` 行的标签用 `,` 分隔 |
| `behaviour:x 类型:ITableImporter 不存在`<br>`behaviour:x type:ITableImporter not exists` | `error.behaviour.not_exists` | `tableImporter.name` 写了个不存在的名字。有意义的取值只有缺省的 `default` 和 `none` |
| `B1 缺少 full_name`<br>`B1 is missing full_name` | `esyluban.b1.missing_full_name` | B1 至少要写 `full_name="模块.表名"`，其余各项都能省 |
| `B1 的 mode 写成了 'x'`<br>`B1 mode is 'x'` | `esyluban.b1.bad_mode` | `mode` 只能是 `map`、`list`、`one` |
| `B1 的 x 写成了 'y'`<br>`B1 x is 'y'` | `esyluban.b1.bad_bool` | `read_schema_from_file` 只接受 `true`、`false`、`1`、`0` |
| `B1 里的双引号没有配对`<br>`B1 has an unmatched double quote` | `esyluban.b1.unmatched_quote` | 多半是输入法打出了中文引号“”。B1 里的引号一律用英文的 `"` |
| `B1 里的 'x' 缺少 =`<br>`B1 item 'x' has no '='` | `esyluban.b1.missing_equals` | 每一项都写成 `key="value"`，项与项之间用 ` & ` 隔开，`&` 两边各一个空格 |
| `表 x 被定义了 N 次`<br>`Table x is defined N times` | `esyluban.b1.duplicate_full_name` | 两张 sheet 的 B1 写了同一个 `full_name`。多半是复制 sheet 后忘了改 `full_name`；想做成某种语言的版本，放进 `variant_<语言>` 文件夹，见[写一张表](writing-tables.md#某种语言的版本要不一样的数据)。已经放进 `variant_` 文件夹还报这条，是 `luban.conf` 里没写 `l10n.languages`：没声明语言时 `variant_` 只是普通文件夹。报错会列出每一处的 sheet 和文件 |
| `存在多个无 variant 的 fallback 定义`<br>`has multiple fallback definitions without variant` | `error.def.table.variant_fallback_duplicate` | 同一张表定义了两次，一份在 B1、一份在 XML 或 `__tables__.xlsx`（两份都在 B1 报的是上面那条）。常见于表迁到 B1 之后忘了从 `__tables__.xlsx` 删掉 |
| `B1 不写 variant`<br>`B1 does not take variant` | `esyluban.b1.variant_key` | B1 里写了 `variant` 或 `variants`。某种语言的版本放进 `variant_<语言>` 文件夹，B1 照抄默认版 |
| `表 x 在默认版和 variant_<语言> 里的 y 写得不一样`<br>`Table x: y differs between the default version and variant_<language>` | `esyluban.b1.variant_mismatch` | 两份的 `output`、`mode`、`index` 要写成一样的，没写也算一种写法（报错里写作 `''`）。报错会列出两份的值 |
| `variant_<语言> 里的表 x 在默认版里找不到`<br>`Table x in variant_<language> has no default version` | `esyluban.variant.no_default` | 某种语言独有的表，要在默认版里建一张只有表头的空表；表名写错了也是这条 |
| `文件夹 variant_<语言> 的语言 x 没有在 luban.conf 的 l10n.languages 里声明`<br>`Folder variant_<language>: language x is not declared in l10n.languages` | `esyluban.variant.undeclared_language` | 文件夹名打错了，或者新语言还没让程序员加进 `l10n.languages`。语言名要和声明的完全一样，区分大小写 |
| `x 是默认语言（l10n.languages 的第一种），不需要 variant_<语言> 文件夹`<br>`x is the default language (the first in l10n.languages) and needs no variant_<language> folder` | `esyluban.variant.default_language` | 默认语言的数据直接写在默认版里。`variant_` 文件夹里的东西默认语言不会读，放了也没效果 |
| `x 在两层 variant_ 文件夹里`<br>`x is inside two variant_ folders` | `esyluban.variant.nested` | 一个 `variant_` 文件夹放进了另一个里面。每种语言的文件夹都和默认版放在同一层 |
| `被 patch 多次覆盖`<br>`is overridden by patch multiple times` | `error.data.patch_override_multiple` | 同一种语言的 `variant_` 里，同一个主键写了两次。报错里的 patch 指的就是 `variant_` 里的差异 |
| `l10n.languages 里 x 写了两次`<br>`l10n.languages lists x twice` | `esyluban.l10n.duplicate_language` | `luban.conf` 的 `l10n.languages` 里有重复的语言 |
| `-o x 里的语言 y 没有在 luban.conf 的 l10n.languages 里声明`<br>`-o x: language y is not declared in l10n.languages` | `esyluban.output.undeclared_language` | 命令行 `-o 表名@语言` 的语言不在 `l10n.languages` 里 |
| `variantKey:'x' 已存在，但 variantName 'y' 不在`<br>`variantKey:'x' exists, but variantName 'y' is not in` | `error.def.field.variant_not_in_list` | 字段变体（数据表里 `name@en` 这样的列）里没有 `--variant` 选中的名字，它没有默认版可退，见[表格式](table-format.md) |
| `导入表失败`<br>`Failed to import tables` | `esyluban.import.failed` | 有个 Excel 文件读不出来。报错下面的 `file:` 是哪个文件，再下一条是原因，常见的是文件损坏、设了打开密码，或者根本不是 Excel、只是扩展名叫 `.xlsx` |
| `tableImporter.scanPath 指向的路径不存在`<br>`tableImporter.scanPath points to a path that does not exist` | `esyluban.import.scan_path_not_found` | `-x tableImporter.scanPath=` 给的路径不对。相对路径按运行 Luban 时的当前目录算 |

## 没报错，但结果不对

这一类最费时间 —— 导出显示成功，退出码是 0，问题要等到程序或游戏里才暴露。
下面几条都是实测确认过的行为，不是猜测。

### 校验失败了，但导出照样成功

**这是最该先知道的一条。** `ref` 找不到、`path` 文件不存在、`regex` 不匹配 ——
这些都只记 ERROR 日志，**退出码仍然是 0**：

```
gen.bat -t all -f                          exit=0   ← 日志里有 11 条 ERROR
gen.bat -t all -f --strict                 exit=1
```

所以：**CI 或提交钩子里必须加 `--strict`**（`check.bat` 已经带上了），否则校验等于白跑。
平时手动导表时，也要看日志里有没有 `|ERROR|`，别只看有没有弹错。

### 某个字段在产物里不见了

**字段的分组名写错完全不报错**（表上、bean / enum 上写错则会中止并报
`error.def.type.group_not_found`）。退出码 0，日志零提及，这个字段从每个 target 消失。

最常见的具体写法是给类型格里的 `&group=` 加了引号 —— `int&group="c"` 得到的
组名是带引号的 `"c"`，匹配不上任何 target。规矩与 B1 相反，
见[表格式参考](table-format.md)。

排查手法：拿同一张表分别导 `-t client` 和 `-t all`，比较字段列表。
`-t all` 里也没有的字段，就是分组名写错了。

### 产物里是 key，不是文案

`text` 字段的 key 在文本表里不存在，而导出用的是 `convertTextKeyToValue=1`（分语言出包的
常用做法）。这时只记一条 `error.l10n.missing_text`，**不算校验失败**，`--strict` 和 `check.bat`
都拦不住，写错的 key 原样进了产物。提交前用 `check.bat -t client -x l10n.convertTextKeyToValue=0`
再查一遍，缺的 key 会以 `error.validator.text.invalid_key` 报出来，退出码变成 1。
见[本地化](localization.md)。

### 生成的代码里类型不是我映射的那个

`<mapper>` 的 `target` 与 `codeTarget` 是**与**的关系，任一对不上就当没写，
不报错，安静用回 Luban 自己生成的类型。检查这次导出的 `-t` 和 `-c` 是否都在
mapper 的属性里，见[常见需求怎么配](recipes.md)。

### `-x` 设的参数像是没生效

`-x` 的前缀只认 dataTarget / codeTarget 的名字，**不认 `-t` 那个 target**。
`-x client.outputDataDir=...` 永远不生效。

在日志里搜 `[dead xargs]` —— EsyLuban 会为这种写法给出告警（上游是完全沉默的）。
正确写法见[目标与输出](targets-and-output.md)。

### json 数据源读出来的字段类型全不对

`input` 漏写了 `*`。一个装着 N 行的数组被当成一行去解析，于是第一个字段拿到了
整个对象、第二个字段拿到了下一个对象……报错指向字段类型不匹配，不会提示你少写
了个星号。见[数据从哪来](data-sources.md)。

---

## 右键菜单

| 现象 | 原因与处置 |
|---|---|
| 右键菜单根本不出现 | 安装脚本没用**管理员身份**运行 |
| `Luban runtime not found` | `runtime/` 没和 `luban.conf` 放在一起。发布包解压后两者应当都在 `Tools/Luban/` 下 |
| `Tools\Luban not found within 5 levels` | 右键的位置离 `Tools/Luban/` 超过 5 层目录，或没按推荐布局摆 |
| `Export script not found` | `Tools\Luban\contextmenu\` 被删了。它必须留在项目里 —— 注册表指向的只是转发器，真正的脚本在这 |
| 某个 target 报「ref 引用的表没有导出」 | `contextMenu.targets` 里列了一个 group 不含所选表的 target。只列真正含有这些表的 target；「只给测试用」的 target 不该进右键菜单 |
| 右键能跑，但配置像没生效 | `luban.conf` 里写了 JSON 注释或尾逗号。Luban 自己能接受，但右键脚本用 PowerShell 读它，两样都不接受 |
| 装了两套项目，右键菜单互相打架 | 安装时用 `--suite <名字>` 区分 |

## 输出目录

| 现象 | 原因与处置 |
|---|---|
| 导出报文件被占用 | Excel 还开着那张表，关掉再导 |
| 导出后目录里**别的文件不见了** | `outputDataDir` 指向了一个混放其它资源的目录。Luban 在写入前会清理输出目录 —— 给它一个专用目录 |
| 日志说 `[skip cleanup]` | EsyLuban 拦下了一次可疑的清理。看它给的理由：要么这次一个文件都没产出（通常是 group 把表全过滤掉了），要么要删的比要写的还多（通常是多个 target 共用了同一个目录） |
| 多个 target 的产物互相覆盖 | 它们共用了同一个 `outputDataDir`。注意 `xargs` 里写 `client.outputDataDir=` 是**无效**的，那个前缀只认 dataTarget/codeTarget；要按 target 分目录得每次调用传 `-x` |

## 环境

| 现象 | 原因与处置 |
|---|---|
| 提示缺少 .NET / 无法启动 | 用的是小包但机器上没有 .NET 8。装运行时，或换 standalone 版（解压即用） |
| 从源码构建后跑不起来 | 先跑 `esyluban\scripts\build.bat` |
| `The current directory is invalid` | 路径太深。Windows 大多数路径上限是 260 字符，工程嵌套深一点就会越界 —— 这句报错完全不指向真因。把项目挪到浅一点的位置。`gen.bat` 在路径超过 200 字符时会提前警告 |
| 报错全是英文 | 报错语言跟随 Windows 界面语言。想看中文就加 `--locale zh`，比如 `gen.bat -t client -d json --locale zh`；右键菜单在 `luban.conf` 的 `contextMenu` 里把 `extraArgs` 设成 `["--locale", "zh"]`。不改也行，上面的速查表中英文原文都有 |

---

## 还是没解决

导出日志比这张表详细得多，它会写出**具体是哪张表、哪个单元格**：

```
esyluban\examples\dev\TestOutputs\main_export.log     （回归的日志）
```

自己的项目里，`gen.bat` 的输出就是日志。找 `|ERROR|` 那几行，它们通常长这样：

```
ERROR|记录 "item.TbItem[3].price":"abc" (来自文件:"Sheet1@.../items.xlsx") ...
                    表名  行号  字段名   实际值        哪个文件的哪张 sheet
```

这一行足以定位到 Excel 里的具体格子。
