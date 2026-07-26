// Copyright 2025 EZLuban
// Licensed under MIT License

using ExcelDataReader;
using Luban.RawDefs;
using Luban.Utils;
using Luban.Defs;

namespace Luban.Schema.Builtin;

/// <summary>
/// 自包含 Excel Schema Loader
/// 支持从 Excel 的 A1(##export) 和 B1(元数据) 读取表定义
/// </summary>
[SchemaLoader("", new[] { ".xlsx", ".xls", ".xlsm" }, Priority = 100)]
public class SelfContainedExcelSchemaLoader : SchemaLoaderBase
{
    private static readonly NLog.Logger s_logger = NLog.LogManager.GetCurrentClassLogger();

    public override void Load(string fileName)
    {
        (var actualFile, var requestedSheetName) = FileUtil.SplitFileAndSheetName(FileUtil.Standardize(fileName));

        if (!File.Exists(actualFile))
        {
            s_logger.Warn($"File not found: {actualFile}");
            return;
        }

        // schema 定义表本身（__beans__ / __enums__ / __tables__）虽然 A1 也是 ##export，
        // 但它们由 bean/enum schema loader 处理，不是数据表，这里必须跳过，
        // 否则会因 B1 无表元数据而报错。
        if (IsSchemaDefinitionFile(actualFile))
        {
            return;
        }

        using var stream = new FileStream(actualFile, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        // 与上游 SheetLoadUtil 保持同一套 Excel 读取实现（ExcelDataReader），
        // 避免额外引入第三方 Excel 库。注意 reader 是前向只读的：
        // 每张 sheet 只需读第一行即可拿到 A1/B1。
        using var reader = ExcelReaderFactory.CreateReader(stream);

        do
        {
            string sheetName = reader.Name;

            // 如果指定了 Sheet 名，只处理该 Sheet
            if (!string.IsNullOrEmpty(requestedSheetName) && sheetName != requestedSheetName)
            {
                continue;
            }

            // 读首行，取 A1 与 B1
            if (!reader.Read() || reader.FieldCount == 0)
            {
                continue;
            }
            string a1 = reader.GetValue(0)?.ToString()?.Trim() ?? "";
            string b1 = reader.FieldCount > 1 ? reader.GetValue(1)?.ToString()?.Trim() ?? "" : "";

            // A1 恰为 ##export 才是需要导出的自包含表；
            // ##export=false 表示显式关闭导出，这里直接跳过。
            if (a1 != "##export")
            {
                continue;
            }

            try
            {
                var table = ParseSheetMetadata(sheetName, b1, actualFile);
                Collector.Add(table);
                s_logger.Info($"Loaded self-contained table: {table.Name} from {actualFile}@{sheetName}");
            }
            catch (Exception ex)
            {
                s_logger.Error(ex, $"Failed to parse self-contained sheet: {actualFile}@{sheetName}");
                throw;
            }
        } while (reader.NextResult());
    }

    private static readonly HashSet<string> s_schemaDefinitionFileNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "__beans__", "__enums__", "__tables__",
    };

    /// <summary>
    /// 判断是否为 schema 定义表（而非数据表）
    /// </summary>
    internal static bool IsSchemaDefinitionFile(string filePath)
    {
        return s_schemaDefinitionFileNames.Contains(Path.GetFileNameWithoutExtension(filePath));
    }

    /// <summary>
    /// 解析 Sheet 元数据。
    /// SelfContainedTableImporter 复用同一实现，确保两条入口对 B1 的解释完全一致。
    /// </summary>
    internal static RawTable ParseSheetMetadata(string sheetName, string b1Content, string fileName)
    {
        if (string.IsNullOrWhiteSpace(b1Content))
        {
            throw new Exception($"Sheet '{sheetName}' has ##export but B1 is empty!");
        }

        // 使用 B1Parser 解析元数据
        var metadata = B1Parser.Parse(b1Content);

        // 提取必填字段
        string fullName = metadata["full_name"];
        string valueType = metadata["value_type"];

        // 提取命名空间和表名
        string namespaceName = TypeUtil.GetNamespace(fullName);
        string tableName = TypeUtil.GetName(fullName);

        // 处理 input 字段（默认为当前 Sheet）
        string input;
        if (metadata.ContainsKey("input"))
        {
            input = metadata["input"];
        }
        else
        {
            // 计算相对路径
            string relativePath = GetRelativePathToDataDir(fileName);
            input = $"{relativePath}@{sheetName}";
        }

        // 处理 mode
        TableMode mode = TableMode.MAP;  // 默认值
        if (metadata.ContainsKey("mode"))
        {
            mode = ParseMode(metadata["mode"]);
        }

        // 处理 read_schema_from_file
        bool readSchemaFromFile = true;  // 默认值
        if (metadata.ContainsKey("read_schema_from_file"))
        {
            readSchemaFromFile = ParseBool(metadata["read_schema_from_file"]);
        }

        // 自动补全 value_type 的命名空间
        if (readSchemaFromFile && string.IsNullOrEmpty(TypeUtil.GetNamespace(valueType)))
        {
            valueType = TypeUtil.MakeFullName(namespaceName, valueType);
        }

        // 创建 RawTable
        var table = new RawTable
        {
            Namespace = namespaceName,
            Name = tableName,
            ValueType = valueType,
            InputFiles = new List<string> { input },
            Mode = mode,
            ReadSchemaFromFile = readSchemaFromFile,
            Index = GetOptional(metadata, "index", "id"),
            Comment = GetOptional(metadata, "comment", ""),
            Groups = ParseGroups(GetOptional(metadata, "group", "")),
            Tags = DefUtil.ParseAttrs(GetOptional(metadata, "tags", "")),
            OutputFile = GetOptional(metadata, "output", ""),
        };

        return table;
    }

    /// <summary>
    /// 获取相对于 dataDir 的路径
    /// </summary>
    private static string GetRelativePathToDataDir(string absolutePath)
    {
        // 获取 dataDir（与上游 DefaultTableImporter 取同一来源）
        string dataDir = FileUtil.Standardize(GenerationContext.GlobalConf.InputDataDir);
        string standardizedPath = FileUtil.Standardize(absolutePath);

        if (standardizedPath.StartsWith(dataDir))
        {
            string relative = standardizedPath.Substring(dataDir.Length)
                .TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            return relative.Replace('\\', '/');
        }

        // 降级：返回文件名
        return Path.GetFileName(absolutePath);
    }

    /// <summary>
    /// 从字典中获取可选字段
    /// </summary>
    private static string GetOptional(Dictionary<string, string> dict, string key, string defaultValue)
    {
        return dict.TryGetValue(key, out var value) ? value : defaultValue;
    }

    /// <summary>
    /// 解析 mode 字符串
    /// </summary>
    private static TableMode ParseMode(string modeStr)
    {
        return modeStr.ToLower() switch
        {
            "map" => TableMode.MAP,
            "list" => TableMode.LIST,
            "one" => TableMode.ONE,
            _ => throw new Exception($"Invalid mode: {modeStr}. Expected: map, list, or one")
        };
    }

    /// <summary>
    /// 解析布尔值字符串
    /// </summary>
    private static bool ParseBool(string boolStr)
    {
        return boolStr.ToLower() switch
        {
            "1" => true,
            "true" => true,
            "0" => false,
            "false" => false,
            _ => throw new Exception($"Invalid bool value: {boolStr}. Expected: 1, 0, true, or false")
        };
    }

    /// <summary>
    /// 解析 groups 字符串
    /// </summary>
    private static List<string> ParseGroups(string groupStr)
    {
        if (string.IsNullOrWhiteSpace(groupStr))
        {
            return new List<string>();
        }

        return groupStr.Split(',')
            .Select(s => s.Trim())
            .Where(s => !string.IsNullOrEmpty(s))
            .ToList();
    }
}
