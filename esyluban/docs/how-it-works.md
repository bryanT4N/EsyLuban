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
   L10N Processor                  │
   文本 key 替换                    │
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

按阶段定位问题：

| 现象 | 出在哪一阶段 |
|---|---|
| 表根本没被发现 | SchemaCollector / TableImporter |
| `invalid type` | DefAssembly（结构没找到） |
| 某个单元格的值报错 | DataLoader |
| `不符合正则` / `不在set` / `找不到对应文件` | DataValidator |
| 产物里是 key 不是文案 | L10N Processor（`convertTextKeyToValue`） |
| 产物形状不对 | DataTarget |
| 输出目录里别的文件不见了 | OutputSaver |

## EsyLuban 在哪里介入

上游 Luban 用 `Priority` 属性做扩展点：同名实现里 Priority 高的胜出。EsyLuban
的三个核心能力都是靠新增文件自注册实现的，**没有改动上游的对应代码**：

| 扩展点 | 新增的实现 | 做什么 |
|---|---|---|
| `[TableImporter("default", Priority = 100)]` | `SelfContainedTableImporter` | 扫描 Excel，认出 A1 的 `##export` 与 B1 的元数据，从而不再需要 `__tables__.xlsx` |
| `[SchemaCollector("default", Priority = 100)]` | `SelfContainedSchemaCollector` | 把数据表文件里的 `__beans__` / `__enums__` sheet 当作内联结构定义加载 |
| `[OutputSaver("local", Priority = 100)]` | `SafeLocalFileSaver` | 在清空输出目录前判断这次清理是否可疑，可疑就拒绝并说明理由 |

这三个都是**替换**内置实现，而不是修改它。跟进上游时它们不参与合并冲突。

**替换是彻底的，不是并存。** 以 TableImporter 为例：上游那套「文件名以 `#` 开头
就自动导表」的 `DefaultTableImporter` 源码原封不动，但它注册的名字同样是
`default`，被更高 Priority 压过之后**没有第二个名字能选回它** ——
`tableImporter.name` 只有两个取值有意义：缺省的 `default`（拿到 EsyLuban 的），
以及 `none`（不导入任何表）；写别的名字会明确报
`behaviour:xxx type:ITableImporter not exists`。

这是有意的取舍。自包含定义覆盖了 `#xxx` 的全部场景，还多支持三样它不支持的：
多数据源合表、按 sheet 分别导出、`one` / `list` 模式。两套发现方式并存，只会让
「这张表为什么被导出」多一个需要排查的分支。

## 不得不改动的上游文件

有三处绕不开扩展点，改动面登记在 [`upstream_boundary.txt`](../upstream_boundary.txt)，
并由回归逐条比对：

| 文件 | 为什么绕不开 |
|---|---|
| `Excel/SheetLoadUtil.cs` | Excel 读取是纯静态方法，没有扩展点。要认出 A1 的 `##export` 标记，并把它造成的行偏移一路带到合并单元格与报错坐标，只能改这里 |
| `Luban/Program.cs` | 命令行选项没有注册机制。`--listTables` 与「无效 xargs 键」告警都加在这 |
| `CustomBehaviourManager.cs` | 加了一个 `HasBehaviour<C>()` 纯查询方法，供上面那条告警判断某个名字是不是已注册的 dataTarget/codeTarget |

其中 `SheetLoadUtil.cs` 是风险最高的一处：它给一段既有的行游标逻辑整体引入了一
维偏移量，改动点散布在整个文件且必须彼此一致。这条链路现在有四套基线覆盖。

## 右键导表比全量导表多做了什么

右键要「只导选中的那些表」，但**不能只加载选中范围的 schema** —— 范围外的跨表
引用会悬空，导出直接中止。所以它分两步：

1. `--listTables <所选路径>` —— 只做 schema 收集，输出该范围内的表全名，每行一个。
   不编译、不校验、不生成，因此范围外的引用不会造成中止。
2. 正常导出，但用 `-o <表名>` 逐个限定输出。schema 仍是全量加载的。

这也是为什么右键**不修改** `tableImporter.scanPath`：那会真的缩小加载范围。

注册表里指向的是转发器 `menu_entry_*.bat`，里面只有目录约定、没有逻辑，真正的
实现留在项目内 —— 换新版发布包替换 `Tools/Luban/` 即完成升级，不必重装右键菜单。
详见 [右键菜单](context-menu.md)。

## 想验证这些说法

```bat
esyluban\scripts\test\run_full_tests_example.bat
```

回归会报出它跑了多少项检查。里面既有产物的 SHA256 基线，也有守卫 —— 包括上面
那张「不得不改的上游文件」表是否仍然属实。想知道每一项在检查什么，见
[参与开发](contributing.md)。
