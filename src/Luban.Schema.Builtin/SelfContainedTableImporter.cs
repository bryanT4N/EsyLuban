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
/// 也就少一处需要在各工程间同步的配置。
/// </para>
///
/// <para>
/// <b>代价：上游的 <c>#xxx</c> 文件名自动导表不再可达。</b> 上游 DefaultTableImporter
/// 的源码未被改动，但它注册的名字同样是 "default"，本类以更高 Priority 压过它，
/// 而 Luban 按「名字 + 优先级」选行为，没有第二个名字能选回上游那个。实测：
/// <c>tableImporter.name=default</c> 得到本类；不存在的名字明确报
/// <c>behaviour:xxx type:ITableImporter not exists</c>；<c>none</c> 是真实存在的空
/// importer，导入零张表。
///
/// 这是有意的取舍 —— 两种发现方式并存会让「这张表为什么被导出」多一个分支，
/// 而自包含定义本就覆盖了 <c>#xxx</c> 的全部场景，还多支持多数据源、按 sheet
/// 导出与 one/list 模式（上游自动导表这三样都不支持）。
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
    ///
    /// 这组名字既可能是【文件名】（<c>__beans__.xlsx</c>），也可能是数据表文件
    /// 【内部的 sheet 名】—— 内联定义正是写在数据表旁边的 <c>__beans__</c> sheet 里
    /// （见 SelfContainedSchemaCollector）。两处都要认，否则内联定义会被当成
    /// "写坏了的数据表"而报一句无用的告警。
    /// </summary>
    private static readonly HashSet<string> s_schemaDefinitionNames =
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
            if (s_schemaDefinitionNames.Contains(Path.GetFileNameWithoutExtension(file)))
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

                // 内联 schema sheet（数据表文件里的 __beans__ / __enums__）不是数据表，
                // 由 SelfContainedSchemaCollector 负责。它的 A1 同样是 ##export、B1 同样
                // 为空，若不在这里跳过，下面那句"有 ##export 但 B1 没有表元数据"的告警
                // 就会对每个用了内联定义的文件各响一次 —— 而那恰恰是推荐写法。
                if (s_schemaDefinitionNames.Contains(sheetName))
                {
                    continue;
                }

                if (!reader.Read() || reader.FieldCount == 0)
                {
                    continue;
                }
                string a1 = reader.GetValue(0)?.ToString()?.Trim() ?? "";
                string b1 = reader.FieldCount > 1 ? reader.GetValue(1)?.ToString()?.Trim() ?? "" : "";

                // A1 恰为 ##export 才导出；##export=false 表示显式关闭。
                //
                // 大小写不敏感：策划手打出 ##Export 的概率不低，而此前它会让整张表
                // 无声消失 —— 没有报错、没有告警，导出照常成功，只是少了一张表。
                // 对"看着像想写 export 却不合法"的写法给一句告警，是因为这类 A1
                // 几乎不可能是有意为之；而 ##var 这类正常的非自包含表仍静默跳过。
                string a1Lower = a1.ToLowerInvariant();
                if (a1Lower.StartsWith("##export="))
                {
                    continue;
                }
                if (a1Lower != "##export")
                {
                    if (a1Lower.StartsWith("##") && a1Lower.Contains("export"))
                    {
                        s_logger.Warn("sheet '{}'@{} 的 A1 是 '{}'，不是有效的 ##export 标记，该表未被导出。"
                                      + " 有效写法只有 ##export 与 ##export=false。",
                            sheetName, file, a1);
                    }
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

        // full_name 是 B1 里唯一必填项 —— 其余字段要么能从它推导，
        // 要么上游本就有合理缺省。写得越少越好。
        string fullName = metadata["full_name"];

        string namespaceName = TypeUtil.GetNamespace(fullName);
        string tableName = TypeUtil.GetName(fullName);

        // value_type 缺省时按惯例由表名推导：TbItem -> Item。
        string valueType = metadata.TryGetValue("value_type", out var valueTypeValue)
            ? valueTypeValue
            : DeriveValueTypeName(tableName);

        // input 缺省时指向当前 sheet 自身。
        // 注意定位语法是「sheet名@文件路径」，而非「文件@sheet」
        // （见 FileUtil.SplitFileAndSheetName）。
        string input = metadata.TryGetValue("input", out var inputValue)
            ? inputValue
            : $"{sheetName}@{GetRelativePathToDataDir(fileName)}";

        TableMode mode = metadata.TryGetValue("mode", out var modeValue) ? ParseMode(modeValue) : TableMode.MAP;

        // 缺省为 false：表结构通常写在 XML / __beans__ 里，需要"从数据表标题行读结构"
        // 才显式写 true。
        bool readSchemaFromFile = metadata.TryGetValue("read_schema_from_file", out var readValue)
                                  && ParseBool(readValue);

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

    private static string GetRelativePathToDataDir(string filePath)
    {
        // 必须先转绝对路径再比对：tableImporter.scanPath 常以相对路径传入
        // （右键菜单、gen.bat 都是如此），此时 filePath 也是相对的，
        // 直接与绝对的 dataDir 做 StartsWith 会失配而退化成纯文件名，
        // 丢掉中间目录，进而让缺省推导出的 input 指向不存在的路径。
        string dataDir = FileUtil.Standardize(Path.GetFullPath(GenerationContext.GlobalConf.InputDataDir));
        string fullPath = FileUtil.Standardize(Path.GetFullPath(filePath));

        if (fullPath.StartsWith(dataDir))
        {
            return fullPath.Substring(dataDir.Length)
                .TrimStart(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                .Replace('\\', '/');
        }
        return Path.GetFileName(filePath);
    }

    /// <summary>
    /// 由表名推导值类型名：约定表名以 Tb 开头（TbItem -> Item）。
    /// 不符合该约定时退回表名本身，此时应在 B1 显式写 value_type。
    /// </summary>
    private static string DeriveValueTypeName(string tableName)
    {
        return tableName.Length > 2 && tableName.StartsWith("Tb")
            ? tableName.Substring(2)
            : tableName;
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

    // Delegate rather than reimplement. B1's group= replaces the group attribute
    // of an XML <table> or a __tables__.xlsx row, and upstream parses both of
    // those through CreateGroups -- so anything it accepts, B1 has to accept.
    //
    // This started life as a private copy that split on ',' only. The divergence
    // was invisible until data used it: group="c;s" became a single group named
    // literally "c;s". DefTypeBase.PreCompile validates table groups against the
    // declared set, so the export then aborted with `group:c;s not found` -- a
    // table that worked in __tables__.xlsx stopped building after migration, and
    // the message named a group nobody wrote.
    //
    // (Measured, not assumed. Field-level groups are the ones that fail
    // silently; table and type level are validated and abort.)
    //
    // Sharing the function means a future change to upstream's separator rules
    // follows us.
    private static List<string> ParseGroups(string groupStr)
    {
        return SchemaLoaderUtil.CreateGroups(groupStr ?? "");
    }
}
