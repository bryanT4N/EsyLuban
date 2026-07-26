# EsyLuban 使用讲解（示例项目版）

本文面向 `esyluban/examples/release`，说明**发布版示例项目的常规使用方式**。
测试与回归请使用 `esyluban/examples/dev`。
从零入门与最佳实践请优先阅读 `esyluban/docs/guides/esyluban_beginner_guide.md`。

## 1. 示例项目结构

```
esyluban/examples/release/
├─ DataTables/                 # 配置与数据
│  ├─ Defines/                 # XML Schema 定义（注意：目录名不能以 _ 开头）
│  ├─ __beans__.xlsx           # 全局 Bean 定义
│  ├─ __enums__.xlsx           # 全局 Enum 定义
│  └─ ...                      # 各类数据表 / 数据源
├─ Projects/
│  └─ Csharp_Unity_json/       # Unity 示例工程（json）
└─ Tools/
   └─ Luban/                   # 只放本工程自己的配置与入口
      ├─ luban.conf
      ├─ gen.bat
      └─ check.bat
```

注意 `Tools/Luban/` 里**没有 Luban.dll**。运行时全仓库共享一份，位于
`esyluban/runtime/`，由 `gen.bat` / `check.bat` / 右键菜单自动向上寻址。
工具更新后无需再往各工程复制副本。

## 2. 准备运行时（clone 后必做一次）

运行时是构建产物，不进版本控制。执行：

```
esyluban\scripts\build.bat
```

它从仓库的 `src/` 构建出 `esyluban/runtime/`。之后所有入口才能找到 `Luban.dll`。

## 3. 自包含表定义

- **A1**：`##export`，或 `##export=false` 关闭导出
- **B1**：表元数据

原 `##var` / `##type` / `##group` / `##comment` 行整体下移一行。

### 3.1 B1 写多少？—— 只有 `full_name` 是必填的

```
full_name="test.TbFoo"
```

这就是一张完整可用的表定义。其余字段都有缺省，**能不写就不写**：

| 字段 | 不写时 | 什么时候才需要写 |
|---|---|---|
| `value_type` | 由表名推导：`TbFoo` → `Foo` | 值类型名不遵循 `Tb` 前缀约定时 |
| `output` | 由全名生成：`test.TbFoo` → `test_tbfoo` | 想自定义输出文件名时 |
| `input` | 指向本 sheet 自己 | 数据在别的文件 / 多个数据源时 |
| `index` | 取值类型的第一个字段 | 主键不是第一个字段时 |
| `read_schema_from_file` | `false`（结构来自 XML 或 `__beans__`） | 想让结构也写在本表标题行里，填 `true` |
| `mode` | `map` | 单例表填 `one`，列表表填 `list` |
| `group` / `comment` / `tags` | 空 | 需要时才写 |

**结构与数据同在一表**（最自包含的形态）只需两个字段：

```
full_name="test.TbMinimal" & read_schema_from_file="true"
```

可运行的样例见 `esyluban/examples/dev/DataTables/test/minimal_b1.xlsx`。

### 3.2 `input` 的定位语法：`sheet名@文件路径`

注意顺序是 **sheet 在前、文件在后**，与常见的 `文件#锚点` 相反：

```
input="通用道具表@item/道具系统表.xlsx"     # 该文件里名为「通用道具表」的 sheet
input="a.json,*@b.json"                    # 逗号分隔多个数据源，合成一张表
```

理解方式：`@` 把一条路径切成「逻辑位置」和「物理落点」——
`item/通用道具表@道具系统表.xlsx` 读作"逻辑上是 item 下的『通用道具表』，
物理上躺在 道具系统表.xlsx 里"。因此 sheet 名占据路径的一段，写在 `@` 左边。

### 3.3 内联枚举 / Bean 子表

- 同一 Excel 内名为 `__enums__` / `__beans__` 的 sheet 会被自动识别为定义
- 子表结构需与 `DataTables/__enums__.xlsx` / `__beans__.xlsx` 一致（含 `A1=##export`）
- 作用域为 file-wide：同一文件内多张数据表可共用
- `full_name` 需包含模块名（如 `test.InlineQuality`）
- 示例：`DataTables/test/inline_defs.xlsx`

这样一张表连同它专用的类型定义可以放在同一个文件里交付，不必回到集中的
`__beans__.xlsx` 登记。

### 3.4 单一来源配置

输出目录、校验与 L10N 统一写在 `Tools/Luban/luban.conf` 的 `xargs`，
脚本（gen / check / 右键）不再覆盖这些参数：

```
"xargs": [
  "client.outputDataDir=../../Projects/Csharp_Unity_json/Assets/GenData/client",
  "client.outputCodeDir=../../Projects/Csharp_Unity_json/Assets/GenCode/client",
  "pathValidator.rootDir=../../Projects/Csharp_Unity_json",
  "l10n.provider=default",
  "l10n.textFile.path=../../DataTables/l10n/texts.xlsx",
  "l10n.textFile.keyFieldName=key",
  "l10n.textFile.languageFieldName=zh",
  "l10n.convertTextKeyToValue=1"
]
```

`pathValidator.rootDir` 指向**工程根**，而不是 `Assets` 目录本身 ——
表里存的资源路径通常自带 `Assets/` 前缀，两处都写会拼成重复路径。

## 4. 生成与校验

```
esyluban\examples\release\Tools\Luban\gen.bat      生成数据
esyluban\examples\release\Tools\Luban\check.bat    校验数据
```

## 5. Unity 示例

- 工程：`Projects/Csharp_Unity_json`，演示在 Unity 中加载生成数据（json）的最小工程
- 生成结果落在 `Assets/GenData` 与 `Assets/GenCode`

## 6. 右键菜单

```
安装  esyluban\scripts\contextmenu\install_luban_context_menu.bat   （需管理员）
卸载  esyluban\scripts\contextmenu\uninstall_luban_context_menu.bat
```

装好后右键**文件夹 / 文件夹空白处 / 单个 xlsx**，会出现
`Luban Export (Data)` 与 `Luban Export (Code)`，只导出所选范围内的表。

- 寻址：从所选位置向上最多 5 层找 `Tools\Luban\luban.conf`；运行时再向上找
  `esyluban\runtime\Luban.dll`
- 修改了 `scripts/contextmenu/` 下的脚本后，需**重新运行一次安装脚本**才生效
  —— 注册表指向的是 `%ProgramData%\EsyLuban` 下的副本

右键行为写在 `luban.conf`，无需改脚本：

```
"contextMenu": {
  "data": { "targets": ["client","server","editor"], "dataTarget": "json", "extraArgs": [] },
  "code": { "targets": ["client","server"], "codeTargets": ["cs-simple-json"], "extraArgs": [] }
}
```

## 7. 辅助脚本

```
esyluban\scripts\build.bat                        构建运行时
esyluban\scripts\test\run_full_tests_example.bat  全量回归 + 双基线比对
esyluban\scripts\test\run_unit_tests.bat          B1Parser 单元测试
esyluban\scripts\test\refresh_coverage_baseline.bat  刷新覆盖基线
esyluban\scripts\authoring\create_table_template.bat --output <path.xlsx> --full-name test.TbFoo
```

## 8. 常见提示

- **A1 有 `##export` 但 B1 为空**：视作由其它机制导出（L10N 文本表等），
  只告警、不中断
- **path 校验报错**：`examples/dev` 内含**故意的**错误用例（`negatives/` 目录），
  用于覆盖测试
- **variant 警告**：字段变体未设置 `--variant` 会提示 WARN
- **目录名不要以 `_` 开头**：Luban 会忽略以 `.` / `_` / `~` 开头的路径段，
  放在这类目录里的定义文件会被静默跳过
