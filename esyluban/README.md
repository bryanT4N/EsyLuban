# EsyLuban 自有资产子树

本目录收纳 EsyLuban 的**全部自有资产**。仓库根目录保持为**上游 Luban 原物**
（`src/`、`docs/`、`scripts/`、`LICENSE`、`README.md` 等），一字未改。

这条分界线是本 fork 的核心约束：**只新增文件，从不修改上游文件**。
验证方式：

```bash
git diff --name-status origin/main -- src
# 应当只出现 A（新增），不应出现任何 M（修改）
```

功能本体由 `src/` 下三个**新增**文件实现，靠 Luban 的特性注册机制自注册，
因此无需改动上游任何一行代码：

| 文件 | 作用 |
|---|---|
| `src/Luban.Core/Utils/B1Parser.cs` | 解析 B1 单元格的表元数据串 |
| `src/Luban.Schema.Builtin/SelfContainedExcelSchemaLoader.cs` | `[SchemaLoader(Priority=100)]` 自注册，接管 xlsx schema 加载 |
| `src/Luban.Tests/` | B1Parser 的单元测试 |

---

## 目录

```
esyluban/
├─ runtime/        Luban 运行时（构建产物，不进版本控制）
├─ examples/      数据多数源自上游 luban_examples，出处见 examples/README.md
│  ├─ dev/         回归测试工程：全覆盖用例 + matrix/ + negatives/
│  └─ release/     发布示例工程：干净用例 + Unity 集成演示
├─ baselines/
│  ├─ core/        53 个 json，核心一致性基线（源自上游 luban_examples）
│  └─ coverage/    55 个 json，覆盖一致性基线（由 dev 工程输出刷新）
├─ scripts/
│  ├─ build.bat    从 ../src 构建运行时
│  ├─ test/        回归测试、基线刷新、覆盖矩阵报告
│  ├─ contextmenu/ 右键菜单安装/卸载与两个导表入口
│  └─ authoring/   建表模板、矩阵用例生成、xlsx 迁移
├─ templates/      新建工程用的 luban.conf / gen.bat / check.bat 模板
├─ docs/
│  ├─ guides/      新手指南、使用讲解
│  ├─ reference/   Luban 配置参考、源码分析
│  ├─ dev/         优化日志、覆盖矩阵、全链路集成、结构设计
│  └─ archive/     已废弃的分析稿、历史迁移报告
└─ sandbox/        自包含加载器开发期的手工验证沙盒
```

---

## 快速上手

**1. 构建运行时**（clone 后必做一次，运行时不在版本控制里）

```
esyluban\scripts\build.bat
```

**2. 跑回归测试**

```
esyluban\scripts\test\run_full_tests_example.bat
```

输出落在 `examples/dev/TestOutputs/`，并与两份基线逐文件 SHA256 比对，
结果写入 `compare_report.json`（核心）与 `compare_report_coverage.json`（覆盖）。

**3. 安装右键菜单**（需管理员）

```
esyluban\scripts\contextmenu\install_luban_context_menu.bat
```

装好后右键任意文件夹 / 文件夹空白处 / 单个 xlsx，会出现
`Luban Export (Data)` 与 `Luban Export (Code)`，仅导出所选范围内的表。

---

## 工具与配置的分工

**运行时全仓库只存一份**（`runtime/`），**配置随工程走**（各工程自己的
`Tools/Luban/luban.conf`）。两者由脚本分别寻址：配置从右键位置向上找
`Tools\Luban\luban.conf`，运行时从工程根向上找 `runtime\Luban.dll`。

这样拆开之后，工具更新不需要再往各工程复制副本，历史上的
`sync_example_tools.bat` 同步机制及其"忘记同步"风险随之消失。

---

## 表定义格式

```
A1 = ##export                （或 ##export=false 关闭导出）
B1 = full_name="test.TbFoo" & value_type="Foo" & index="id" & mode="map" & input="test/foo.xlsx"
```

原 `##var` / `##type` / `##group` / `##comment` 行整体下移一行。
同一 Excel 内还可用 `__enums__` / `__beans__` 子表定义文件级作用域的枚举与 bean。

详见 `docs/guides/esyluban_beginner_guide.md`。
