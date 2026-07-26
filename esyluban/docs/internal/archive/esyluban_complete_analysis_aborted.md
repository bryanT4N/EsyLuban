# EsyLuban 完整优化方案：深度技术分析报告

> **版本**: v2.0（完整版）  
> **分析深度**: 源码级  
> **覆盖范围**: 所有优化需求  
> **创建日期**: 2026-01-22

---

## 目录

1. [优化需求总览](#一优化需求总览)
2. [B1格式设计深度分析](#二b1格式设计深度分析)
3. [自包含表定义实现方案](#三自包含表定义实现方案)
4. [目录结构调整分析](#四目录结构调整分析)
5. [部分导出功能实现](#五部分导出功能实现)
6. [右键菜单集成方案](#六右键菜单集成方案)
7. [完整测试策略](#七完整测试策略)
8. [实施计划](#八实施计划)
9. [风险评估](#九风险评估)

---

## 一、优化需求总览

### 1.1 核心问题

**Luban 现状痛点**：

1. **表定义分散**：__tables__.xlsx + 数据文件，两处维护
2. **目录冗余**：DataTables/Datas 双层结构，配置文件混在数据中
3. **导出全量慢**：修改一个表需要重新生成所有表，大项目耗时数分钟
4. **交互不便**：需要手动进入 Projects/xxx/ 运行 gen.bat

---

### 1.2 优化目标

| 优化点 | 现状 | 目标 | 技术挑战 |
|--------|------|------|---------|
| **1. 自包含表定义** | __tables__.xlsx + Excel数据文件 | Excel 自包含（A1+B1） | B1格式设计、解析器开发 |
| **2. 目录结构简化** | DataTables/Datas/ | DataTables/ | 路径解析调整、配置迁移 |
| **3. 部分导出** | 全量导出（60秒） | 单表导出（3秒） | 文件过滤、增量生成 |
| **4. 右键菜单** | 命令行运行 | 右键快速导出 | 注册表、路径查找 |

---

## 二、B1格式设计深度分析

### 2.1 用户建议格式分析

**用户建议**：`字段1="值1",字段2="值2",字段3="值3"`

#### 2.1.1 分隔符冲突分析

**已使用分隔符汇总**（源码分析结果）：

| 分隔符 | 用途 | 源码位置 | 示例 |
|--------|------|---------|------|
| `,` | **group: 多组分隔** | SchemaLoaderUtil.CreateGroups | `c,s,e` |
| `,` | **tags 内部（可能）** | DefUtil.ParseListOrMultilineString | `item,monster` |
| `,` | **多个 index 字段** | DefTable.cs:139 | `id+level,type` |
| `"` | **JSON 字符串** | - | 值可能包含引号 |
| `=` | **tags: 键值分隔** | DefUtil.ParseAttrs | `priority=high` |
| `#` | **tags: 键值对分隔** | DefUtil.ParseAttrs | `k1=v1#k2=v2` |

**关键发现**：

✅ **逗号 `,` 在多处使用**：
- group 字段：`c,s,e`
- tags 字段（潜在）
- index 字段（多键）

❌ **问题**：如果用 `,` 作为顶层分隔符，会与字段值内部的 `,` 冲突！

---

#### 2.1.2 冲突场景模拟

**场景 1：group 字段包含逗号**

```
full_name="TbItem",value_type="Item",group="c,s,e"
                                             ↑↑↑
                                        内部逗号！
```

**解析问题**：

```csharp
// 按 , 分割
parts = Split(',')
→ ["full_name=\"TbItem\"", "value_type=\"Item\"", "group=\"c", "s", "e\""]
                                                        ↑      ↑    ↑
                                                    错误分割！
```

---

**场景 2：comment 字段包含逗号**

```
full_name="TbItem",comment="道具表,包含所有道具"
                                  ↑
                              内部逗号！
```

**解析问题**：同样会被错误分割。

---

#### 2.1.3 引号转义问题

**值包含引号**：

```
comment="这是一个\"特殊\"注释"
                  ↑↑    ↑↑
              需要转义！
```

**解析复杂度**：需要处理转义，增加解析复杂度。

---

### 2.2 修正方案：逗号+引号格式的改进

#### 方案 A：支持转义的逗号分割

**格式**：

```
full_name="item.TbItem",value_type="Item",mode="map",group="c,s",comment="道具表"
```

**解析算法**：

```csharp
public static Dictionary<string, string> ParseB1WithQuotes(string b1Content)
{
    var result = new Dictionary<string, string>();
    var buffer = new StringBuilder();
    bool inQuote = false;
    bool inEscape = false;
    
    for (int i = 0; i < b1Content.Length; i++)
    {
        char c = b1Content[i];
        
        // 处理转义
        if (inEscape)
        {
            buffer.Append(c);
            inEscape = false;
            continue;
        }
        
        if (c == '\\')
        {
            inEscape = true;
            continue;
        }
        
        // 处理引号
        if (c == '"')
        {
            inQuote = !inQuote;
            continue;  // 不保存引号本身
        }
        
        // 处理逗号（仅在引号外部才是分隔符）
        if (!inQuote && c == ',')
        {
            ParseKeyValue(result, buffer.ToString());
            buffer.Clear();
        }
        else
        {
            buffer.Append(c);
        }
    }
    
    // 处理最后一个字段
    if (buffer.Length > 0)
    {
        ParseKeyValue(result, buffer.ToString());
    }
    
    return result;
}

private static void ParseKeyValue(Dictionary<string, string> dict, string pair)
{
    var parts = pair.Split(new[] { '=' }, 2);
    if (parts.Length != 2)
        throw new Exception($"Invalid format: {pair}");
    
    string key = parts[0].Trim();
    string value = parts[1].Trim();
    
    dict[key] = value;
}
```

**优点**：
- ✅ 直观易懂
- ✅ 类似 JSON，策划熟悉

**缺点**：
- ❌ group="c,s" 内部的逗号仍然存在歧义
- ❌ 解析复杂（状态机）
- ❌ 错误定位困难

---

#### 方案 B：推荐方案（使用不冲突的分隔符）

**格式**：

```
full_name="item.TbItem" & value_type="Item" & mode="map" & group="c,s" & comment="道具表"
```

**分隔符**：
- **字段间分隔**：` & `（两端空格，视觉清晰）
- **键值分隔**：`=`
- **值包裹**：`""`

**解析算法**：

```csharp
public static Dictionary<string, string> ParseB1Metadata(string b1Content)
{
    var result = new Dictionary<string, string>();
    
    // 1. 按 " & " 分割字段（注意空格）
    var fields = SplitByDelimiterWithQuotes(b1Content, " & ");
    
    foreach (var field in fields)
    {
        if (string.IsNullOrWhiteSpace(field)) continue;
        
        // 2. 按 = 分割键值对
        var eqIndex = field.IndexOf('=');
        if (eqIndex < 0)
            throw new Exception($"Missing '=' in field: {field}");
        
        string key = field.Substring(0, eqIndex).Trim();
        string value = field.Substring(eqIndex + 1).Trim();
        
        // 3. 去除值两端的引号
        if (value.StartsWith("\"") && value.EndsWith("\""))
        {
            value = value.Substring(1, value.Length - 2);
            // 处理转义的引号
            value = value.Replace("\\\"", "\"");
        }
        
        result[key] = value;
    }
    
    return result;
}

private static string[] SplitByDelimiterWithQuotes(string content, string delimiter)
{
    var result = new List<string>();
    var buffer = new StringBuilder();
    bool inQuote = false;
    
    for (int i = 0; i < content.Length; i++)
    {
        char c = content[i];
        
        // 检查引号
        if (c == '"' && (i == 0 || content[i-1] != '\\'))
        {
            inQuote = !inQuote;
        }
        
        // 检查分隔符（仅在引号外）
        if (!inQuote && StartsWithDelimiter(content, i, delimiter))
        {
            result.Add(buffer.ToString());
            buffer.Clear();
            i += delimiter.Length - 1;  // 跳过分隔符
            continue;
        }
        
        buffer.Append(c);
    }
    
    if (buffer.Length > 0)
    {
        result.Add(buffer.ToString());
    }
    
    return result.ToArray();
}
```

**优点**：
- ✅ ` & ` 不与现有分隔符冲突
- ✅ 视觉清晰（空格分隔）
- ✅ 支持所有字段值（包含逗号、引号等）
- ✅ 解析相对简单

**缺点**：
- ⚠️ 比逗号稍长（但更安全）

---

### 2.3 完整字段映射表（基于源码）

| 键名 | 对应字段 | 类型 | 必填 | 默认值 | 示例值 |
|------|---------|------|------|--------|--------|
| `full_name` | Namespace+Name | string | ✅ | - | `"item.TbItem"` |
| `value_type` | ValueType | string | ✅ | - | `"Item"` |
| `input` | InputFiles | string | ❌ | **当前文件@当前Sheet** | `"item/other.xlsx"` |
| `mode` | Mode | string | ❌ | `"map"` | `"list"` |
| `read_schema_from_file` | ReadSchemaFromFile | bool | ❌ | `"1"` | `"0"` |
| `index` | Index | string | ❌ | `"id"` | `"item_id"` |
| `comment` | Comment | string | ❌ | `""` | `"道具配置表"` |
| `group` | Groups | string | ❌ | `""` | `"c,s"` |
| `tags` | Tags | string | ❌ | `""` | `"priority=high#category=core"` |
| `output` | OutputFile | string | ❌ | `""` | `"tbitem.bytes"` |

**重要变更**：

- ✅ **input 字段改为可选**（原为必填）
- ✅ **默认值**：自动计算为 `当前文件路径@当前SheetName`
- ✅ **仅在需要引用其他文件时才需要填写 input**

**计算逻辑**：

```csharp
// 如果 B1 未指定 input
if (!metadata.ContainsKey("input"))
{
    // 自动推导
    string currentFile = GetRelativePathToDataDir(excelFilePath);  // "item/items.xlsx"
    string currentSheet = sheet.SheetName;                          // "Sheet1"
    
    table.InputFiles = new List<string> { $"{currentFile}@{currentSheet}" };
}
```

---

### 2.4 多 Sheet 场景示例 ⭐（重要）

**场景**：一个 Excel 文件包含多个表（用户会大量使用此场景）

**items.xlsx 结构**：

```
items.xlsx
├── Sheet1: 道具表
├── Sheet2: 道具升级表
└── Sheet3: 道具品质表
```

**Sheet1 配置**：

| A1 | B1 |
|----|-----|
| `##export` | `full_name="item.TbItem" & value_type="Item"` |
| `##var` | `id`, `name`, `icon` |
| `##type` | `int`, `string`, `string` |

**Sheet2 配置**：

| A1 | B1 |
|----|-----|
| `##export` | `full_name="item.TbItemUpgrade" & value_type="ItemUpgrade"` |
| `##var` | `level`, `cost` |
| `##type` | `int`, `int` |

**Sheet3 配置**：

| A1 | B1 |
|----|-----|
| `##export` | `full_name="item.TbItemQuality" & value_type="ItemQuality"` |
| `##var` | `quality`, `color` |
| `##type` | `int`, `string` |

**生成结果**：

```csharp
// 自动生成 3 个表
public class Tables
{
    public item.TbItem TbItem { get; }               // input: items.xlsx@Sheet1
    public item.TbItemUpgrade TbItemUpgrade { get; } // input: items.xlsx@Sheet2
    public item.TbItemQuality TbItemQuality { get; } // input: items.xlsx@Sheet3
}
```

**优点**：

- ✅ 相关表集中在一个文件中
- ✅ 无需填写 input 字段
- ✅ 减少文件数量
- ✅ 便于整体管理

---

### 2.5 B1格式最终推荐

**推荐格式**（常用场景 - 自包含）：

```
full_name="item.TbItem" & value_type="Item" & mode="map" & read_schema_from_file="1" & comment="道具配置表"
```

**最小格式**（仅必填字段）：

```
full_name="TbItem" & value_type="Item"
```

**⚠️ 注意**：不需要填写 `input` 字段！默认就是当前 Sheet。

---

**带复杂值的示例**：

```
full_name="item.TbItem" & value_type="Item" & comment="这是一个包含,逗号和\"引号\"的注释" & group="c,s" & tags="priority=high#desc=测试#author=策划A"
```

---

**需要引用其他文件时**（少见）：

```
full_name="TbItemRef" & value_type="ItemRef" & input="item/other_file.xlsx@Data"
```

**说明**：仅当数据在其他文件时才需要填写 `input`。

---

## 三、自包含表定义实现方案

### 3.1 新的 Excel 格式

#### 格式规范

| 单元格 | 内容 | 说明 |
|--------|------|------|
| A1 | `##export` | 导出控制标记 |
| B1 | 表元数据（B1格式） | 完整的表定义 |
| A2 | `##var` | 变量名行（原A1下移） |
| B2 | `id` | 字段名 |
| A3 | `##type` | 类型行（原A2下移） |
| B3 | `int` | 字段类型 |

#### 完整示例

```
A1: ##export
B1: full_name="item.TbItem" & value_type="Item" & input="item/items.xlsx" & mode="map" & read_schema_from_file="1"

A2: ##var
B2: id
C2: name
D2: icon

A3: ##type
B3: int
C3: string
D3: string

A4: ##
B4: ID
C4: 名称
D4: 图标

A5: (空)
B5: 1001
C5: 金币
D5: icon_gold
```

---

### 3.2 SchemaLoader 实现

#### 3.2.1 新的 Loader 类

**文件**：`Luban.Schema.Builtin/SelfContainedExcelSchemaLoader.cs`

```csharp
[SchemaLoader("selfcontained", new[] { ".xlsx", ".xls" }, Priority = 100)]
public class SelfContainedExcelSchemaLoader : ISchemaLoader
{
    public void Load(string fileName)
    {
        var (actualFile, sheetName) = FileUtil.SplitFileAndSheetName(fileName);
        
        using var stream = new FileStream(actualFile, FileMode.Open, FileAccess.Read);
        var workbook = WorkbookFactory.Create(stream);
        
        // 遍历所有 Sheet
        for (int i = 0; i < workbook.NumberOfSheets; i++)
        {
            var sheet = workbook.GetSheetAt(i);
            
            // 读取 A1
            var a1Cell = sheet.GetRow(0)?.GetCell(0);
            string a1Value = a1Cell?.StringCellValue?.Trim() ?? "";
            
            if (a1Value != "##export")
            {
                // 跳过非导出 Sheet
                continue;
            }
            
            // 读取 B1
            var b1Cell = sheet.GetRow(0)?.GetCell(1);
            string b1Value = b1Cell?.StringCellValue?.Trim() ?? "";
            
            if (string.IsNullOrEmpty(b1Value))
            {
                throw new Exception($"Sheet '{sheet.SheetName}' has ##export but B1 is empty!");
            }
            
            // 解析 B1
            var metadata = ParseB1Metadata(b1Value);
            
            // 创建 RawTable
            var table = CreateTableFromMetadata(metadata, fileName, sheet.SheetName);
            
            Collector.Add(table);
        }
    }
    
    private Dictionary<string, string> ParseB1Metadata(string b1Content)
    {
        // 实现前面的解析逻辑
        // ...
    }
    
    private RawTable CreateTableFromMetadata(Dictionary<string, string> meta, string fileName, string sheetName)
    {
        // 提取必填字段
        string fullName = GetRequired(meta, "full_name");
        string valueType = GetRequired(meta, "value_type");
        
        // input 字段：如果未指定，默认为当前 Sheet
        string input;
        if (meta.ContainsKey("input"))
        {
            input = meta["input"];
        }
        else
        {
            // 计算相对路径（相对于 dataDir）
            string relativePath = GetRelativePathToDataDir(fileName);
            input = $"{relativePath}@{sheetName}";
        }
        
        return new RawTable
        {
            Namespace = TypeUtil.GetNamespace(fullName),
            Name = TypeUtil.GetName(fullName),
            ValueType = valueType,
            InputFiles = new List<string> { input },
            Mode = ParseMode(GetOptional(meta, "mode", "map")),
            ReadSchemaFromFile = ParseBool(GetOptional(meta, "read_schema_from_file", "1")),
            Index = GetOptional(meta, "index", "id"),
            Comment = GetOptional(meta, "comment", ""),
            Groups = ParseGroups(GetOptional(meta, "group", "")),
            Tags = ParseTags(GetOptional(meta, "tags", "")),
            OutputFile = GetOptional(meta, "output", ""),
        };
    }
    
    private string GetRelativePathToDataDir(string absolutePath)
    {
        // 计算相对于 dataDir 的路径
        string dataDir = Context.DataDir;  // 从配置获取
        
        if (absolutePath.StartsWith(dataDir))
        {
            string relative = absolutePath.Substring(dataDir.Length)
                .TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            return relative.Replace('\\', '/');  // 统一使用 /
        }
        
        return Path.GetFileName(absolutePath);  // 降级方案
    }
}
```

---

### 3.3 注册和优先级

**SchemaManager 注册**：

```csharp
// 优先级：SelfContainedExcelSchemaLoader (100) > ExcelSchemaLoader (0)
[SchemaLoader("selfcontained", new[] { ".xlsx" }, Priority = 100)]
```

**选择逻辑**（基于 A1 判断）：

```csharp
// 在 SelfContainedExcelSchemaLoader.Load 中
if (a1Value == "##export")
{
    // 使用新格式
    ProcessSelfContainedSheet(sheet);
}
else
{
    // 跳过（由旧 Loader 处理，或忽略）
    continue;
}
```

---

## 四、目录结构调整分析

### 4.1 新旧结构对比

**旧结构**：

```
ProjectRoot/
├── DataTables/
│   ├── luban.conf          ← 配置文件
│   ├── check.bat
│   ├── Defines/
│   └── Datas/              ← 冗余层级
│       ├── __tables__.xlsx
│       └── item/
└── Projects/
    └── Csharp_Unity_bin/
        └── gen.bat         ← 分散的脚本
```

**新结构**：

```
ProjectRoot/
├── Tools/
│   └── Luban/
│       ├── Luban.dll
│       ├── luban.conf      ← 集中配置
│       ├── gen.bat         ← 统一脚本
│       └── check.bat
├── DataTables/             ← 扁平化
│   ├── __Defines__/
│   ├── item/
│   └── test/
└── Projects/
```

---

### 4.2 路径影响分析

#### 4.2.1 luban.conf 路径调整

**源码**：`GlobalConfigLoader.cs:93`

```csharp
var dataInputDir = Path.Combine(_curDir, globalConf.DataDir);
```

**旧配置**：

```json
{
    "schemaFiles": [
        {"fileName": "Defines", "type": ""},
        {"fileName": "Datas/__tables__.xlsx", "type": "table"}
    ],
    "dataDir": "Datas"
}
```

**新配置**（luban.conf 在 Tools/Luban/）：

```json
{
    "schemaFiles": [
        {"fileName": "../../DataTables/__Defines__", "type": ""},
        {"fileName": "../../DataTables/__tables__.xlsx", "type": "table"}
    ],
    "dataDir": "../../DataTables"
}
```

**计算**：

```
_curDir = Tools/Luban/
dataInputDir = Tools/Luban/ + ../../DataTables = DataTables/
schemaFiles = Tools/Luban/ + ../../DataTables/__Defines__ = DataTables/__Defines__/
```

✅ **路径正确**

---

#### 4.2.2 gen.bat 调整

**旧 gen.bat**（位于 Projects/Csharp_Unity_bin/）：

```batch
set WORKSPACE=..\..
set LUBAN_DLL=%WORKSPACE%\Tools\Luban\Luban.dll
set CONF_ROOT=%WORKSPACE%\DataTables

dotnet %LUBAN_DLL% --conf %CONF_ROOT%\luban.conf
```

**新 gen.bat**（位于 Tools/Luban/）：

```batch
set LUBAN_DLL=%~dp0Luban.dll
set CONF=%~dp0luban.conf

dotnet %LUBAN_DLL% --conf %CONF% ^
    -x outputCodeDir=../../Projects/Csharp_Unity_bin/Assets/Gen ^
    -x outputDataDir=../../Projects/GenerateDatas/bytes
```

---

### 4.3 迁移脚本

**文件**：`Tools/Luban/migrate_structure.bat`

```batch
@echo off
echo Migrating to new structure...

:: 备份
xcopy /E /I ..\..\ ..\..\backup_%date:~0,10%\

:: 移动 luban.conf
move ..\..\DataTables\luban.conf .\luban.conf

:: 移动 check.bat
move ..\..\DataTables\check.bat .\check.bat

:: 移动 Datas 内容到 DataTables
xcopy /E /I ..\..\DataTables\Datas\* ..\..\DataTables\
rmdir /S /Q ..\..\DataTables\Datas

:: 重命名 Defines
ren ..\..\DataTables\Defines __Defines__

echo Migration complete!
pause
```

---

## 五、部分导出功能实现

### 5.1 需求分析

**场景**：  
- 修改 `item/items.xlsx` 后，只想导出这个表
- 修改 `item/` 目录下所有表，只想导出 item 模块

**现状**：  
- 全量导出所有表（100个表 = 60秒）

**目标**：  
- 部分导出（1个表 = 3秒）

---

### 5.2 命令行参数设计

**新增参数**：

```batch
# 导出单个文件
-x exportFiles=item/items.xlsx

# 导出多个文件
-x exportFiles=item/items.xlsx,item/upgrades.xlsx

# 导出目录下所有文件
-x exportDir=item

#导出目录下所有文件（递归）
-x exportDir=item -x recursive=true
```

---

### 5.3 实现方案

#### 5.3.1 文件发现修改

**源码**：`DefaultSchemaCollector.cs`（需要修改）

**原逻辑**：

```csharp
// 扫描所有 Excel 文件
var allFiles = Directory.GetFiles(dataDir, "*.xlsx", SearchOption.AllDirectories);
foreach (var file in allFiles)
{
    LoadExcel(file);
}
```

**新逻辑**：

```csharp
public void Collect()
{
    // 检查是否有部分导出参数
    string exportFiles = GetXarg("exportFiles");
    string exportDir = GetXarg("exportDir");
    
    if (!string.IsNullOrEmpty(exportFiles))
    {
        // 只加载指定文件
        var files = exportFiles.Split(',');
        foreach (var file in files)
        {
            string fullPath = Path.Combine(dataDir, file.Trim());
            LoadExcel(fullPath);
        }
    }
    else if (!string.IsNullOrEmpty(exportDir))
    {
        // 只加载指定目录
        string dirPath = Path.Combine(dataDir, exportDir);
        bool recursive = GetXarg("recursive") == "true";
        var searchOption = recursive ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly;
        
        var files = Directory.GetFiles(dirPath, "*.xlsx", searchOption);
        foreach (var file in files)
        {
            if (ShouldSkipFile(file)) continue;
            LoadExcel(file);
        }
    }
    else
    {
        // 全量扫描（原逻辑）
        var files = Directory.GetFiles(dataDir, "*.xlsx", SearchOption.AllDirectories);
        foreach (var file in files)
        {
            if (ShouldSkipFile(file)) continue;
            LoadExcel(file);
        }
    }
}

private bool ShouldSkipFile(string filePath)
{
    string fileName = Path.GetFileName(filePath).ToLower();
    string[] excludedFiles = { "__tables__.xlsx", "__beans__.xlsx", "__enums__.xlsx" };
    return excludedFiles.Contains(fileName);
}
```

---

### 5.4 增量生成（可选优化）

**原理**：比较文件 hash，跳过未修改的表

```csharp
private Dictionary<string, string> _fileHashes = new();

private bool ShouldRegenerate(string filePath)
{
    string currentHash = ComputeFileHash(filePath);
    
    if (_fileHashes.TryGetValue(filePath, out var oldHash))
    {
        return currentHash != oldHash;
    }
    
    return true;  // 首次生成
}
```

---

## 六、右键菜单集成方案

### 6.1 Windows 注册表方案

#### 6.1.1 注册表位置

**Excel 文件右键**：

```
HKEY_CLASSES_ROOT\Excel.Sheet.12\shell\EsyLuban
```

**文件夹右键**（文件夹内空白处）：

```
HKEY_CLASSES_ROOT\Directory\Background\shell\EsyLubanDir
```

---

#### 6.1.2 install_context_menu.bat

**文件**：`Tools/Luban/install_context_menu.bat`

```batch
@echo off
echo Installing EsyLuban Context Menu...

:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Please run as Administrator!
    pause
    exit /b 1
)

set LUBAN_PATH=%~dp0

:: Excel 文件右键菜单
reg add "HKEY_CLASSES_ROOT\Excel.Sheet.12\shell\EsyLuban" /ve /d "EsyLuban - 导出此表" /f
reg add "HKEY_CLASSES_ROOT\Excel.Sheet.12\shell\EsyLuban\command" /ve /d "\"%LUBAN_PATH%export_wrapper.bat\" \"%%1\"" /f

:: 文件夹右键菜单
reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\EsyLubanDir" /ve /d "EsyLuban - 导出此目录" /f
reg add "HKEY_CLASSES_ROOT\Directory\Background\shell\EsyLubanDir\command" /ve /d "\"%LUBAN_PATH%export_wrapper.bat\" \"%%V\"" /f

echo Context menu installed successfully!
pause
```

---

#### 6.1.3 export_wrapper.bat

**文件**：`Tools/Luban/export_wrapper.bat`

```batch
@echo off
setlocal enabledelayedexpansion

set TARGET=%~1
set LUBAN_ROOT=%~dp0

:: 判断是文件还是目录
if exist "%TARGET%\" (
    :: 目录
    echo Exporting directory: %TARGET%
    call "%LUBAN_ROOT%gen.bat" -x exportDir="%TARGET%"
) else (
    :: 文件
    echo Exporting file: %TARGET%
    
    :: 计算相对路径（相对于 DataTables）
    set "DATATABLES_PATH=%LUBAN_ROOT%..\..\DataTables"
    
    :: 简化：直接传绝对路径（gen.bat 内部处理）
    call "%LUBAN_ROOT%gen.bat" -x exportFiles="%TARGET%"
)

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo Export completed successfully!
    echo ========================================
) else (
    echo.
    echo ========================================
    echo Export FAILED! See errors above.
    echo ========================================
)

pause
```

---

### 6.2 向上查找 Luban 路径（可选优化）

如果不固定路径，可以向上查找：

```batch
:: 向上查找 Tools\Luban（最多3层）
set CURRENT_DIR=%CD%
for /L %%i in (1,1,3) do (
    if exist "!CURRENT_DIR!\Tools\Luban\Luban.dll" (
        set LUBAN_ROOT=!CURRENT_DIR!\Tools\Luban\
        goto :found
    )
    cd ..
    set CURRENT_DIR=!CD!
)

echo ERROR: Cannot find Tools\Luban!
pause
exit /b 1

:found
echo Found Luban at: %LUBAN_ROOT%
```

---

## 七、完整测试策略

### 7.1 单元测试

#### 7.1.1 B1 解析器测试

**文件**：`Luban.Tests/B1ParserTests.cs`

**测试用例**（30+）：

```csharp
[Fact]
public void Test_ParseB1_MinimalFormat()
{
    string b1 = "full_name=\"TbItem\" & value_type=\"Item\" & input=\"items.xlsx\"";
    var result = B1Parser.Parse(b1);
    
    Assert.Equal("TbItem", result["full_name"]);
    Assert.Equal("Item", result["value_type"]);
    Assert.Equal("items.xlsx", result["input"]);
}

[Fact]
public void Test_ParseB1_WithCommaInValue()
{
    string b1 = "full_name=\"TbItem\" & comment=\"道具表,包含所有道具\"";
    var result = B1Parser.Parse(b1);
    
    Assert.Equal("道具表,包含所有道具", result["comment"]);
}

[Fact]
public void Test_ParseB1_WithQuoteInValue()
{
    string b1 = "comment=\"这是一个\\\"特殊\\\"注释\"";
    var result = B1Parser.Parse(b1);
    
    Assert.Equal("这是一个\"特殊\"注释", result["comment"]);
}

[Fact]
public void Test_ParseB1_InvalidFormat_MissingEquals()
{
    string b1 = "full_nameTbItem";
    
    Assert.Throws<Exception>(() => B1Parser.Parse(b1));
}
```

---

### 7.2 集成测试项目

#### 7.2.1 测试项目结构

```
TestProject/
├── Tools/Luban/
├── DataTables/
│   ├── normal/
│   │   └── normal_table.xlsx      # A1=##export, B1=正常格式
│   ├── partial_export/
│   │   └── skip_sheet.xlsx        # A1=（空），应跳过
│   ├── error/
│   │   └── invalid_b1.xlsx        # B1 格式错误
│   └── complex/
│       └── special_chars.xlsx     # 包含特殊字符
```

#### 7.2.2 测试用例清单

| 编号 | 测试内容 | Excel 文件 | 期望结果 |
|------|---------|-----------|---------|
| 1 | 正常导出（新格式） | normal_table.xlsx | ✅ 成功生成 |
| 2 | A1=空（跳过） | skip_sheet.xlsx | ✅ 跳过，无报错 |
| 3 | B1 格式错误 | invalid_b1.xlsx | ❌ 报错并提示 |
| 4 | comment 包含逗号 | special_chars.xlsx | ✅ 正确解析 |
| 5 | 部分导出（单文件） | - | ✅ 只生成指定表 |
| 6 | 部分导出（目录） | - | ✅ 只生成目录下的表 |
| 7 | 右键菜单导出 | - | ✅ 手动测试 |

---

### 7.3 性能测试

**测试场景**：100个表

| 测试 | 操作 | 预期耗时 |
|------|------|---------|
| 全量导出 | 导出所有表 | 60秒 |
| 单表导出 | 导出1个表 | <5秒 |
| 目录导出 | 导出10个表 | <15秒 |

---

## 八、实施计划

### 阶段 1：B1 格式和自包含定义（4周）

#### Week 1-2：B1 解析器

- [ ] 实现 B1 解析器（支持 ` & ` 和引号）
- [ ] 单元测试（30+ 用例）
- [ ] 错误提示优化

#### Week 3-4：SelfContainedExcelSchemaLoader

- [ ] 实现新 SchemaLoader
- [ ] 集成到 SchemaManager
- [ ] 集成测试

---

### 阶段 2：目录结构调整（1周）

#### Week 5：路径调整和迁移

- [ ] 修改 luban.conf 路径引用
- [ ] 修改 gen.bat、check.bat
- [ ] 编写迁移脚本
- [ ] 测试迁移流程

---

### 阶段 3：部分导出（2周）

#### Week 6-7：实现文件过滤

- [ ] 新增 -x exportFiles 参数
- [ ] 新增 -x exportDir 参数
- [ ] 修改文件发现逻辑
- [ ] 性能测试

---

### 阶段 4：右键菜单（1周）

#### Week 8：注册表和包装脚本

- [ ] install_context_menu.bat
- [ ] uninstall_context_menu.bat
- [ ] export_wrapper.bat
- [ ] 手动测试（Windows 10/11）

---

### 阶段 5：测试和文档（1周）

#### Week 9：完整测试

- [ ] 集成测试项目
- [ ] 所有测试用例通过
- [ ] 性能测试
- [ ] 更新文档

---

## 九、风险评估

### 风险 1：B1 单元格长度限制

**风险**：Excel 单元格最多 32,767 字符

**影响**：复杂配置可能超长

**缓解**：
- ✅ 大部分配置 <500 字符
- ✅ 超长时报错提示

---

### 风险 2：引号转义的一致性

**风险**：策划可能忘记转义引号

**影响**：解析失败

**缓解**：
- ✅ 详细错误提示
- ✅ 提供格式校验工具
- ✅ 文档说明

---

### 风险 3：迁移失败

**风险**：迁移脚本可能出错

**影响**：项目无法使用

**缓解**：
- ✅ 迁移前自动备份
- ✅ 提供回滚脚本
- ✅ 充分测试

---

## 十、总结

### 核心设计要点

1. **B1 格式**：使用 ` & ` 和 `"` 分隔，支持所有字段值
2. **自包含定义**：A1=##export, B1=元数据
3. **目录简化**：Tools/Luban 集中配置，DataTables 扁平化
4. **部分导出**：-x exportFiles/exportDir，3秒单表
5. **右键菜单**：注册表 + 包装脚本

### 可行性结论

| 优化点 | 可行性 | 风险等级 | 预计工期 |
|--------|--------|---------|---------|
| B1 格式 | ✅ 高 | 低 | 2周 |
| 自包含定义 | ✅ 高 | 低 | 2周 |
| 目录调整 | ✅ 高 | 低 | 1周 |
| 部分导出 | ✅ 高 | 低 | 2周 |
| 右键菜单 | ✅ 高 | 中 | 1周 |

**总计**: 约 8 周

---

**文档版本**: v2.0（完整版）  
**分析深度**: 源码级  
**可行性**: ✅ 高
