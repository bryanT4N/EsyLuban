// Copyright 2026 EsyLuban
// Licensed under MIT License

using ExcelDataReader;
using Luban.RawDefs;
using Luban.Utils;

namespace Luban.Schema.Builtin;

/// <summary>
/// 自包含表导入器。
///
/// 扫描数据目录下的所有 Excel，凡 A1 恰为 <c>##export</c> 的 sheet，
/// 即按 B1 的元数据串生成表定义。这样每张表自描述，不再需要集中式的
/// <c>__tables__.xlsx</c>。
///
/// 为什么是 TableImporter 而不是 SchemaLoader：
/// SchemaLoader 只处理 luban.conf 中 schemaFiles 显式列出的文件；而"扫描整个
/// 数据目录、发现哪些表要导出"属于 TableImporter 的职责（上游 DefaultTableImporter
/// 即按 <c>#xxx</c> 文件名模式做同样的事）。把数据目录直接配进 schemaFiles 是行不通的
/// —— 目录里混有 .xml/.json 等数据文件，会被误当作 schema 定义。
///
/// 启用方式（luban.conf 的 xargs 或命令行 -x）：
/// <code>tableImporter.name=selfcontained</code>
/// 可选：<code>tableImporter.scanPath=&lt;目录或文件&gt;</code> 限定扫描范围，
/// 右键菜单的"局部导表"正是借此只导出所选范围内的表。
/// </summary>
[TableImporter("selfcontained")]
public class SelfContainedTableImporter : ITableImporter
{
    private static readonly NLog.Logger s_logger = NLog.LogManager.GetCurrentClassLogger();

    private static readonly HashSet<string> s_excelExts = new() { "xlsx", "xls", "xlsm" };

    public List<RawTable> LoadImportTables()
    {
        string dataDir = GenerationContext.GlobalConf.InputDataDir;
        string scanPath = EnvManager.Current.GetOptionOrDefault("tableImporter", "scanPath", false, "");

        // scanPath 为空时扫描整个 dataDir；否则只扫描指定范围（可以是目录或单个文件）。
        string scanRoot = string.IsNullOrWhiteSpace(scanPath) ? dataDir : scanPath;

        var files = new List<string>();
        if (File.Exists(scanRoot))
        {
            files.Add(scanRoot);
        }
        else if (Directory.Exists(scanRoot))
        {
            files.AddRange(Directory.GetFiles(scanRoot, "*", SearchOption.AllDirectories));
        }
        else
        {
            s_logger.Warn("tableImporter.scanPath not found: {}", scanRoot);
            return new List<RawTable>();
        }

        var tables = new List<RawTable>();
        foreach (string file in files)
        {
            if (FileUtil.IsIgnoreFile(dataDir, file))
            {
                continue;
            }
            string ext = Path.GetExtension(file).TrimStart('.').ToLower();
            if (!s_excelExts.Contains(ext))
            {
                continue;
            }
            // __beans__ / __enums__ / __tables__ 由 bean/enum schema loader 处理
            if (SelfContainedExcelSchemaLoader.IsSchemaDefinitionFile(file))
            {
                continue;
            }

            foreach (var table in LoadTablesFromFile(file))
            {
                tables.Add(table);
            }
        }

        s_logger.Info("self-contained table importer: {} table(s) found under {}", tables.Count, scanRoot);
        return tables;
    }

    private static IEnumerable<RawTable> LoadTablesFromFile(string file)
    {
        var result = new List<RawTable>();
        try
        {
            using var stream = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
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

                // A1 有 ##export 但 B1 没有表元数据：属于 L10N 文本表、XML 定义表、
                // 目录型数据表等由其它机制导出的文件。按约定只告警、不中断。
                if (string.IsNullOrWhiteSpace(b1))
                {
                    s_logger.Warn("sheet '{}'@{} has ##export but no table metadata in B1, skipped.", sheetName, file);
                    continue;
                }

                var table = SelfContainedExcelSchemaLoader.ParseSheetMetadata(sheetName, b1, file);
                result.Add(table);
                s_logger.Info("Loaded self-contained table: {} from {}@{}", table.Name, file, sheetName);
            } while (reader.NextResult());
        }
        catch (Exception ex)
        {
            throw new Exception($"Failed to import self-contained tables from: {file}", ex);
        }
        return result;
    }
}
