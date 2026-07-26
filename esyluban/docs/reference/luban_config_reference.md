# Luban 配置/脚本/定义文件全量参考

> 说明: 本文覆盖工作区内所有“非真实数据表”的 Luban 相关文件, 包含脚本、XML 定义、__XXX__.xlsx 定义、核心配置与日志配置等。  
> 数据源文件(实际配置数据)不在本文逐条解释范围内。  
> 新手入门请先看: `docs/esyluban_beginner_guide.md`  
> 覆盖矩阵参考: `docs/coverage_matrix.md`

## 1. 通用参数与字段字典

### 1.1 命令行基础参数 (Luban.dll)

参数来源: `luban/src/Luban/Program.cs`

- `--conf` 必填, 指向 `luban.conf`。
- `-t / --target` 必填, 目标输出, 取自 `luban.conf` 的 targets。
- `-c / --codeTarget` 可选, 代码目标 (可多次指定)。
- `-d / --dataTarget` 可选, 数据目标 (可多次指定)。
- `-f / --forceLoadTableDatas` 强制加载数据, 即使不生成数据。
- `-i / --includeTag` 仅导出指定 tag。
- `-e / --excludeTag` 排除指定 tag。
- `--variant` 字段变体选择。
- `-o / --outputTable` 指定输出表。
- `--timeZone` 时区。
- `--customTemplateDir` 自定义模板目录。
- `--validationFailAsError` 校验失败视为错误。
- `-x / --xargs` 扩展参数, 详见 1.2。
- `-l / --logConfig` 日志配置, 默认 `nlog.xml`。
- `-w / --watchDir` 目录监控自动生成。
- `-v / --verbose` 详细日志。

### 1.2 xargs 关键选项 (内置)

来源: `luban/src/Luban.Core/BuiltinOptionNames.cs` + 官方命令行文档

- `outputCodeDir` 代码输出目录
- `outputDataDir` 数据输出目录
- `{codeTarget}.outputCodeDir` 指定某个 codeTarget 的代码输出目录（优先于上面的兜底项）
- `{dataTarget}.outputDataDir` 指定某个 dataTarget 的数据输出目录（优先于上面的兜底项）

> **前缀只能是 codeTarget / dataTarget，不能是 target。**
> 输出目录的查找命名空间取自 `OutputFileManifest.TargetName`，而该值在
> `DefaultPipeline.ProcessDataTarget` 中来自 **dataTarget**（`json`、`bin`…）、
> 在 `ProcessCodeTarget` 中来自 **codeTarget**（`cs-simple-json`…）。
> 因此 `client.outputDataDir`、`server.outputCodeDir` 这类写法**不会生效**，
> 既不报错也不起作用（实测 `TestOutputs/json` 下并无 client/server 子目录，
> 所有文件都在同一层）。需要按 target 分离输出时，应在各自的 `luban.conf`
> 或调用时用 `-x outputDataDir=...` 指定。
- `fileExt` / `{dataTarget}.fileExt` 指定数据后缀
- `json.compact` 或 `compact` 输出紧凑 JSON
- `dataExporter` 默认 `default`
- `outputSaver` 默认 `local`, 可设 `null`
- `codeStyle` 代码风格
- `namingConvention.{codeTarget}.{location}` 命名约定
- `pathValidator.rootDir` 路径校验根目录
- `tableImporter.name` / `tableImporter.filePattern` / `tableImporter.tableNamespaceFormat`  
  / `tableImporter.tableNameFormat` / `tableImporter.valueTypeNameFormat`
- `tableImporter.scanPath` 仅扫描指定文件/目录 (支持绝对或相对 dataDir)
- `l10n.provider` / `l10n.textFile.path` / `l10n.textFile.keyFieldName`  
  / `l10n.textFile.languageFieldName` / `l10n.convertTextKeyToValue`

### 1.3 变体与 tag

- 变体: `--variant {beanFullName}.{fieldName}={variantName}`  
  示例: `--variant test.TestFieldVariant.name=zh`
- 数据 tag: `__tag__` 字段, `##` 为永久忽略, `unchecked` 为跳过校验

## 2. 核心配置文件

### 2.1 `luban.conf`

示例文件:
- `luban_examples/DataTables/luban.conf`
- `luban_examples/MiniTemplate/luban.conf`

解析实现: `luban/src/Luban.Core/GlobalConfigLoader.cs`

字段说明:

- `groups`: 导出分组定义  
  - `names`: 分组名列表 (如 `["c"]`)  
  - `default`: 是否默认导出分组
- `schemaFiles`: schema 定义集合  
  - `fileName`: 文件或目录  
  - `type`: `"enum" | "bean" | "table" | ""` (空表示 XML)
- `dataDir`: 数据根目录
- `targets`: 输出目标  
  - `name`: 目标名  
  - `manager`: Tables 管理类名  
  - `groups`: 输出分组  
  - `topModule`: 额外命名空间前缀
- `xargs`: 默认扩展参数 (命令行可覆盖)

额外说明:
- JSON 支持注释与尾随逗号 (解析器设置允许)。
- `schemaFiles` 支持目录递归加载。

### 2.2 `nlog.xml`

文件:
- `luban/src/Luban/nlog.xml`
- `EsyLuban/src/Luban/nlog.xml`
- `luban_examples/Tools/Luban/nlog.xml`

作用:
配置 Luban 的日志输出 (console + 异步 wrapper)。  
与命令行参数 `-l` 对应。

核心字段:
- `<targets>`: 定义输出目标  
  - `AsyncWrapper` 队列长度、批处理大小
  - `ColoredConsole` 日志格式与颜色
- `<rules>`: 日志级别与输出目标绑定

## 3. Schema 定义文件 (XML)

解析器: `Luban.Schema.Builtin/XmlSchemaLoader.cs`

### 3.1 XML 语法字段 (通用规则)

- `<module name="...">`  
  - 允许嵌套, 对应 namespace  
- `<enum name="..." flags="0|1" unique="0|1" comment="..." tags="...">`  
  - 子元素: `<var>` 与 `<mapper>`
- `<bean name="..." parent="..." valueType="0|1" sep="," alias="..." comment="..." tags="..." group="...">`  
  - 子元素: `<var>` / `<bean>` / `<mapper>`
- `<table name="..." value="..." input="..." index="..." mode="one|map|list" group="..." readSchemaFromFile="0|1" output="..." tags="...">`
- `<refgroup name="..." ref="a,b,c">`
- `<constalias name="..." value="...">`
- `<mapper target="a,b" codeTarget="cs-bin,cs-json">`  
  - `<option name="type|constructor|...">`  
  - 选项字段由具体 codeTarget 决定

### 3.2 本地 XML 文件清单与解释

#### `luban_examples/MiniTemplate/Defines/builtin.xml`

- 定义 `vector2/3/4` 基础 bean  
  - `valueType=1` 表示值类型 (生成 struct 等)
  - `sep=","` 支持单元格紧凑写法

#### `EsyLuban/TestProject/Defines/builtin.xml`

- 与 MiniTemplate 同结构, 用于测试项目基础向量定义

#### `luban_examples/DataTables/Defines/builtin.xml`

- 定义 `AudioType` enum, 并提供 `mapper` 映射:
  - `client` 侧映射为 `UnityEngine.AudioType`
  - `server` 侧映射为 `CustomAudioType`
- 定义 `vec2/vec3/vec4` 并为 client/server 分别映射 Unity 或 System.Numerics 类型

#### `luban_examples/DataTables/Defines/common.xml`

- 提供时间段、范围结构等公共 bean  
  - `DateTimeRange`, `TimeOfDay`, `IntRange` 等  
  - 示例 table: `TbGlobalConfig`

#### `luban_examples/DataTables/Defines/item.xml`

- 道具系统 enum + bean + table 定义  
  - 示例: `EItemQuality`, `EMajorType`, `TbItem`

#### `luban_examples/DataTables/Defines/l10n.xml`

- 本地化示例 bean + table  
  - `L10NDemo`, `TbL10NDemo`

#### `luban_examples/DataTables/Defines/ai.xml`

- 行为树配置 (多态结构)
  - 使用多层 bean + 子 bean 表达复杂节点树
  - `TbBehaviorTree` 等 table 定义

#### `luban_examples/DataTables/Defines/tag.xml`

- tag 机制示例  
  - `TestTag` 与 `TbTestTag`

#### `luban_examples/DataTables/Defines/test.xml`

- 综合测试定义  
  - enum/bean/table/constalias/refgroup/variant/validators 等全覆盖示例  
  - 是理解 Luban 高级能力的综合样本

## 4. Schema 定义文件 (Excel)

解析器: `Luban.Schema.Builtin/ExcelSchemaLoader.cs`

### 4.0 自包含表定义 (B1 元数据)

EsyLuban 新规范: Excel/CSV 表**不再依赖 `__tables__.xlsx`**, 以 Sheet 自包含元数据完成表定义。

- A1: `##export` / `##export=false`
- B1: `key="value" & key2="value2"` 形式的表元数据
- 旧 `##var/##type/##group/##comment` 等行整体下移一行

支持字段:
`full_name`, `value_type`, `index`, `mode`, `group`, `comment`, `read_schema_from_file`, `input`, `output`, `tags`

规则:
- **`full_name` 是唯一必填项**，其余字段均有缺省
- `value_type` 缺省由表名推导（`TbItem` -> `Item`）
- `output` 缺省由全名生成（`item.TbItem` -> `item_tbitem`，等同上游对空值的 fallback）
- `input` 缺省指向本 sheet 自己，语法为 `sheet名@文件路径`（注意顺序，见 1.4）
- `index` 缺省留空，交由上游取值类型的第一个字段
- `read_schema_from_file` 默认 `false`（结构来自 XML 或 `__beans__`）
- `mode` 默认 `map`
- B1 支持引号与 `\"` 转义

### 1.4 `sheet名@文件路径` 定位语法

上游既有约定（`FileUtil.SplitFileAndSheetName`），`input`、`schemaFiles`、
L10N 配置共用同一套写法。**顺序是 sheet 在前、文件在后**，与常见的 `文件#锚点` 相反：

```
通用道具表@item/道具系统表.xlsx        该文件里名为「通用道具表」的 sheet
item/通用道具表@道具系统表.xlsx        与上一行等价（sheet 名占据路径的一段）
a.json,*@b.json                        逗号分隔多数据源，合成一张表
```

`@` 把一条路径切成「逻辑位置」与「物理落点」：前者是这张表在模块树中的位置，
后者是它实际存放的文件。

### 4.1 `__tables__.xlsx`

**已废弃**: 仅保留说明, 不再作为表定义入口。

字段结构:
- `full_name` 表全名 (含 namespace)
- `value_type` 记录类型
- `index` 主键字段
- `mode` one/map/list
- `group` 导出分组
- `comment` 注释
- `read_schema_from_file` 是否从数据文件标题头读取结构
- `input` 数据源
- `output` 输出文件名
- `tags` 自定义 tags

### 4.2 `__beans__.xlsx`

字段结构:
- `full_name` bean 全名
- `parent` 父类
- `valueType` 是否值类型
- `sep` 默认分隔符
- `alias` 别名
- `comment`
- `tags`
- `group`
- `fields` 字段列表 (子结构)

Field 列表结构:
- `name` / `alias` / `type` / `group` / `comment` / `tags` / `variants`

### 4.3 `__enums__.xlsx`

字段结构:
- `full_name` enum 全名
- `comment`
- `flags` 是否 Flags
- `group`
- `tags`
- `unique` 枚举值唯一性
- `items` 枚举项列表

EnumItem 列表:
- `name` / `alias` / `value` / `comment` / `tags`

### 4.3.1 在普通数据表内定义 Bean/Enum（测例）

结论:
- **Bean**：支持。通过 `read_schema_from_file=true` 从数据表标题头读取结构。
- **Enum/Bean 子表**：支持自动识别。只要同一 Excel 内存在 `__enums__`/`__beans__` 子表，即会自动加载，无需在 `schemaFiles` 中显式声明。

**测例 1：Bean 定义来自数据表标题头（已存在样例）**
- 文件：`esyluban/examples/release/DataTables/test/define_from_excel.xlsx`
- A1/B1:
  - `A1 = ##export`
  - `B1 = full_name="test.TbDefineFromExcel2" & value_type="DefineFromExcel2" & read_schema_from_file="True" & input="test/define_from_excel.xlsx"`
- 标题头示例（同一 sheet）：
  - `##` 行给出字段名
  - `##type` 行给出字段类型  
  - 这些行即为 **Bean 结构定义**

**测例 2：Enum/Bean 定义在同一 Excel 的子表（自动识别）**
- 文件：`esyluban/examples/release/DataTables/test/inline_defs.xlsx`
- 子表名固定为 `__enums__` / `__beans__`（大小写不敏感）
- 子表结构必须与 `__enums__.xlsx` / `__beans__.xlsx` 完全一致（含 `A1=##export`）
- 作用域为 **file-wide**，同文件内多张数据表可复用
- `full_name` 必须包含模块名（如 `test.InlineQuality`），避免跨文件同名冲突

### 4.4 实际文件清单

- `esyluban/examples/release/DataTables/Defines/builtin.xml`
- `esyluban/examples/release/DataTables/Defines/test.xml`
- `esyluban/examples/release/DataTables/**` (示例数据与表定义)

- `luban_examples/MiniTemplate/Datas/__tables__.xlsx`
- `luban_examples/MiniTemplate/Datas/__beans__.xlsx`
- `luban_examples/MiniTemplate/Datas/__enums__.xlsx`
- `luban_examples/DataTables/Datas/__tables__.xlsx`
- `luban_examples/DataTables/Datas/__beans__.xlsx`
- `luban_examples/DataTables/Datas/__enums__.xlsx`
- `EsyLuban/TestProject/Datas/__tables__.xlsx`
- `EsyLuban/TestProject/Datas/__beans__.xlsx`
- `EsyLuban/TestProject/Datas/__enums__.xlsx`

## 5. 脚本文件 (Bat / Sh)

> 说明: 各脚本中出现的参数均按 1.1/1.2 的通用语义解释。  
> 其中出现的绝对路径 (如 D:\workspace2\...) 需在本机环境中调整。

### 5.0 EsyLuban 新工作流 (Tools/Luban)

#### `Tools/Luban/luban.conf`
- 新结构下的统一入口配置, 指向 `DataTables/Defines` 与 `DataTables/` 数据目录。

#### `Tools/Luban/gen.bat`
- 统一生成入口, 将 `--conf` 固定到 `Tools/Luban/luban.conf`, 其余参数透传。

#### `Tools/Luban/check.bat`
- 统一校验入口, 默认 `-t all -f`, 其余参数透传。

#### `esyluban/scripts/test/run_full_tests_example.bat`
- 示例项目全覆盖测试入口:
  - 生成 `TestOutputs/json`（带 L10N）与 `TestOutputs/json_nol10n`（不带 L10N）。
  - 无 L10N 输出与核心基线对比：`luban_examples_pristine/Projects/GenerateDatas/json` -> `TestOutputs/compare_report.json`。
  - 无 L10N 输出与覆盖基线对比：`esyluban/baselines/coverage` -> `TestOutputs/compare_report_coverage.json`。
  - 负例用例会单独运行，**仅记录日志不影响整体导出**，日志为 `TestOutputs/negative_tests.log`。

#### `scripts/run_luban_context_menu_data.bat` / `scripts/run_luban_context_menu_code.bat`
- 全局右键菜单入口脚本（数据/代码），自动寻址 `Tools/Luban`（向上最多 5 层）。
- 仅覆盖 `tableImporter.scanPath`，输出/L10N/校验参数全部来自 `luban.conf` 的 `xargs`。

#### `esyluban/scripts/test/refresh_coverage_baseline.bat`
- 覆盖基线刷新脚本：
  - 将 `esyluban/examples/dev/TestOutputs/json_nol10n` 同步到 `esyluban/baselines/coverage`。
  - 追加刷新记录到 `esyluban/baselines/baseline_log.md`。

#### `esyluban/scripts/test/report_coverage_matrix.bat`
- 覆盖矩阵摘要报告：
  - 扫描 `DataTables/matrix` 与 `DataTables/negatives`。
  - 输出 `esyluban/examples/dev/TestOutputs/coverage_matrix_report.json`。

#### `esyluban/scripts/authoring/create_matrix_cases.py`
- 覆盖矩阵用例生成工具：
  - 生成/刷新 `DataTables/matrix/feature_tables.xlsx` 与 `DataTables/negatives/path_fail.xlsx`
  - 追加 `__beans__.xlsx` / `__enums__.xlsx` 的矩阵用例定义

#### `esyluban/scripts/authoring/create_table_template.bat` / `scripts/create_table_template.py`
- 最小表模板生成工具：
  - 生成包含 `A1=##export` 与 `B1` 元数据、`##var/##type` 的新表模板。

### 5.2 单一来源配置建议

推荐将输出目录、校验与 L10N 参数统一写入 `Tools/Luban/luban.conf` 的 `xargs`，脚本不再覆盖：
```
"xargs": [
  "outputDataDir=../../TestOutputs/json",
  "outputCodeDir=../../TestOutputs/code",
  "cs-simple-json.outputCodeDir=../../TestOutputs/code/cs-simple-json",
  "pathValidator.rootDir=../../DataTables/Assets",
  "l10n.provider=default",
  "l10n.textFile.path=../../DataTables/l10n/texts.xlsx",
  "l10n.textFile.keyFieldName=key",
  "l10n.textFile.languageFieldName=zh",
  "l10n.convertTextKeyToValue=1"
]
```

#### 5.3 右键菜单参数配置（contextMenu）
右键数据/代码入口可通过 `luban.conf` 配置，无需改脚本：  
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
说明：  
- `data.targets` 控制右键导出哪些表 target  
- `data.dataTarget` 控制 `-d`  
- `code.target` 控制表 target  
- `code.codeTargets` 控制 `-c` 列表  
- `extraArgs` 追加参数（如 `--variant` / `--includeTag` / `--validationFailAsError` / `-x key=val`）

#### `esyluban/scripts/contextmenu/install_luban_context_menu.bat` / `uninstall_luban_context_menu.bat`
- 全局安装/卸载 Windows 右键菜单 (HKLM, 需管理员)。
- 安装时将 `run_luban_context_menu_data.bat` / `run_luban_context_menu_code.bat` 复制到 `%ProgramData%\EsyLuban`，保证多项目共用。
- 因注册表指向的是该副本，改动脚本后需**重新运行安装脚本**才生效。

#### `esyluban/scripts/build.bat`
- 从仓库 `src/` 构建 Luban 运行时到 `esyluban/runtime/`。
- 运行时不进版本控制，clone 后需先执行一次。

#### `esyluban/scripts/test/run_unit_tests.bat`
- 运行 `src/Luban.Tests`（B1Parser 单元测试）。
- 该测试项目刻意不写入上游 `Luban.sln`，`dotnet test` 直接接受项目路径即可。

> **已退役：`scripts/sync_example_tools.bat`**
> 早期工具本体随每个示例工程各存一份，需靠该脚本复制同步。现在运行时全仓库
> 只有 `esyluban/runtime/` 一份，各工程仅保留自己的 `luban.conf` 与 gen/check 入口，
> 由脚本分别向上寻址，同步机制与"忘记同步"的风险一并消失。

### 5.1 构建与格式化

#### `luban_examples/Tools/build-luban.bat`
- 变量: 无
- 命令:
  - `dotnet build ../../luban/src/Luban/Luban.csproj -c Release -o Luban`
- 作用: 编译 Luban 工具并输出到 `Tools/Luban/`。

#### `luban_examples/Tools/build-luban.sh`
- 同上, Shell 版本。

#### `luban/scripts/format.bat` / `luban/scripts/format.sh`
#### `EsyLuban/scripts/format.bat` / `EsyLuban/scripts/format.sh`
- 命令: `dotnet format --severity error -v n`
- 作用: 对源码目录执行格式化与错误级别检查。

### 5.2 MiniTemplate

#### `luban_examples/MiniTemplate/gen.bat`
- `-t all`, `-d json`
- `--conf luban.conf`
- `-x outputDataDir=output`
- 作用: 最小模板生成 JSON 数据。

#### `luban_examples/MiniTemplate/gen.sh`
- 同上, Shell 版本。

### 5.3 DataTables 校验脚本

#### `luban_examples/DataTables/check.bat`
- `-t all`, `-f`, `--conf luban.conf`
- `-x pathValidator.rootDir=...`
- `-x l10n.textProviderFile=...`  
  - 注意: 当前源码内置配置键为 `l10n.textFile.path`, 该脚本可能为旧版本参数。

#### `luban_examples/DataTables/check.sh`
- 同上, Shell 版本。

### 5.4 githooks-demo

#### `luban_examples/githooks-demo/auto_validation.sh`
- 与 `DataTables/check.sh` 相同逻辑。

#### `luban_examples/githooks-demo/pre-commit`
- 调用 `auto_validation.sh`  
  - 校验失败则拒绝提交。

### 5.5 Unity + C# 示例

#### `luban_examples/Projects/Csharp_Unity_json/gen.bat`
- `-t client`
- `-c cs-simple-json`
- `-d json`
- `-x outputCodeDir=Assets/Gen`
- `-x outputDataDir=..\GenerateDatas\json`
- `-x pathValidator.rootDir=...`
- `-x l10n.provider=default`
- `-x l10n.textFile.path=.../texts.xlsx`
- `-x l10n.textFile.keyFieldName=key`

#### `luban_examples/Projects/Csharp_Unity_bin/gen.bat`
- `-t client`
- `-c cs-bin`
- `-d bin`
- `-x outputCodeDir=Assets/Gen`
- `-x outputDataDir=..\GenerateDatas\bytes`
- 其他参数同上

#### `luban_examples/Projects/Csharp_Unity_Editor_json/gen.bat`
- `-t editor`
- `-c cs-editor-json`
- `-x outputCodeDir=Assets/Gen`
- 不生成 dataTarget

#### `luban_examples/Projects/Csharp_Unity_LazyLoad_bin/gen.bat`
- `-t client`
- `-c cs-lazyload-bin`
- `-d bin bin-offsetlength`
- `-x bin.outputDataDir=Unity/Assets/StreamingAssets/Config/bin`
- `-x bin-offsetlength.outputDataDir=Unity/Assets/StreamingAssets/Config/offset`
- 注意: 代码内置 dataTarget 名为 `bin-offset`, 该脚本可能为旧版本命名。

### 5.6 .NET / C# 服务端

#### `luban_examples/Projects/Csharp_DotNet_bin/gen.bat`
- `-t server`
- `-c cs-bin`
- `-d bin`
- `-x outputCodeDir=Gen`
- `-x outputDataDir=..\GenerateDatas\bytes`

#### `luban_examples/Projects/Csharp_DotNet_json/gen.bat`
- `-t server`
- `-c cs-dotnet-json`
- `-d json`
- `-x outputCodeDir=Gen`
- `-x outputDataDir=..\GenerateDatas\json`
- `-x pathValidator.rootDir=D:\workspace2\...` (需替换)

#### `luban_examples/Projects/Csharp_NewtonSoft_json/gen.bat`
- `-t server`
- `-c cs-newtonsoft-json`
- `-d json`
- `-x outputCodeDir=Gen`
- `-x outputDataDir=..\GenerateDatas\json`
- `-x pathValidator.rootDir=D:\workspace2\...` (需替换)

### 5.7 Protobuf 方案

#### `luban_examples/Projects/Csharp_Protobuf/gen_pb_schema_code_bin.bat`
- `-t all`
- `-c cs-protobuf3`
- `-c protobuf3`
- `-d protobuf3-bin`
- `-x cs-protobuf3.outputCodeDir=Gen`
- `-x protobuf3.outputCodeDir=pb_schemas`
- `-x outputDataDir=pb_datas`

#### `luban_examples/Projects/Csharp_Protobuf/gen_pb_schema_code_json.bat`
- 与上相同, `-d protobuf3-json`

#### `luban_examples/Projects/Csharp_Protobuf/gen_pb_code.bat`
- 使用 `protoc` 对 `schema.proto` 生成 C# 代码

#### `luban_examples/Projects/Protobuf2_bin/gen_pb_schema_data.bat`
- `-c protobuf2`, `-d protobuf2-bin`
- 输出 `pb_schemas` / `pb_datas`

#### `luban_examples/Projects/Protobuf2_json/gen_pb_schema_data.bat`
- `-c protobuf2`, `-d protobuf2-json`

#### `luban_examples/Projects/Protobuf2_bin/gen_pb_code.bat`
#### `luban_examples/Projects/Protobuf2_json/gen_pb_code.bat`
#### `luban_examples/Projects/Protobuf3_bin/gen_pb_code.bat`
#### `luban_examples/Projects/Protobuf3_json/gen_pb_code.bat`
- 统一调用 `protoc -I=pb_schemas --csharp_out=Gen pb_schemas/schema.proto`

#### `luban_examples/Projects/Protobuf3_bin/gen_pb_schema_data.bat`
#### `luban_examples/Projects/Protobuf3_json/gen_pb_schema_data.bat`
- `-c protobuf3`, `-d protobuf3-bin|protobuf3-json`

### 5.8 FlatBuffers

#### `luban_examples/Projects/Flatbuffers_json/gen_platbuffers_schema_data.bat`
- `-c flatbuffers`
- `-d flatbuffers-json`
- `-x outputCodeDir=schemas`
- `-x outputDataDir=json`
- `-x pathValidator.rootDir=D:\workspace2\...` (需替换)
- `-x l10n.textProviderFile=...` (旧参数名提示)

#### `luban_examples/Projects/Flatbuffers_json/gen_platbuffers_code.bat`
- `flatc` 生成 C# 代码与示例数据
- `--root-type cfg.TestTbTestNull` 直接指定表类型

### 5.9 MsgPack

#### `luban_examples/Projects/MsgPack_bin/gen.bat`
- `-d msgpack`
- `-x outputDataDir=msg_datas`
- `-x l10n.textProviderFile=...` (旧参数名提示)

### 5.10 Lua

#### `luban_examples/Projects/Lua_lua/gen.bat`
- `-c lua-lua`
- `-d lua`
- `-x outputCodeDir=Gen`
- `-x outputDataDir=..\GenerateDatas\lua`

#### `luban_examples/Projects/Lua_Unity_xlua_bin/gen.bat`
- `-c lua-bin`
- `-d bin`
- `-x outputCodeDir=Assets/Lua/Gen`
- `-x outputDataDir=..\GenerateDatas\bytes`

### 5.11 Go

#### `luban_examples/Projects/Go_bin/gen.bat`
- `-c go-bin`
- `-d bin`
- `-x outputCodeDir=gen`
- `-x outputDataDir=..\GenerateDatas\bytes`
- `-x lubanGoModule=demo/luban`

#### `luban_examples/Projects/Go_json/gen.bat`
- `-c go-json`
- `-d json`
- `-x outputDataDir=..\GenerateDatas\json`
- `-x lubanGoModule=demo/luban`

### 5.12 Java

#### `luban_examples/Projects/Java_bin/gen.bat`
- `-c java-bin`
- `-d bin`
- `-x outputCodeDir=src/main/gen/cfg`

#### `luban_examples/Projects/java_json/gen.bat`
- `-c java-json`
- `-d json`
- `-x outputCodeDir=src/gen/cfg`

#### `luban_examples/Projects/java_json/gradlew.bat`
- Gradle wrapper, 非 Luban 配置脚本, 仅供项目构建使用。

### 5.13 JavaScript / TypeScript

#### `luban_examples/Projects/Javascript_NodeJs_bin/gen.bat`
- `-c javascript-bin`
- `-d bin`
- `-x outputCodeDir=Gen`
- `-x outputDataDir=..\GenerateDatas\bytes`

#### `luban_examples/Projects/Javascript_NodeJs_json/gen.bat`
- `-c javascript-json`
- `-d json`
- `-x outputDataDir=..\GenerateDatas\json`

#### `luban_examples/Projects/TypeScript_NodeJs_Bin/gen.bat`
- `-c typescript-bin`
- `-d bin`

#### `luban_examples/Projects/TypeScript_NodeJs_json/gen.bat`
- `-c typescript-json`
- `-d json`

#### `luban_examples/Projects/TypeScript_Cocos2_bin/gen.bat`
#### `luban_examples/Projects/TypeScript_Cocos3_bin/gen.bat`
- `-c typescript-bin`
- `-d bin`
- `-x outputCodeDir=assets/scripts/schema`
- `-x outputDataDir=assets/resources`
- `-x bin.fileExt=bin`

### 5.14 Rust / Python / Dart / GDScript / PHP

#### `luban_examples/Projects/Rust_bin/gen.bat`
- `-c rust-bin`
- `-d bin`

#### `luban_examples/Projects/Rust_Json/gen.bat`
- `-c rust-json`
- `-d json`

#### `luban_examples/Projects/Python_json/gen.bat`
- `-c python-json`
- `-d json`

#### `luban_examples/Projects/Dart_json/gen.bat`
- `-c dart-json`
- `-d json`
- `-x outputCodeDir=lib/gen`
- `-x outputDataDir=json`

#### `luban_examples/Projects/GDScript_json/gen.bat`
- `-c gdscript-json`
- `-d json`

### 5.15 C++ 示例

#### `luban_examples/Projects/Cpp_rawptr_bin/gen.bat`
- `-c cpp-rawptr-bin`
- `-d bin`

#### `luban_examples/Projects/Cpp_sharedptr_bin/gen.bat`
- `-c cpp-sharedptr-bin`
- `-d bin`

### 5.16 纯数据导出脚本 (GenerateDatas)

#### `gen_data_bytes.bat`
- `-d bin`, `-x outputDataDir=bytes`

#### `gen_data_json.bat`
- `-d json`, `-x outputDataDir=json`

#### `gen_data_json2.bat`
- `-d json2`, `-x outputDataDir=json2`

#### `gen_data_json_compact.bat`
- `-d json`, `-x compact=1`

#### `gen_data_json_convert.bat`
- `-d json-convert`, `-x outputDataDir=json-convert`

#### `gen_data_json_monolithic.bat`
- 使用 `Luban.ClientServer.exe` (旧版本)  
  - `--gen_types data_json_monolithic`  
  - `--output:data:json_monolithic_file json_monolithic/all.json`

#### `gen_data_bson.bat`
- `-d bson`, `-x outputDataDir=bson`

#### `gen_data_lua.bat`
- `-d lua`, `-x outputDataDir=lua`

#### `gen_data_xml.bat`
- `-d xml`, `-x outputDataDir=xml`

#### `gen_data_yaml.bat`
- `-d yml`, `-x outputDataDir=yaml`

### 5.17 CfgValidator

#### `luban_examples/Projects/CfgValidator/run_CfgValidator.bat`
- `-c cs-dotnet-json`
- `-d json`
- `-x outputCodeDir=Gen`
- `-x outputDataDir=..\GenerateDatas\json`
- 之后执行 `dotnet test` 做配置校验

### 5.18 EsyLuban TestProject

#### `EsyLuban/TestProject/gen.sh`
- `-t all`, `-d json`
- `--conf ./luban.conf`
- `-x outputDataDir=output`

## 6. 其他配置与依赖文件

- `nuget.config` (Luban 构建依赖)
- `.runtimeconfig.json` / `.deps.json` (Tools/Luban 内置运行时配置)
- `package.json`, `manifest.json` (示例工程依赖, 非 Luban 核心)

## 7. 备注与兼容性提示

- 多个脚本仍使用旧参数 `l10n.textProviderFile`, 对应新参数为 `l10n.textFile.path`。
- `bin-offsetlength` 与 `bin-offset` 命名需与源码对齐。
- 示例脚本中的绝对路径必须根据本地环境替换。
- `__tables__.xlsx` 在 EsyLuban 中已废弃, 请改用 `##export + B1` 自包含表定义。
- `#AutoImport` 文件名自动导表规则已替换为 B1 元数据解析。
- Excel/CSV 的 `##var/##type/...` 需整体下移一行, A1 固定 `##export`。
