# EsyLuban

在上游 [Luban](https://github.com/focus-creative-games/luban) 之上增加**自包含表定义**：
每张 Excel 用 `A1=##export` 与 `B1` 元数据自我描述，不再需要集中式的 `__tables__.xlsx`；
配套 Windows 右键菜单，让策划右键自己那张表就能导出。

---

## 你是来用它的

**不需要 clone 本仓库，也不需要构建任何东西。**
去 Releases 页面下载，解压后读里面的 `README.md`——那份文档专门讲从下载到接入
游戏项目的完整过程。

两个版本功能完全一致，按机器上有没有 .NET 8 选：

| 包 | 体积 | 前置条件 | 每项目占用 |
|---|---|---|---|
| `EsyLuban-<版本>-win-x64-standalone.zip` | 约 34 MB | 无，解压即用 | 约 76 MB |
| `EsyLuban-<版本>-win-x64.zip` | 约 2 MB | 需要 .NET 8 运行时 | 约 6 MB |

发布包解压出来的结构**就是推荐的项目布局本身**，把 `Tools/` 和 `DataTables/`
两个目录拷进你的开发目录即可：

```
你的开发目录/
├─ Docs/
├─ DataTables/          Excel 都放这，策划的地盘
├─ Tools/Luban/         runtime/ + luban.conf + gen.bat + contextmenu/
└─ Source/你的游戏/     只接收导出产物，不放源表
```

包里另附完全手册 `docs/esyluban_beginner_guide.md`（A 章给策划，B 章给程序员）。

---

## 你是来改它的

本目录收纳 EsyLuban 的**全部自有资产**。仓库根目录保持为**上游 Luban 原物**
（`src/`、`docs/`、`scripts/`、`LICENSE`、`README.md` 等）。

### 上游边界

这条分界线是本 fork 的核心约束：**对上游只新增文件，尽量不修改**。验证方式：

```bash
git diff --name-status origin/main -- src
```

目前 `src/` 下有两处修改（M），其余全是新增（A）：

| 被修改的上游文件 | 改动内容与不得不改的理由 |
|---|---|
| `Luban.DataLoader.Builtin/Excel/SheetLoadUtil.cs` | 让 A1 的 `##export` 声明不被当成 meta 行本身——真正的 meta 行（`##var` 等）在它下一行。这是自包含格式的前提，无法从外部扩展点绕开。 |
| `Luban/Program.cs` | 新增 `--listTables`，输出指定路径下的表全名清单。右键菜单靠它确定"选中范围内有哪些表"，进而只导出这些表。命令行选项无扩展点可注册。 |

其余功能全部由**新增文件**经 Luban 的特性注册机制自注册实现：

| 新增文件 | 作用 |
|---|---|
| `src/Luban.Core/Utils/B1Parser.cs` | 解析 B1 的表元数据串 |
| `src/Luban.Schema.Builtin/SelfContainedTableImporter.cs` | `[TableImporter(Priority=100)]`，扫描并发现自包含表 |
| `src/Luban.Schema.Builtin/SelfContainedSchemaCollector.cs` | `[SchemaCollector(Priority=100)]`，加载内联 `__beans__` / `__enums__` |
| `src/Luban.Tests/` | B1Parser 单元测试 |

`Priority=100` 是关键：Luban 按优先级选取扩展点实现，高优先级的同名实现会覆盖内置的，
因此无需改动上游的注册代码。

### 环境准备

```
esyluban\scripts\build.bat                    -> runtime/      framework-dependent, 需 .NET 8
esyluban\scripts\build.bat --self-contained   -> runtime-sc/   自带运行时, 约 76 MB
```

从 `../src` 构建。两个目录都**不进版本控制**（二进制会让仓库历史不可逆地膨胀），
所以 clone 后必须先跑这一步。日常开发用前者即可，后者只在打 standalone 发布包时需要。

### 跑回归测试

```
esyluban\scripts\test\run_full_tests_example.bat
```

输出落在 `examples/dev/TestOutputs/`，与两份基线逐文件 SHA256 比对，结果写入
`compare_report.json`（核心一致性）与 `compare_report_coverage.json`（覆盖一致性）。

单元测试：`esyluban\scripts\test\run_unit_tests.bat`

### 打发布包

```
esyluban\scripts\release\make_release.bat                    -> EsyLuban-<版本>-win-x64.zip
esyluban\scripts\release\make_release.bat --self-contained   -> ...-win-x64-standalone.zip
```

组装到 `esyluban/dist/`。版本号取自 `src/Luban/Luban.csproj` 的 `<Version>`，
也可作为参数传入。两个包各自打包对应的 `runtime/` 或 `runtime-sc/`，需先构建。

所有脚本调用 `runtime\Luban.exe` 而非 `dotnet Luban.dll`——两种构建都产出 `Luban.exe`，
因此**一套脚本服务两个版本**，不必为 standalone 维护第二份 `gen.bat` 与右键脚本。

打包过程内置冒烟测试：**通过 `gen.bat` 导出包内自带的示例表**。走 `gen.bat` 而不是直接
调 `Luban.exe`，是因为前者才是文档告诉使用者运行的东西——绕过它就会漏掉运行时寻址和参数
处理，而那正是打包出错最容易表现出来的地方。

---

## 目录

```
esyluban/
├─ runtime/        Luban 运行时（构建产物，不进版本控制）
├─ dist/           发布包暂存与产物（不进版本控制）
├─ examples/       数据多数源自上游 luban_examples，出处见 examples/README.md
│  ├─ dev/          回归测试工程：全覆盖用例 + matrix/ + negatives/
│  └─ release/      发布示例工程：干净用例 + Unity 集成演示
├─ baselines/
│  ├─ core/         53 个 json，核心一致性基线
│  └─ coverage/     56 个 json，覆盖一致性基线
├─ scripts/
│  ├─ build.bat     从 ../src 构建运行时
│  ├─ test/         回归测试、基线刷新、覆盖矩阵报告
│  ├─ release/      发布打包脚本与发布包 README
│  ├─ contextmenu/  右键菜单安装/卸载与两个导表入口
│  └─ authoring/    建表模板、矩阵用例生成、xlsx 迁移
├─ templates/      新建工程用的 luban.conf / gen.bat / check.bat 与示例表
├─ docs/
│  ├─ esyluban_beginner_guide.md   完全手册（A 给策划，B 给程序员）
│  └─ internal/    仅供维护者：Luban 参考、源码分析、开发记录、归档
└─ sandbox/        自包含加载器开发期的手工验证沙盒
```

**随项目发布的文档只有三份**：本文件、`docs/esyluban_beginner_guide.md`、
以及 `examples/README.md`（数据出处与 MIT 归属，合规必需）。
发布包内的 `README.md` 由 `scripts/release/RELEASE_README.md` 打包时拷入。
`docs/internal/` 下的内容面向维护者，判断标准见 `docs/internal/README.md`。

---

## 工具与配置的分工

**配置与运行时必须放在一起**（各工程自己的 `Tools/Luban/`），因为右键菜单先从右键位置
向上找 `Tools\Luban\luban.conf`，再在它旁边找 `runtime\Luban.exe`。

本仓库内的示例工程是个例外：它们共享 `esyluban/runtime/` 一份运行时，靠脚本向上搜索命中。
外部项目则每个自带一份（约 6MB），好处是各项目工具版本互相独立，老项目不会因为别处升级
Luban 而被动出问题。

---

## 表定义格式

```
A1 = ##export                （或 ##export=false 关闭导出）
B1 = full_name="test.TbFoo" & read_schema_from_file="true"
```

**`full_name` 是 B1 唯一必填项**——它是这张表的身份，推导不出来。
`read_schema_from_file="true"` 表示结构看下面的 `##var` / `##type` 两行；
不写它则表示结构来自 schema XML 或 `__beans__`。

`value_type`（由表名推导 `TbFoo` → `Foo`）、`output`、`input`、`index`、`mode`
等都有缺省，仅在需要偏离默认时才写。

原 `##var` / `##type` / `##group` / `##comment` 行整体下移一行。
同一 Excel 内还可用 `__enums__` / `__beans__` 子表定义文件级作用域的枚举与 bean。

详见 `docs/esyluban_beginner_guide.md`。
