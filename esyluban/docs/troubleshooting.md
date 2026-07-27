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
