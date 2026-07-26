# EsyLuban 使用讲解 (示例项目版)

本文面向 `Projects/EsyLuban_Example_release`，用于说明**发布版示例项目的常规使用方式**。
测试与回归请使用 `Projects/EsyLuban_Example_dev`。
如需从零入门与最佳实践，请优先阅读：`docs/esyluban_beginner_guide.md`。

## 1. 示例项目结构

```
Projects/EsyLuban_Example_release/
├─ DataTables/                 # 配置与数据
│  ├─ __Defines__/             # XML Schema 定义
│  ├─ __beans__.xlsx           # Bean 定义
│  ├─ __enums__.xlsx           # Enum 定义
│  └─ ...                      # 各类数据表/数据源
├─ Projects/
│  └─ Csharp_Unity_json/        # Unity 示例工程 (json)
├─ Tools/
│  └─ Luban/                   # 工具本体 + 示例配置与脚本
│     ├─ Luban.dll
│     ├─ luban.conf
│     ├─ gen.bat
│     ├─ check.bat
│     ├─ install_luban_context_menu.bat
│     └─ uninstall_luban_context_menu.bat
└─ TestOutputs/                # 生成输出（运行后产生）
```

## 2. 工具版本保持最新 (复制同步)

- 使用根目录脚本：`scripts/sync_example_tools.bat`
- 作用：从根目录 `Tools/Luban` 复制工具文件到示例项目：
  - `Projects/EsyLuban_Example_dev/Tools/Luban`
  - `Projects/EsyLuban_Example_release/Tools/Luban`
- 约定：**不覆盖**示例项目的 `luban.conf`。

## 3. 自包含表定义规范

- A1: `##export` 或 `##export=false`
- B1: 表元数据（示例）

```
full_name="test.TbFoo" & value_type="Foo" & index="id" & mode="map" & input="test/foo.xlsx"
```

注意：原 `##var/##type/##group/##comment` 行需整体下移一行。

### 3.1 内联枚举/Bean 子表

- 同一 Excel 内支持 `__enums__` / `__beans__` 子表自动识别
- 子表结构需与 `DataTables/__enums__.xlsx` / `DataTables/__beans__.xlsx` 一致（含 `A1=##export`）
- 作用域为 file-wide：同一文件内多张数据表可复用
- `full_name` 必须包含模块名（如 `test.InlineQuality`）
- 示例文件：`DataTables/test/inline_defs.xlsx`

### 3.2 单一来源配置（推荐）

- 输出目录、校验与 L10N 统一写入 `Tools/Luban/luban.conf` 的 `xargs`。
- 脚本（gen/check/右键）不再覆盖这些参数，避免多处修改。

示例片段：
```
"xargs": [
  "outputDataDir=../../TestOutputs/json/all",
  "all.outputDataDir=../../TestOutputs/json/all",
  "client.outputDataDir=../../TestOutputs/json/client",
  "server.outputDataDir=../../TestOutputs/json/server",
  "editor.outputDataDir=../../TestOutputs/json/editor",
  "test.outputDataDir=../../TestOutputs/json/test",
  "outputCodeDir=../../TestOutputs/code/all",
  "client.outputCodeDir=../../TestOutputs/code/client",
  "server.outputCodeDir=../../TestOutputs/code/server",
  "editor.outputCodeDir=../../TestOutputs/code/editor",
  "cs-simple-json.outputCodeDir=../../TestOutputs/code/cs-simple-json",
  "pathValidator.rootDir=../../DataTables/Assets",
  "l10n.provider=default",
  "l10n.textFile.path=../../DataTables/l10n/texts.xlsx",
  "l10n.textFile.keyFieldName=key",
  "l10n.textFile.languageFieldName=zh",
  "l10n.convertTextKeyToValue=1"
]
```

## 4. 生成与校验

### 4.1 生成数据
```
Projects/EsyLuban_Example_release/Tools/Luban/gen.bat
```

### 4.2 校验数据
```
Projects/EsyLuban_Example_release/Tools/Luban/check.bat
```


## 5. Unity 示例

- 示例工程：`Projects/Csharp_Unity_json`
- 用途：演示 Unity 中加载 Luban 生成数据的最小工程（json）。
- 提示：资源路径校验依赖 `luban.conf` 的 `pathValidator.rootDir`。

## 6. 右键菜单

- 安装：`Tools/Luban/install_luban_context_menu.bat`（全局安装，两个菜单项）
- 卸载：`Tools/Luban/uninstall_luban_context_menu.bat`
- 使用：右键点击 `DataTables` 或单个 Excel 文件即可导表/生成代码（数据入口会覆盖 `tableImporter.scanPath`）。
- 寻址：从所选路径向上最多 5 层寻找 `Tools/Luban` 与 `Tools/luban.conf`。
- 数据入口：`scripts/run_luban_context_menu_data.bat`（`client/server/editor`）
- 代码入口：`scripts/run_luban_context_menu_code.bat`（`client + cs-simple-json`）

右键配置（写在 `luban.conf`，无需改脚本）：
```
"contextMenu": {
  "data": {
    "targets": ["client","server","editor"],
    "dataTarget": "json",
    "extraArgs": []
  },
  "code": {
    "target": "client",
    "codeTargets": ["cs-simple-json"],
    "extraArgs": []
  }
}
```

## 7. 快速模板工具

- 生成最小表模板：
  - `scripts/create_table_template.bat --output <path.xlsx> --full-name test.TbFoo --value-type test.Foo`
- 可选字段：
  - `--index id`
  - `--mode map|one|list`
  - `--field name:type`（可重复）

## 8. 常见提示与处理

- **缺少 B1 元数据**：XML 定义表或目录型数据表会输出 WARN，不影响导出。
- **path 校验错误**：示例数据内含错误用例，用于覆盖测试。
- **variant 警告**：字段变体未设置 `--variant` 会提示 WARN。

