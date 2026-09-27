// Copyright 2026 EsyLuban
// Licensed under MIT License

using ExcelDataReader;
using Luban.Diagnostics;
using Luban.RawDefs;
using Luban.Utils;

namespace Luban.Schema.Builtin;

/// <summary>
/// 支持内联定义的 schema 收集器。
///
/// 在上游收集流程之外，额外扫描数据目录：同一个 Excel 内若含名为
/// <c>__beans__</c> / <c>__enums__</c> 的 sheet，即作为该文件的 bean / enum 定义加载，
/// 作用域为 file-wide（同一文件内多张数据表可共用）。
///
/// <para>
/// 这样一张表连同它专用的类型定义可以放在同一个 Excel 里交付，不必再回到集中的
/// <c>__beans__.xlsx</c> 登记 —— 与"表自描述"是同一个目标：让写表的人只面对一个文件。
/// </para>
///
/// <para>
/// 实现上借 Luban 既有的 behaviour 优先级机制覆盖默认收集器，并直接复用上游的
/// bean/enum ExcelSchemaLoader（它本就支持 <c>文件@sheet</c> 定位），因此既不改动
/// 上游代码，也不重复实现一遍定义表的解析。
/// </para>
/// </summary>
[SchemaCollector("default", Priority = 100)]
public class SelfContainedSchemaCollector : DefaultSchemaCollector
{
    private static readonly NLog.Logger s_logger = NLog.LogManager.GetCurrentClassLogger();

    private const string InlineBeanSheetName = "__beans__";
    private const string InlineEnumSheetName = "__enums__";

    public override void Load(LubanConfig config)
    {
        base.Load(config);
        LoadInlineDefinitions();
    }

    /// <summary>
    /// 右键「列出选中的表」：选中范围里有哪些表名。
    ///
    /// 不走 Load，因为 Load 会解析表变体，而那要看同名表的全部定义。选中范围里往往只有
    /// 其中一份：默认那份在 B1、其余几份在 XML 时，右键别的目录，范围里只剩 XML 那几份，
    /// 解析就报「没有 fallback」而中止。这里只收集表名，选哪一份交给随后的导出，它加载
    /// 全量 schema，带着同一个 --variant。重复定义照旧当场报。
    ///
    /// B1 表按 B1 所在的 sheet 算，由导入器按 tableImporter.scanPath 扫出。XML 和
    /// __tables__.xlsx 里定义的表按 input 是否和选中范围重叠算，否则它们会混进每一次右键。
    ///
    /// 多语言项目里，每一行还要说明影响哪些语言：默认版的表影响每一种语言，写表名；只在
    /// variant_&lt;语言&gt; 里选中的表只影响那种语言，写成「表名@语言」（见 Program.PlanLanguageRuns）。
    /// </summary>
    public List<string> ListTableNamesInScope(LubanConfig config)
    {
        // 和 DefaultSchemaCollector.Load 的前两步相同，少了变体解析和读表头
        foreach (var importFile in config.Imports)
        {
            string ext = FileUtil.GetExtensionWithoutDot(importFile.FileName);
            if (string.IsNullOrEmpty(ext))
            {
                throw new LubanException("error.schema.file_no_extension", importFile.FileName);
            }
            SchemaManager.Ins.CreateSchemaLoader(ext, importFile.Type, this).Load(importFile.FileName);
        }
        var defined = Tables.ToList();
        var imported = new List<RawTable>();
        string importerName = EnvManager.Current.GetOptionOrDefault("tableImporter", "name", false, "default");
        if (!string.IsNullOrWhiteSpace(importerName) && importerName != "none")
        {
            imported = SchemaManager.Ins.CreateTableImporter(importerName).LoadImportTables();
        }
        CheckDuplicateDefinitions(defined.Concat(imported).ToList());

        string scope = Path.GetFullPath(SelfContainedTableImporter.GetScanRoot());
        string dataDir = GenerationContext.GlobalConf.InputDataDir;
        var names = defined
            .Where(t => t.InputFiles.Any(input =>
                Overlaps(Path.GetFullPath(Path.Combine(dataDir, FileUtil.SplitFileAndSheetName(FileUtil.Standardize(input)).Item1)), scope)))
            .Concat(imported)
            .Select(t => TypeUtil.MakeFullName(t.Namespace, t.Name))
            .Distinct()
            .ToList();
        // 默认版也选中了的表已经每种语言都导，不用再按语言列一遍
        var languageOnly = SelfContainedTableImporter.ListVariantTables()
            .Where(v => !names.Contains(v.FullName))
            .Select(v => $"{v.FullName}@{v.Language}")
            .Distinct()
            .ToList();
        return names.Concat(languageOnly).Concat(TextTablesInScope(config, scope)).ToList();
    }

    /// <summary>
    /// 文本在导出时替换成文案的项目，文本表影响所有用到文本的表：选中默认版的文本表，每种
    /// 语言都要重导全部的表；选中 variant_&lt;语言&gt; 里的文本表，只重导那种语言的。全部的表
    /// 写成 *，免得命令行上列出几百张表。
    ///
    /// 文本表的路径相对 luban.conf 所在目录（导出时 gen.bat 和右键都先进入这个目录）；
    /// 右键列表时当前目录是右键的位置，所以这里先换成绝对路径。
    /// </summary>
    private static IEnumerable<string> TextTablesInScope(LubanConfig config, string scope)
    {
        var env = EnvManager.Current;
        if (!env.TryGetOption(BuiltinOptionNames.L10NFamily, BuiltinOptionNames.L10NProviderName, false, out _)
            || !DataUtil.ParseBool(env.GetOptionOrDefault(BuiltinOptionNames.L10NFamily, BuiltinOptionNames.L10NConvertTextKeyToValue, false, "false"))
            || !env.TryGetOption(BuiltinOptionNames.L10NFamily, BuiltinOptionNames.L10NTextFilePath, false, out string textFiles))
        {
            yield break;
        }
        textFiles = string.Join(",", textFiles.Split(';', ',').Select(entry => Path.Combine(config.ConfigDir, entry)));
        bool InScope(string textFile) => IsUnder(Path.GetFullPath(FileUtil.SplitFileAndSheetName(FileUtil.Standardize(textFile)).Item1), scope);

        if (LanguageVariants.TextFiles(textFiles, null).Defaults.Any(InScope))
        {
            yield return "*";
            yield break;
        }
        foreach (string language in LanguageVariants.Declared.Skip(1))
        {
            if (LanguageVariants.TextFiles(textFiles, language).Overlays.Any(InScope))
            {
                yield return $"*@{language}";
            }
        }
    }

    /// <summary>
    /// 两份定义都没写 variant、同一个变体写了两份：这类错不管选哪一份都导不出来，
    /// 列表就该当场报，不能拖到导出那一步，在每个 target 上各报一遍。
    ///
    /// 借上游的解析器来查，免得抄一份它的规则：给每张带变体的表指定一个它自己声明过的
    /// 变体，选择这一步就不会因为看不全同名表而失败，而重复检查在选择之前就做完了。
    /// </summary>
    private static void CheckDuplicateDefinitions(List<RawTable> tables)
    {
        var selectable = tables
            .Where(t => t.Variants.Count > 0)
            .GroupBy(t => TypeUtil.MakeFullName(t.Namespace, t.Name))
            .ToDictionary(g => g.Key, g => g.First().Variants[0]);
        TableVariantResolver.Resolve(tables, selectable);
    }

    // input 可以是目录：选中目录里的一个文件，同样算选中了这张表
    private static bool Overlaps(string a, string b) => IsUnder(a, b) || IsUnder(b, a);

    private static bool IsUnder(string path, string root)
    {
        path = FileUtil.Standardize(path).TrimEnd('/');
        root = FileUtil.Standardize(root).TrimEnd('/');
        return path.Equals(root, StringComparison.OrdinalIgnoreCase)
               || path.StartsWith(root + "/", StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>
    /// 收集内联定义。放在 base.Load 之后即可：Load 阶段只做收集，
    /// 真正的类型解析发生在 CreateRawAssembly，此时定义已齐备。
    /// </summary>
    private void LoadInlineDefinitions()
    {
        int fileCount = 0;
        foreach (string file in SelfContainedTableImporter.EnumerateDataExcelFiles(
                     SelfContainedTableImporter.GetScanRoot()))
        {
            var sheets = GetInlineDefinitionSheets(file);
            if (sheets.Count == 0)
            {
                continue;
            }
            foreach (var (sheetName, type) in sheets)
            {
                var loader = SchemaManager.Ins.CreateSchemaLoader("xlsx", type, this);
                // 注意定位语法是「sheet名@文件路径」，而非「文件@sheet」
                // （见 FileUtil.SplitFileAndSheetName）。
                loader.Load($"{sheetName}@{file}");
                s_logger.Info("import inline schema file:\"{}@{}\" type:\"{}\"", sheetName, file, type);
            }
            ++fileCount;
        }
        if (fileCount > 0)
        {
            s_logger.Info("self-contained schema collector: inline definitions loaded from {} file(s)", fileCount);
        }
    }

    private static int TypeLoadOrder(string type) => type == "enum" ? 0 : 1;

    /// <summary>
    /// 探测文件内是否含 __beans__ / __enums__ 子表，返回 (sheet 名, schema 类型)。
    /// </summary>
    private static List<(string SheetName, string Type)> GetInlineDefinitionSheets(string file)
    {
        var found = new List<(string, string)>();
        try
        {
            using var stream = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            using var reader = ExcelReaderFactory.CreateReader(stream);
            do
            {
                string sheetName = reader.Name;
                if (string.Equals(sheetName, InlineEnumSheetName, StringComparison.OrdinalIgnoreCase))
                {
                    found.Add((sheetName, "enum"));
                }
                else if (string.Equals(sheetName, InlineBeanSheetName, StringComparison.OrdinalIgnoreCase))
                {
                    found.Add((sheetName, "bean"));
                }
            } while (reader.NextResult());
        }
        // 和 SelfContainedTableImporter 同理：LubanException 自带错误码和位置，别再包一层
        catch (Exception ex) when (ex is not LubanException)
        {
            throw new EsyLubanException(ex, EsyMessages.ImportFailed, SchemaSource.Create(file));
        }

        // enum 先于 bean：bean 的字段可能引用同文件内定义的枚举
        found.Sort((a, b) => TypeLoadOrder(a.Item2).CompareTo(TypeLoadOrder(b.Item2)));
        return found;
    }
}
