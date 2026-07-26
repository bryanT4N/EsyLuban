// Copyright 2026 EsyLuban
// Licensed under MIT License

using ExcelDataReader;
using Luban.Defs;
using Luban.RawDefs;
using Luban.Utils;

namespace Luban.Schema.Builtin;

/// <summary>
/// 自包含表导入器 —— EsyLuban 发现表的唯一入口。
///
/// 扫描数据目录下的所有 Excel，凡 A1 恰为 <c>##export</c> 的 sheet，即按 B1 的
/// 元数据串生成表定义。每张表自描述，不再需要集中式的 <c>__tables__.xlsx</c>。
///
/// <para>
/// <b>为什么以 Priority 覆盖 "default"</b>：自包含表定义是本 fork 的唯一形态，
/// 不是可选项。借 Luban 既有的 behaviour 优先级机制接管默认 importer 之后，
/// 使用者无需在 luban.conf 里写 <c>tableImporter.name</c> —— 少一个不该暴露的旋钮，
/// 也就少一处需要在各工程间同步的配置。上游按 <c>#xxx</c> 文件名模式导表的
/// DefaultTableImporter 未被改动，显式配置 <c>tableImporter.name=default</c> 以外的
/// 名字仍可回到上游行为。
/// </para>
///
/// <para>
/// <b>为什么是 TableImporter 而不是 SchemaLoader</b>：SchemaLoader 只处理 luban.conf 中
/// schemaFiles 显式列出的文件；"扫描整个数据目录、发现哪些表要导出"属于 TableImporter
/// 的职责。把数据目录直接配进 schemaFiles 是行不通的 —— 目录里混有 .xml/.json/.unity
/// 等数据与资源文件，会被误当作 schema 定义。
/// </para>
/// </summary>
[TableImporter("default", Priority = 100)]
public class SelfContainedTableImporter : ITableImporter
{
    private static readonly NLog.Logger s_logger = NLog.LogManager.GetCurrentClassLogger();

    private static readonly HashSet<string> s_excelExts = new() { "xlsx", "xls", "xlsm" };

    /// <summary>
    /// schema 定义表：A1 同样是 ##export，但它们由 bean/enum schema loader 处理，
    /// 不是数据表。
    /// </summary>
    private static readonly HashSet<string> s_schemaDefinitionFileNames =
        new(StringComparer.OrdinalIgnoreCase) { "__beans__", "__enums__", "__tables__" };

    /// <summary>
    /// 本次导表的扫描根：<c>tableImporter.scanPath</c> 限定范围（可为目录或单个文件），
    /// 右键菜单的"局部导表"由此实现；留空则为整个 dataDir。
    /// </summary>
    internal static string GetScanRoot()
    {
        string scanPath = EnvManager.Current.GetOptionOrDefault("tableImporter", "scanPath", false, "");
        return string.IsNullOrWhiteSpace(scanPath) ? GenerationContext.GlobalConf.InputDataDir : scanPath;
    }

    /// <summary>
    /// 枚举扫描根下所有**数据表** Excel：跳过 Luban 的忽略项（'.'、'_'、'~' 开头）
    /// 与 schema 定义表。SelfContainedSchemaCollector 复用同一枚举，
    /// 确保"哪些文件算数据表"只有一处定义。
    /// </summary>
    internal static IEnumerable<string> EnumerateDataExcelFiles(string scanRoot)
    {
        string dataDir = GenerationContext.GlobalConf.InputDataDir;

        IEnumerable<string> files;
        if (File.Exists(scanRoot))
        {
            files = new[] { scanRoot };
        }
        else if (Directory.Exists(scanRoot))
        {
            files = Directory.GetFiles(scanRoot, "*", SearchOption.AllDirectories);
        }
        else
        {
            throw new Exception($"tableImporter.scanPath not found: {scanRoot}");
        }

        foreach (string file in files)
        {
            if (FileUtil.IsIgnoreFile(dataDir, file))
            {
                continue;
            }
            if (!s_excelExts.Contains(Path.GetExtension(file).TrimStart('.').ToLower()))
            {
                continue;
            }
            if (s_schemaDefinitionFileNames.Contains(Path.GetFileNameWithoutExtension(file)))
            {
                continue;
            }
            yield return file;
        }
    }

    public List<RawTable> LoadImportTables()
    {
        string scanRoot = GetScanRoot();

        var tables = new List<RawTable>();
        foreach (string file in EnumerateDataExcelFiles(scanRoot))
        {
            tables.AddRange(LoadTablesFromFile(file));
        }

        s_logger.Info("self-contained table importer: {} table(s) found under {}", tables.Count, scanRoot);
        return tables;
    }

    private static List<RawTable> LoadTablesFromFile(string file)
    {
        var result = new List<RawTable>();
        try
        {
            using var stream = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            // 与上游 SheetLoadUtil 使用同一套 Excel 实现（ExcelDataReader），
            // 避免为此引入第二个 Excel 库。reader 前向只读：每张 sheet 只需读第一行。
            using var reader = ExcelReaderFactory.CreateReader(stream);
            do
            {
                string sheetName = reader.Name;
                if (!reader.Read() || reader.FieldCount == 0)
                {
                    continue;
                }
                string a1 = reader.GetValue(0)?.ToString()?.Trim() ?? "";
                string b1 = reader.FieldCount > 1 ? reader.GetValue(1)?.ToString()?.Trim() ?? "" : "";

                // 只有 A1 恰为 ##export 才导出；##export=false 表示显式关闭。
                if (a1 != "##export")
                {
                    continue;
                }

                // A1 有 ##export 但 B1 无表元数据：属于 L10N 文本表、XML 定义表等
                // 由其它机制导出的文件。按既有约定只告警、不中断。
                if (string.IsNullOrWhiteSpace(b1))
                {
                    s_logger.Warn("sheet '{}'@{} has ##export but no table metadata in B1, skipped.", sheetName, file);
                    continue;
                }

                result.Add(ParseSheetMetadata(sheetName, b1, file));
                s_logger.Info("Loaded self-contained table from {}@{}", file, sheetName);
            } while (reader.NextResult());
        }
        catch (Exception ex)
        {
            throw new Exception($"Failed to import self-contained tables from: {file}", ex);
        }
        return result;
    }

    /// <summary>
    /// 按 B1 元数据串生成表定义。
    /// </summary>
    private static RawTable ParseSheetMetadata(string sheetName, string b1Content, string fileName)
    {
        var metadata = B1Parser.Parse(b1Content);

        string fullName = metadata["full_name"];
        string valueType = metadata["value_type"];

        string namespaceName = TypeUtil.GetNamespace(fullName);
        string tableName = TypeUtil.GetName(fullName);

        // input 缺省时指向当前 sheet 自身。
        // 注意定位语法是「sheet名@文件路径」，而非「文件@sheet」
        // （见 FileUtil.SplitFileAndSheetName）。
        string input = metadata.TryGetValue("input", out var inputValue)
            ? inputValue
            : $"{sheetName}@{GetRelativePathToDataDir(fileName)}";

        TableMode mode = metadata.TryGetValue("mode", out var modeValue) ? ParseMode(modeValue) : TableMode.MAP;

        bool readSchemaFromFile = !metadata.TryGetValue("read_schema_from_file", out var readValue)
                                  || ParseBool(readValue);

        // 从 Excel 读 schema 时，value_type 若未写命名空间则按表所在命名空间补全
        if (readSchemaFromFile && string.IsNullOrEmpty(TypeUtil.GetNamespace(valueType)))
        {
            valueType = TypeUtil.MakeFullName(namespaceName, valueType);
        }

        return new RawTable
        {
            Namespace = namespaceName,
            Name = tableName,
            ValueType = valueType,
            // input 支持逗号分隔多个数据源，拆分规则与上游 SchemaLoaderUtil.CreateTable 一致
            InputFiles = input.Split(',')
                .Select(s => s.Trim())
                .Where(s => !string.IsNullOrWhiteSpace(s))
                .ToList(),
            Mode = mode,
            ReadSchemaFromFile = readSchemaFromFile,
            // index 缺省时留空，交由上游 DefTable 按"取 bean 的第一个字段"处理。
            // 不要在这里臆测默认值（例如 "id"）—— 那会遮蔽上游语义，并让首字段
            // 不叫 id 的表（如 ai.Blackboard 的 name）平白报"index 字段不存在"。
            Index = GetOptional(metadata, "index", ""),
            Comment = GetOptional(metadata, "comment", ""),
            Groups = ParseGroups(GetOptional(metadata, "group", "")),
            Tags = DefUtil.ParseAttrs(GetOptional(metadata, "tags", "")),
            OutputFile = GetOptional(metadata, "output", ""),
        };
    }

    private static string GetRelativePathToDataDir(string absolutePath)
    {
        string dataDir = FileUtil.Standardize(GenerationContext.GlobalConf.InputDataDir);
        string standardizedPath = FileUtil.Standardize(absolutePath);

        if (standardizedPath.StartsWith(dataDir))
        {
            return standardizedPath.Substring(dataDir.Length)
                .TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                .Replace('\\', '/');
        }
        return Path.GetFileName(absolutePath);
    }

    private static string GetOptional(Dictionary<string, string> dict, string key, string defaultValue)
    {
        return dict.TryGetValue(key, out var value) ? value : defaultValue;
    }

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

    private static bool ParseBool(string boolStr)
    {
        return boolStr.ToLower() switch
        {
            "1" or "true" => true,
            "0" or "false" => false,
            _ => throw new Exception($"Invalid bool value: {boolStr}. Expected: 1, 0, true, or false")
        };
    }

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
