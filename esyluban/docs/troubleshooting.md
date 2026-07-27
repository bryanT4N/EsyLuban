# 出错了怎么办

**给谁看**：所有人。策划和程序员看到的报错在这里都能查到。

**读完你能做什么**：把屏幕上那句话对上原因，知道下一步动哪里。

按**你看到的现象**查，不按出错的模块分类 —— 出错的时候你只知道屏幕上写了什么。

---

## 表没导出来

| 现象 | 原因与处置 |
|---|---|
| 整张表没产物，**也没报错** | A1 写错了。只有恰好是 `##export` 才导出，`##Export` 这类大小写变体也接受，但 `##exportt`、`#export` 不行。日志里会有一条 WARN 点出这张 sheet |
| 表没产物，A1 确实是 `##export` | B1 空着。B1 至少要有 `full_name="模块.表名"` |
| 表改了，产物没变 | 改的表不在右键选中的范围内；或 A1 被写成了 `##export=false` |
| `No exportable tables found under: ...` | 右键的范围里没有带 `##export` 的表 |
| 某个目录下的表全部被忽略 | 目录名以 `_`、`.` 或 `~` 开头。这是 Luban 的规则：这类路径段一律跳过。改名即可 |

## 报了具体的错

| 报错 | 原因与处置 |
|---|---|
| `invalid type. module:'x' type:'Y'` | B1 少了 `read_schema_from_file="true"`。结构写在本表 `##var`/`##type` 行里时必须加它 —— 它的默认值是 `false`，意思是「结构在别处（schema XML 或 `__beans__`）」，于是 Luban 去找一个并不存在的定义 |
| `主键值:'x' 重复` | 同一张表里两条记录的主键相同。这是**中止级**错误，整次导出都不会产出 |
| `是单值表 mode=one,但数据个数:N != 1` | 标了 `mode="one"` 的表填了不止一行 |
| `在引用表:'x' 中不存在` | `ref` 指向的记录不存在。检查拼写，以及被引用的表是否在同一次导出的范围内 |
| `找不到对应文件` | `path` 校验器没找到那个资源。路径相对 `pathValidator.rootDir`，检查拼写与大小写 |
| `不符合正则表达式` | 字段值不满足 `regex` 约束 |
| `值不在set` / `size:N,但要求为` / `是一个默认值` | 分别是 `set`、`size`、`not-default` 校验器。报错里会写出期望值 |
| `不是一个有效的文本key` | `text` 字段填的 key 在本地化表里不存在 |
| bool 字段报错 | 只接受 `true`/`false`/`0`/`1`。`Yes`、`是`、`√` 都不行 |
| 枚举字段报错 | 填了不存在的枚举名。注意枚举名区分大小写 |
| `ref 引用的表:'x' 没有导出` | 被引用的表不在当前 target 的 group 里。右键菜单常见这个 —— 见下面「右键菜单」一节 |
| `type:'x' group:'y' not found` | **表或类型**上的分组名不在 `luban.conf` 的 `groups` 里。注意报错里的分组名可能是你没写过的 —— 分隔符写错时（`group="c\|s"`，`\|` 不是分隔符）整串会被当成一个名字。分隔符只有 `,` 和 `;` |
| `target:x group:\`y\` not defined` | 上一条的另一头：`luban.conf` 里某个 **target 绑定**了一个没声明的分组。检查 `targets[].groups` 与 `groups[].names` 是否对得上 |
| `index:'a+b' 字段不存在` | `mode="map"` 的表只能有单个索引字段。联合索引 `a+b+c` 只在 `mode="list"` 下有效 |
| `属于type的属性，必须用#分割，尝试 '<类型>#ref=...'` | 把 `ref` / `index` / `path` / `range` / `sep` / `regex` 写到了 `&` 后面。`&` 后面只接受 `group=`、`comment=`、`tags=` |
| `group为保留属性,只能用于table或var定义` | 把 `group` 写进了类型串（`#group=`）。报错自带修复提示：在 Excel 里应当写 `&group=xxx`，**且不带引号** |
| `字段切割应该用'sep'，而不是'seq'` | 拼写错误，`sep` 不是 `seq` |
| `excel标题头不再使用'&'作为分割符` | 从旧版 Luban 迁过来的表。现在 `##` 行的标签用 `,` 分隔 |
| `behaviour:'x' type:ITableImporter not exists` | `tableImporter.name` 写了个不存在的名字。有意义的取值只有缺省的 `default` 和 `none` |

## 没报错，但结果不对

这一类最费时间 —— 导出显示成功，退出码是 0，问题要等到程序或游戏里才暴露。
下面几条都是实测确认过的行为，不是猜测。

### 校验失败了，但导出照样成功

**这是最该先知道的一条。** `ref` 找不到、`path` 文件不存在、`regex` 不匹配 ——
这些都只记 ERROR 日志，**退出码仍然是 0**：

```
gen.bat -t all -f                          exit=0   ← 日志里有 11 条 ERROR
gen.bat -t all -f --validationFailAsError  exit=1
```

所以：**CI 或提交钩子里必须加 `--validationFailAsError`**，否则校验等于白跑。
平时手动导表时，也要看日志里有没有 `|ERROR|`，别只看有没有弹错。

### 某个字段在产物里不见了

**字段的分组名写错完全不报错**（表上、bean / enum 上写错则会中止并报
`group:xxx not found`）。退出码 0，日志零提及，这个字段从每个 target 消失。

最常见的具体写法是给类型格里的 `&group=` 加了引号 —— `int&group="c"` 得到的
组名是带引号的 `"c"`，匹配不上任何 target。规矩与 B1 相反，
见[表格式参考](table-format.md)。

排查手法：拿同一张表分别导 `-t client` 和 `-t all`，比较字段列表。
`-t all` 里也没有的字段，就是分组名写错了。

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
