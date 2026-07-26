# EsyLuban 项目集成与导表全链路（源码级）

> 范围：导表全链路 + 工具脚本/右键/测试脚本；覆盖配置项、指令语义与覆盖关系。  
> 新手与最佳实践入口：`docs/esyluban_beginner_guide.md`

## 1. CLI 入口与参数（Program）

入口与主要参数解析在 `Program.cs`：  
- `--conf` 必填  
- `-t` target 必填  
- `-c` 代码目标、`-d` 数据目标  
- `-x` 额外参数（xargs）  
- `--validationFailAsError` 控制校验失败退出  
```32:152:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban\Program.cs
[Option("conf", Required = true, HelpText = "luban conf file")]
[Option('t', "target", Required = true, HelpText = "target name")]
[Option('c', "codeTarget", Required = false, HelpText = "code target name")]
[Option('d', "dataTarget", Required = false, HelpText = "data target name")]
[Option('x', "xargs", Required = false, HelpText = "args like -x a=1 -x b=2")]
```

`xargs` 的覆盖关系：配置文件中的 `xargs` 先加载，命令行 `-x` 覆盖同名键。  
```242:273:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban\Program.cs
private static Dictionary<string, string> ParseXargs(IEnumerable<string> defaultXargs, IEnumerable<string> cmdXargs)
{
    var defaultXargsMap = ParseXargs0(defaultXargs);
    var cmdXargsMap = ParseXargs0(cmdXargs);
    foreach (var kv in cmdXargsMap)
    {
        defaultXargsMap[kv.Key] = kv.Value;
    }
    return defaultXargsMap;
}
```

## 2. 配置文件加载（luban.conf）

`luban.conf` 解析逻辑：  
- `dataDir`、`schemaFiles`、`targets`、`groups`、`xargs`  
- `dataDir` 是相对 `luban.conf` 的路径  
```79:121:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban.Core\GlobalConfigLoader.cs
var dataInputDir = Path.Combine(_curDir, globalConf.DataDir);
...
foreach (var schemaFile in globalConf.SchemaFiles)
{
    string fileOrDirectory = Path.Combine(_curDir, schemaFile.FileName);
    foreach (var subFile in FileUtil.GetFileOrDirectory(_curDir, fileOrDirectory))
    {
        importFiles.Add(new SchemaFileInfo() { FileName = subFile, Type = schemaFile.Type });
    }
}
```

### 2.1 单一来源配置规范（项目集成）
将所有运行时可选项集中写入 `xargs`，脚本不再覆盖：  
- `outputDataDir` / `{target}.outputDataDir` / `{dataTarget}.outputDataDir`  
- `pathValidator.rootDir`  
- `l10n.*`  

示例（示例项目）：
```json
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

## 3. 选项来源与覆盖关系（EnvManager + xargs）

### 3.1 选项来源（最终进入 EnvManager）
- `luban.conf` 只包含 `groups/schemaFiles/dataDir/targets/xargs` 五类字段，**除 `xargs` 外没有其它运行时参数入口**。  
- CLI `-x` 会与 `luban.conf` 的 `xargs` 合并，且同名键由 CLI 覆盖。  
```242:273:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban\Program.cs
private static Dictionary<string, string> ParseXargs(IEnumerable<string> defaultXargs, IEnumerable<string> cmdXargs)
{
    var defaultXargsMap = ParseXargs0(defaultXargs);
    var cmdXargsMap = ParseXargs0(cmdXargs);
    foreach (var kv in cmdXargsMap)
    {
        defaultXargsMap[kv.Key] = kv.Value;
    }
    return defaultXargsMap;
}
```
- 也就是说，**所有可选配置项只有两个来源**：  
  - `luban.conf` 的 `xargs`  
  - CLI `-x`（脚本中硬编码的 `-x` 也属于这一类）

### 3.2 命名空间覆盖规则
`EnvManager` 支持“命名空间优先 + 全局回退”：  
```50:79:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban.Core\EnvManager.cs
string fullOptionName = string.IsNullOrEmpty(namespaze) ? name : namespaze + "." + name;
if (_options.TryGetValue(fullOptionName, out value)) { return true; }
...
// 找不到时退回到全局 name
```
**结论**：  
- `{target}.outputDataDir` 优先于 `{dataTarget}.outputDataDir` 与全局 `outputDataDir`  
- `{target}.outputCodeDir` 优先于 `{codeTarget}.outputCodeDir` 与全局 `outputCodeDir`  
- `{dataTarget}.outputDataDir` / `{dataTarget}.fileExt` 会优先于全局 `outputDataDir` / `fileExt`  
- `{codeTarget}.outputCodeDir` 会优先于全局 `outputCodeDir`  
- CLI `-x` 覆盖 `luban.conf` 的 `xargs`

### 3.3 输出相关配置“在哪里写”
下面这些配置**只能写在 `xargs` 或 CLI `-x`**，`luban.conf` 本体没有直接字段：
- `outputDataDir`（全局数据输出目录）  
  - 写法：`-x outputDataDir=...` 或 `xargs: ["outputDataDir=../../TestOutputs/json"]`
- `{dataTarget}.outputDataDir`（按 dataTarget 的数据输出目录）  
  - `{dataTarget}` 对应 `-d` 传入的名字，例如 `json`/`bin`  
  - 写法：`-x json.outputDataDir=...`
- `outputCodeDir` / `{codeTarget}.outputCodeDir`  
  - `{codeTarget}` 对应 `-c` 传入的名字，例如 `cs-simple-json`  
  - 写法：`-x cs-simple-json.outputCodeDir=...`

> **没有 `{target}.outputDataDir` 这回事。** 输出目录的命名空间取自
> dataTarget / codeTarget，而非 `luban.conf` 里 `targets.name` 的那个 target。
> `client.outputDataDir` 这类写法不生效也不报错，详见
> `docs/reference/luban_config_reference.md` 1.2 节。
- `fileExt` / `{dataTarget}.fileExt`（数据后缀）  
  - 写法：`-x fileExt=...` 或 `-x json.fileExt=...`

### 3.4 与表输出文件名的关系
`B1` 元数据里的 `output` **只影响输出文件名/相对路径**，不会覆盖输出目录：  
```87:88:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban.Core\Defs\DefTable.cs
public string OutputDataFile => string.IsNullOrWhiteSpace(_outputFile) ? FullName.Replace('.', '_').ToLower() : _outputFile;
```
最终文件位置 = `resolvedOutputDataDir` + `OutputDataFile` + `fileExt`
（`resolvedOutputDataDir` 按 `{target}.outputDataDir` → `{dataTarget}.outputDataDir` → `outputDataDir` 解析）

## 4. Schema 收集（DefaultSchemaCollector）

收集顺序：  
- `schemaFiles`（xml / xlsx / csv 等，取决于类型）  
- 同文件内联 `__enums__` / `__beans__` 子表（自动扫描）  
- `tableImporter` 自动生成表  
```39:168:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban.Schema.Builtin\DefaultSchemaCollector.cs
foreach (var importFile in _config.Imports)
{
    var schemaLoader = SchemaManager.Ins.CreateSchemaLoader(ext, importFile.Type, this);
    schemaLoader.Load(importFile.FileName);
}
LoadInlineSchemasFromDataFiles();
LoadTablesFromTableImporter();
```

内联枚举/Bean 子表扫描规则：  
- 遍历 `dataDir` 下的 Excel（排除 `__tables__/__beans__/__enums__` 及 `Defines`）  
- 只识别 sheet 名 `__enums__` / `__beans__`  
```119:160:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban.Schema.Builtin\DefaultSchemaCollector.cs
if (!FileUtil.IsExcelFile(file) || file.EndsWith(".csv", ...)) { continue; }
...
if (fileName.Equals("__tables__", ...) || fileName.Equals("__beans__", ...) || fileName.Equals("__enums__", ...)) { continue; }
...
string inlinePath = FileUtil.Standardize($"{sheetName}@{fullFile}");
```

## 5. 表定义入口与自包含表元数据

### 5.1 表扫描入口（DefaultTableImporter）
- `tableImporter.scanPath` 支持**绝对路径或相对 `dataDir`**  
```79:95:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban.Schema.Builtin\DefaultTableImporter.cs
string fullScanPath = Path.IsPathRooted(scanPath) ? scanPath : Path.Combine(dataDir, scanPath);
```

### 5.2 A1/B1 规则（SheetLoadUtil）
- A1 必须以 `##export` 开头，支持 `##export=false`  
- B1 存放表元数据（本项目已替代 `__tables__.xlsx`）  
```488:522:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban.DataLoader.Builtin\Excel\SheetLoadUtil.cs
string exportTag = reader.GetValue(0)?.ToString()?.Trim();
if (string.IsNullOrWhiteSpace(exportTag) || !exportTag.StartsWith("##export", ...)) { return false; }
export = ParseExportFlag(exportTag);
tableMeta = reader.FieldCount > 1 ? reader.GetValue(1)?.ToString()?.Trim() ?? "" : "";
```

### 5.3 B1 元数据解析（DefaultTableImporter）
关键字段：`full_name` / `value_type` / `index` / `mode` / `group` / `comment` / `read_schema_from_file` / `input` / `output` / `tags`  
```128:166:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban.Schema.Builtin\DefaultTableImporter.cs
string fullName = GetRequiredMeta(meta, "full_name", location);
string valueType = GetRequiredMeta(meta, "value_type", location);
string output = GetMeta(meta, "output");
bool readSchemaFromFile = ParseBoolMeta(meta, "read_schema_from_file", true, location);
if (string.IsNullOrWhiteSpace(input)) { input = $"{rawSheet.SheetName}@{relativePath}"; }
```

## 6. 数据加载链路

### 6.1 Pipeline 入口
```52:139:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban.Core\Pipeline\DefaultPipeline.cs
LoadSchema();
PrepareGenerationContext();
ProcessTargets();
...
if (_args.ForceLoadTableDatas || _args.DataTargets.Count > 0) { LoadDatas(); }
```

### 6.2 DataLoaderManager
```45:99:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban.Core\DataLoader\DataLoaderManager.cs
foreach (var inputFile in table.InputFiles)
{
    var (actualFile, subAssetName) = FileUtil.SplitFileAndSheetName(...);
    foreach (var atomFile in FileUtil.GetFileOrDirectory(inputDataDir, Path.Combine(inputDataDir, actualFile)))
    {
        tasks.Add(Task.Run(() => LoadTableFile(table, atomFile, subAssetName, options)));
    }
}
```

## 7. 校验链路与失败策略

校验入口：  
```93:98:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban.Core\Pipeline\DefaultPipeline.cs
var v = new DataValidatorContext(_defAssembly);
v.ValidateTables(_genCtx.Tables);
```

校验失败标记：  
```39:45:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban.DataValidator.Builtin\Misc\NotDefaultValueValidator.cs
s_logger.Error("记录 {}:{} (来自文件:{}) 是一个默认值", ...);
GenerationContext.Current.LogValidatorFail(this);
```

如启用 `--validationFailAsError`，会在主流程结束后触发退出码：  
```145:151:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban\Program.cs
if (exitOnError && opts.ValidationFailAsError && GenerationContext.Current.AnyValidatorFail)
{
    s_logger.Error("encounter some validation failure. exit code: 1");
    Environment.Exit(1);
}
```

### 7.1 批量导表错误不中断（当前策略）
为保证批量导表不中断，单文件错误会被记录日志并跳过：
- 表定义扫描（`DefaultTableImporter`）  
```35:77:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban.Schema.Builtin\DefaultTableImporter.cs
try
{
    ...
}
catch (Exception e)
{
    s_logger.Error(e, "import table failed. file:{}", relativePath);
}
```
- 数据加载（`DataLoaderManager`）  
```69:127:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban.Core\DataLoader\DataLoaderManager.cs
catch (DataCreateException e)
{
    ... // 记录详细信息
    return new List<Record>();
}
catch (Exception e)
{
    s_logger.Error(e, "LoadTableFile fail. table:{} file:{}", table.FullName, file);
    return new List<Record>();
}
```

## 8. 输出目录与文件命名规则

### 8.1 输出目录取值
```29:35:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban.Core\OutputSaver\OutputSaverBase.cs
string optionName = manifest.OutputType == OutputType.Code ? BuiltinOptionNames.OutputCodeDir : BuiltinOptionNames.OutputDataDir;
return EnvManager.Current.GetOption($"{manifest.TargetName}", optionName, true);
```

**结论**：  
- `{target}.outputDataDir` 优先于 `{dataTarget}.outputDataDir` 与全局 `outputDataDir`  
- `{dataTarget}.outputDataDir` 优先于全局 `outputDataDir`  
- `{codeTarget}.outputCodeDir` 优先于全局 `outputCodeDir`  
- CLI `-x` 覆盖配置 `xargs`

### 8.2 输出文件名
```87:88:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\luban\src\Luban.Core\Defs\DefTable.cs
public string OutputDataFile => string.IsNullOrWhiteSpace(_outputFile) ? FullName.Replace('.', '_').ToLower() : _outputFile;
```

`B1` 的 `output` 可以覆盖默认文件名。

### 8.3 配置位置回指
- `outputDataDir` / `{target}.outputDataDir` / `{dataTarget}.outputDataDir`：只能在 `xargs` 或 CLI `-x` 设置  
- `outputCodeDir` / `cs.outputCodeDir`：只能在 `xargs` 或 CLI `-x` 设置  
- `fileExt` / `json.fileExt`：只能在 `xargs` 或 CLI `-x` 设置  

## 9. 关键脚本链路

### 9.1 `Tools/Luban/gen.bat` 与 `check.bat`
- 如果未提供 `--conf`，自动注入 `Tools/Luban/luban.conf`  
```4:12:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\Tools\Luban\gen.bat
echo %* | findstr /i /c:"--conf" >nul
if %errorlevel%==0 ( dotnet "%LUBAN_DLL%" %* ) else ( dotnet "%LUBAN_DLL%" --conf "%CONF_FILE%" %* )
```

### 9.2 `esyluban/scripts/test/run_full_tests_example.bat`
- 用于**内部覆盖测试**，不属于正式项目必备脚本  
- 生成带 L10N 与不带 L10N 两套输出  
- 负例仅记录日志（不中断）  
```22:49:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\scripts\run_full_tests_example.bat
dotnet "%LUBAN_DLL%" ... -x outputDataDir="%OUTPUT_DIR%"
dotnet "%LUBAN_DLL%" ... -x outputDataDir="%OUTPUT_DIR_NO_L10N%"
...
dotnet "%LUBAN_DLL%" ... -x outputDataDir="%NEGATIVE_OUTPUT_DIR%" -x tableImporter.scanPath="%NEGATIVE_DIR%" > "%NEGATIVE_LOG%" 2>&1
```

### 9.3 右键菜单入口（全局）
两个入口脚本：  
- `scripts/run_luban_context_menu_data.bat`（导数据：`client/server/editor`）  
- `scripts/run_luban_context_menu_code.bat`（生成代码：`client + cs-simple-json`）  

共同特性：  
- 向上 5 层定位 `Tools/Luban/luban.conf`  
- 其余参数来自 `luban.conf`  

支持配置化（写在 `luban.conf`）：  
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

数据入口片段（仅数据入口覆盖 `tableImporter.scanPath`）：
```26:42:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\scripts\run_luban_context_menu_data.bat
set DATA_TARGETS=client server editor
for %%t in (%DATA_TARGETS%) do (
  call "%GEN_BAT%" -t %%t -d json -x tableImporter.scanPath="%SCAN_PATH%"
)
```

代码入口片段：
```28:34:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\scripts\run_luban_context_menu_code.bat
set CODE_TARGET=cs-simple-json
set TARGET_NAME=client
call "%GEN_BAT%" -t %TARGET_NAME% -c %CODE_TARGET%
```

### 9.4 右键菜单安装/卸载
安装脚本把入口复制到 `%ProgramData%` 并写 HKLM：  
```6:48:C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\Tools\Luban\install_luban_context_menu.bat
set SCRIPT_DATA=%GLOBAL_DIR%\run_luban_context_menu_data.bat
set SCRIPT_CODE=%GLOBAL_DIR%\run_luban_context_menu_code.bat
...
reg add "HKLM\Software\Classes\Directory\shell\LubanExportData" ...
reg add "HKLM\Software\Classes\Directory\shell\LubanExportCode" ...
```

## 10. 项目集成修改量（现状结论）

**最少必改（1 个）**  
- `Tools/Luban/luban.conf`：`dataDir` / `schemaFiles` / `targets`

**常见额外改动（1~2 个）**  
- 导出目录差异：通过 `luban.conf` 的 `xargs` 统一配置  
- 右键菜单在目录结构不固定时，需要调整脚本的路径拼接逻辑

**推荐阅读**  
- 覆盖矩阵：`docs/coverage_matrix.md`

**根因总结**  
- right-click 是跨项目通用的，但当前脚本假设 `DataTables` 在 `PROJECT_ROOT` 下  
- 真实项目中“Tools/Luban 与 DataTables 相对关系不固定”，会导致右键菜单路径推断失效
