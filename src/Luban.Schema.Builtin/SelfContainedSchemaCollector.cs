// Copyright 2026 EsyLuban
// Licensed under MIT License

using ExcelDataReader;
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
        catch (Exception ex)
        {
            throw new Exception($"Failed to probe inline definition sheets in: {file}", ex);
        }

        // enum 先于 bean：bean 的字段可能引用同文件内定义的枚举
        found.Sort((a, b) => TypeLoadOrder(a.Item2).CompareTo(TypeLoadOrder(b.Item2)));
        return found;
    }
}
