// Copyright 2025 EZLuban
// Licensed under MIT License

using NPOI.SS.UserModel;
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

        using var stream = new FileStream(actualFile, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        var workbook = WorkbookFactory.Create(stream);

        // 遍历所有 Sheet
        for (int i = 0; i < workbook.NumberOfSheets; i++)
        {
            var sheet = workbook.GetSheetAt(i);
            
            // 如果指定了 Sheet 名，只处理该 Sheet
            if (!string.IsNullOrEmpty(requestedSheetName) && sheet.SheetName != requestedSheetName)
            {
                continue;
            }

            // 检查是否是自包含 Sheet
            if (IsSelfContainedSheet(sheet))
            {
                try
                {
                    var table = ParseSheetMetadata(sheet, actualFile);
                    Collector.Add(table);
                    s_logger.Info($"Loaded self-contained table: {table.Name} from {actualFile}@{sheet.SheetName}");
                }
                catch (Exception ex)
                {
                    s_logger.Error(ex, $"Failed to parse self-contained sheet: {actualFile}@{sheet.SheetName}");
                    throw;
                }
            }
        }
    }

    /// <summary>
    /// 检查是否是自包含 Sheet
    /// </summary>
    private bool IsSelfContainedSheet(ISheet sheet)
    {
        var a1Row = sheet.GetRow(0);
        if (a1Row == null) return false;

        var a1Cell = a1Row.GetCell(0);
        if (a1Cell == null) return false;

        string a1Value = a1Cell.StringCellValue?.Trim() ?? "";
        return a1Value == "##export";
    }

    /// <summary>
    /// 解析 Sheet 元数据
    /// </summary>
    private RawTable ParseSheetMetadata(ISheet sheet, string fileName)
    {
        var b1Row = sheet.GetRow(0);
        var b1Cell = b1Row?.GetCell(1);
        
        if (b1Cell == null)
        {
            throw new Exception($"Sheet '{sheet.SheetName}' has ##export but B1 is empty!");
        }

        string b1Content = b1Cell.StringCellValue?.Trim() ?? "";
        if (string.IsNullOrWhiteSpace(b1Content))
        {
            throw new Exception($"Sheet '{sheet.SheetName}' B1 content is empty!");
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
            input = $"{relativePath}@{sheet.SheetName}";
        }

        // 处理 mode
        TableMode mode = TableMode.Map;  // 默认值
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
    private string GetRelativePathToDataDir(string absolutePath)
    {
        // 获取 dataDir（从配置中）
        string dataDir = FileUtil.Standardize(Context.DataInputDir);
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
            "map" => TableMode.Map,
            "list" => TableMode.List,
            "one" => TableMode.One,
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
