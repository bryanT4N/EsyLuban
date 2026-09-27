# 它是怎么工作的

**给谁看**：想改 EsyLuban，或者需要判断某个行为是上游的还是 EsyLuban 的人。

**读完你能做什么**：知道一次导表经过哪些阶段、EsyLuban 在哪几个点介入、出问题
该往哪个阶段找。

**不该在这里找**：怎么配置在 [配置参考](configuration.md)，怎么用在
[接入你的项目](setup.md)。

---

## 一次导表的完整链路

```
luban.conf + 命令行参数
        │
        ▼
   SchemaCollector ──────► 有哪些表、每张表的结构是什么
        │
        ▼
    RawAssembly  ────────► 未编译的原始定义
        │
        ▼
    DefAssembly  ────────► 编译后的类型系统（此时类型错误会暴露）
        │
        ├──────────────────────────┐
        ▼                          ▼
    DataLoader                 CodeTarget
    读 Excel/JSON/CSV          生成 C# / Java / ...
        │                          │
        ▼                          │
   DataValidator                   │
   9 个校验器                       │
        │                          │
        ▼                          │
    DataTarget                     │
    序列化成 json / bin / xml       │
        │                          │
        └──────────┬───────────────┘
                   ▼
              OutputSaver
              清理输出目录 + 落盘
```

用了变体时，这条链路默认版和每个变体各跑一遍：DataLoader 读完每张表，叠加上这个变体在
`variant_` 文件夹里的差异；CodeTarget 只在第一遍跑；OutputSaver 把变体的数据写进以变体命名的
子目录。见下面[变体比普通导出多做了什么](#变体比普通导出多做了什么)。

按阶段定位问题：

| 现象 | 出在哪一阶段 |
|---|---|
| 表根本没被发现 | SchemaCollector / TableImporter |
| `invalid type` | DefAssembly（结构没找到） |
| 某个单元格的值报错 | DataLoader |
| 变体的数据不对 | DataLoader 叠加变体差异的那一步（`VariantFolders`） |
| `error.validator.regex.mismatch` / `error.validator.set.not_in_set` / `error.validator.path.not_found` 这类校验报错 | DataValidator |
| 产物形状不对 | DataTarget |
| 输出目录里别的文件不见了 | OutputSaver |

## EsyLuban 在哪里介入

上游 Luban 用 `Priority` 属性做扩展点：同名实现里 Priority 高的胜出。EsyLuban
的核心能力都是靠新增文件自注册实现的，**没有改动上游的对应代码**：

| 扩展点 | 新增的实现 | 做什么 |
|---|---|---|
| `[TableImporter("default", Priority = 100)]` | `SelfContainedTableImporter` | 扫描 Excel，认出 A1 的 `##export` 与 B1 的元数据，从而不再需要 `__tables__.xlsx` |
| `[SchemaCollector("default", Priority = 100)]` | `SelfContainedSchemaCollector` | 把数据表文件里的 `__beans__` / `__enums__` sheet 当作内联结构定义加载 |
| `[OutputSaver("local", Priority = 100)]` | `SafeLocalFileSaver` | 在清空输出目录前判断这次清理是否可疑，可疑就拒绝并说明理由；把变体的数据放进以变体命名的子目录 |

这些都是**替换**内置实现，而不是修改它。跟进上游时它们不参与合并冲突。

**替换是彻底的，不是并存。** 以 TableImporter 为例：上游那套「文件名以 `#` 开头
就自动导表」的 `DefaultTableImporter` 源码原封不动，但它注册的名字同样是
`default`，被更高 Priority 压过之后**没有第二个名字能选回它** ——
`tableImporter.name` 只有两个取值有意义：缺省的 `default`（拿到 EsyLuban 的），
以及 `none`（不导入任何表）；写别的名字会明确报
`error.behaviour.not_exists`。

这是有意的取舍。自包含定义覆盖了 `#xxx` 的全部场景，还多支持三样它不支持的：
多数据源合表、按 sheet 分别导出、`one` / `list` 模式。两套发现方式并存，只会让
「这张表为什么被导出」多一个需要排查的分支。

## 不得不改动的上游文件

有四处绕不开扩展点，改动面登记在 [`upstream_boundary.txt`](../upstream_boundary.txt)，
并由回归逐条比对：

| 文件 | 为什么绕不开 |
|---|---|
| `Excel/SheetLoadUtil.cs` | Excel 读取是纯静态方法，没有扩展点。要认出 A1 的 `##export` 标记，并把它造成的行偏移一路带到合并单元格与报错坐标，只能改这里 |
| `Luban/Program.cs` | 命令行选项和整次运行的流程都没有注册机制。`--listTables`、「无效 xargs 键」告警，以及按 `esyluban.variants` 在默认版之后每个变体各跑一遍导出，都加在这 |
| `CustomBehaviourManager.cs` | 加了一个 `HasBehaviour<C>()` 纯查询方法，供上面那条告警判断某个名字是不是已注册的 dataTarget/codeTarget |
| `DataLoader/DataLoaderManager.cs` | 数据加载是一段固定流程，没有扩展点。变体要把 `variant_` 文件夹里的差异行交给上游现成的按主键合并，只能在读完每张表的那一行改（见下面「变体」一节） |

其中 `SheetLoadUtil.cs` 是风险最高的一处：它给一段既有的行游标逻辑整体引入了一
维偏移量，改动点散布在整个文件且必须彼此一致。这条链路现在有四套基线覆盖。

## 右键导表比全量导表多做了什么

右键要「只导选中的那些表」，但**不能只加载选中范围的 schema** —— 范围外的跨表
引用会悬空，导出直接中止。所以它分两步：

1. `--listTables <所选路径>` —— 只收集表名，输出该范围内的表全名，每行一个；选中的只是
   `variant_<名字>` 里的表时写成 `表名@变体`。不编译、不校验、不生成，也不选上游的表变体，
   因此范围外的引用、同名表范围外的其它几份定义都不会造成中止。
2. 正常导出，但用 `-o <表名>` 逐个限定输出，`-o 表名@变体` 只导那个变体。schema 仍是
   全量加载的。

这也是为什么右键**不修改** `tableImporter.scanPath`：那会真的缩小加载范围。

注册表里指向的是转发器 `menu_entry_*.bat`，里面只有目录约定、没有逻辑，真正的
实现留在项目内 —— 换新版发布包替换 `Tools/Luban/` 即完成升级，不必重装右键菜单。
详见 [右键菜单](context-menu.md)。

## 变体比普通导出多做了什么

变体是同一份数据的几个版本，最常见的是按语言分：对话配音、带文字的图片、每种语言一张的
文本表。国服、海外服这类分支版本不是变体：它们靠版本控制把主干的改动合并过去，各分支
分别导出，导表工具不参与。

**变体在 `luban.conf` 里声明**（`esyluban.variants=en`，EsyLuban 加的键，上游没有），
`variant_` 后面的名字必须是声明过的。默认版导出到输出目录本身，每个变体导出完整的一份，
放在它下面以变体命名的子目录。没写 `esyluban.variants` 的项目里，`variant_` 就是普通
文件夹，所以不用变体的项目升级前后完全一样。

**`variant_<名字>` 里只放差异。** 默认版天天在改，各版本应该自动跟上，而不是每改一次
就手工同步一份拷贝。所以变体里的表按主键叠加在默认版上：

- 主键相同的行整行替换默认版的那一行，主键是新的就追加。
- 整张复制过来也能用，效果就是整张替换，代价是以后要自己同步。
- 单例表和 list 表没有主键可比，有变体就整张替换。
- 同一个变体里同一个主键出现两次，报错。

同名的几份定义、导出时各取一份，这个思路和上游 Luban 5.1 的表变体一样：变体里的表和
默认版是同一个 `full_name`，产物文件名、生成的类都相同，游戏代码不用区分版本。不同的
是合并方式和选法。5.1 的表变体要求每一份都是完整的表，写在 XML 或 `__tables__.xlsx` 里，
导出时用 `--variant` 选一份；这里按主键叠加，一次导出出全部版本，变体由文件夹决定。
合并这一步用的是老 Luban 1.x「main + patch」留下来的代码，5.x 里还保留着。整张复制进
`variant_` 文件夹，就是 5.1 表变体的整张替换。

**上游的表变体和字段变体都不推荐用。** 它们没有被删掉，用 XML 声明的表照样能用，但同一份
数据的几个版本 EsyLuban 只推荐 `variant_` 文件夹。两套一起用时，`--variant` 在默认版和
每个变体里选的都是同一份，某个版本到底用了哪份数据，要同时看两处才知道。

**表怎么对上。** `variant_<名字>` 可以在数据目录的任何一层，里面的表按 `full_name`
对上默认版，和放在哪一层无关。

- 对不上就报错。只有某个版本才有的表，要在默认版里建一张只有表头的空表，这样各版本
  生成的代码完全一样。
- 变体那份的 B1 照抄默认版；`output`、`mode`、`index` 写得不一样会报错。
- B1 里不写 `variant`，版本由文件夹决定。

**导什么。** 两条规则：选中了什么、文件夹下面有什么，就导什么；影响到什么，就导什么。

- 默认版的表影响默认版和每个变体；`variant_<名字>` 里的表只影响那个变体。
- 全量导出就是选中了整个数据目录。

默认版和每个变体各跑一遍完整的导出，所以变体越多越慢；代码只在第一遍生成。默认版的
清理会跳过各变体的子目录，不会把它们当成废弃文件删掉。`check.bat` 每个版本都校验，
任何一个失败都算失败。

## 想验证这些说法

```bat
esyluban\scripts\test\run_full_tests_example.bat
```

回归会报出它跑了多少项检查。里面既有产物的 SHA256 基线，也有守卫 —— 包括上面
那张「不得不改的上游文件」表是否仍然属实。想知道每一项在检查什么，见
[参与开发](contributing.md)。
