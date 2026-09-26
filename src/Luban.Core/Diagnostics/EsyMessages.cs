// Copyright 2026 EsyLuban
// Licensed under MIT License

using System.Globalization;
using Luban.Schema;

namespace Luban.Diagnostics;

/// <summary>
/// EsyLuban 自己的一条报错或告警：稳定的码，加中英两份模板（string.Format 的 {0} 占位）。
/// 语言和上游的报错一样，跟随 --locale 或 Windows 界面语言。
/// </summary>
public sealed class EsyMessage
{
    public string Code { get; }

    public string Zh { get; }

    public string En { get; }

    public EsyMessage(string code, string zh, string en)
    {
        Code = code;
        Zh = zh;
        En = en;
    }

    public string Format(params object[] args)
        => string.Format(CultureInfo.InvariantCulture, MessageCatalog.Locale == "zh" ? Zh : En, args);
}

/// <summary>
/// EsyLuban 的全部报错与告警文字。
///
/// 和上游的 messages_zh.json / messages_en.json 是同一种东西：码对应中英两份模板。
/// 没往那两个文件里加，是因为它们属于上游，每次跟进都要合并。
///
/// 文档引用的码和原文由 check_doc_facts.ps1 对着这里核对，它只认
/// new("码", "中文", "英文") 这种每份模板一个字面量的写法，别拼接、别插值。
/// 告警以 [xxx] 标签开头，中英文日志里都一样，按它搜。
/// </summary>
public static class EsyMessages
{
    public static readonly EsyMessage ScanPathNotFound = new("esyluban.import.scan_path_not_found",
        "tableImporter.scanPath 指向的路径不存在：{0}",
        "tableImporter.scanPath points to a path that does not exist: {0}");

    public static readonly EsyMessage ImportFailed = new("esyluban.import.failed",
        "导入表失败",
        "Failed to import tables");

    public static readonly EsyMessage BadExportMarker = new("esyluban.import.bad_export_marker",
        "[bad A1] sheet '{0}'@{1} 的 A1 是 '{2}'，不是有效的 ##export 标记，这张 sheet 没有导出。有效写法只有 ##export 与 ##export=false，不分大小写。",
        "[bad A1] sheet '{0}'@{1}: A1 is '{2}', which is not a valid ##export marker, so the sheet was not exported. The only valid forms are ##export and ##export=false, in any letter case.");

    public static readonly EsyMessage EmptyB1 = new("esyluban.import.empty_b1",
        "[empty B1] sheet '{0}'@{1} 的 A1 是 ##export，B1 却是空的，这张 sheet 不会作为表导出。要导出就在 B1 写上 full_name；如果它由别处读取（文本表、XML 里定义的表、别的表的 input），这条可以不管。",
        "[empty B1] sheet '{0}'@{1} has ##export in A1 but nothing in B1, so it is not exported as a table. To export it, write full_name in B1. If something else reads this sheet (a text table, a table defined in XML, another table's input), ignore this.");

    public static readonly EsyMessage B1Empty = new("esyluban.b1.empty",
        "B1 是空的。",
        "B1 is empty.");

    public static readonly EsyMessage B1MissingEquals = new("esyluban.b1.missing_equals",
        "B1 里的 '{0}' 缺少 =。每一项都写成 key=\"value\"。",
        "B1 item '{0}' has no '='. Write each item as key=\"value\".");

    public static readonly EsyMessage B1EmptyKey = new("esyluban.b1.empty_key",
        "B1 里的 '{0}' 在 = 前面没有写名字。",
        "B1 item '{0}' has no name before '='.");

    public static readonly EsyMessage B1UnmatchedQuote = new("esyluban.b1.unmatched_quote",
        "B1 里的双引号没有配对。检查是不是混进了中文引号“”。",
        "B1 has an unmatched double quote. Check for curly quotes such as “ ” typed by an input method.");

    public static readonly EsyMessage B1MissingFullName = new("esyluban.b1.missing_full_name",
        "B1 缺少 full_name。它是唯一必填的一项，例如 full_name=\"item.TbItem\"。",
        "B1 is missing full_name, the one required item, e.g. full_name=\"item.TbItem\".");

    public static readonly EsyMessage B1BadMode = new("esyluban.b1.bad_mode",
        "B1 的 mode 写成了 '{0}'，只能是 map、list 或 one。",
        "B1 mode is '{0}', expected map, list or one.");

    public static readonly EsyMessage B1BadBool = new("esyluban.b1.bad_bool",
        "B1 的 {0} 写成了 '{1}'，只能是 true、false、1 或 0。",
        "B1 {0} is '{1}', expected true, false, 1 or 0.");

    public static readonly EsyMessage B1VariantUnsupported = new("esyluban.b1.variant_unsupported",
        "表 {0} 的 B1 写了 variant，自包含表暂不支持表变体。多语言文本请用文本表（见 docs/localization.md）；要按地区换整张表，就把默认那份留在 B1，其余几份用 __tables__.xlsx 或 XML 定义同名表。",
        "Table {0}: B1 sets variant, but self-contained tables do not support table variants yet. For translated text use a text table (see docs/localization.md). To swap a whole table per region, keep the default one in B1 and define the others under the same name in __tables__.xlsx or XML.");

    public static readonly EsyMessage B1DuplicateFullName = new("esyluban.b1.duplicate_full_name",
        "表 {0} 被定义了 {1} 次：{2}。每张表的 full_name 必须唯一，复制 sheet 后记得改 B1。",
        "Table {0} is defined {1} times: {2}. Each table needs its own full_name; after copying a sheet, remember to change B1.");

    // {0} 是 dataTarget / codeTarget（json、cs-simple-json…），不是 targets 里的那个 target，
    // 所以叫它「输出目标」，免得照着去查错东西。
    public static readonly EsyMessage CleanupNoOutput = new("esyluban.cleanup.no_output",
        "[skip cleanup] 输出目标 '{0}' 本次没有产出任何文件，却要删除 {1} 个已有文件，已跳过清理。通常是该 target 绑定的 group 全部 default:false，导致一张表都没被导出。确需清空请加 -x forceCleanUpOutputDir=1",
        "[skip cleanup] output target '{0}' produced no files but would delete {1} existing file(s), so cleanup was skipped. Usually every group bound to the target is default:false and no table was exported. To clear the directory anyway, add -x forceCleanUpOutputDir=1");

    public static readonly EsyMessage CleanupTooMany = new("esyluban.cleanup.too_many",
        "[skip cleanup] 输出目标 '{0}' 将删除 {1} 个文件，多于本次产出的 {2} 个，已跳过清理。通常是多个 target 或 dataTarget 共用了同一个 outputDataDir，或该目录混放了非 Luban 生成的文件。确需清理请加 -x forceCleanUpOutputDir=1",
        "[skip cleanup] output target '{0}' would delete {1} file(s), more than the {2} it produced, so cleanup was skipped. Usually several targets or dataTargets share one outputDataDir, or the directory holds files Luban did not generate. To clean it anyway, add -x forceCleanUpOutputDir=1");

    public static readonly EsyMessage DeadXargs = new("esyluban.xargs.dead_key",
        "[dead xargs] {0} 不会生效：{1} 是 conf 里 targets 的名字（-t 的那个 target），而 xargs 的命名空间只认 dataTarget（json、bin…）与 codeTarget（cs-simple-json…）。要按 target 分目录，请在每次调用时用 -x {2}=... 传入。",
        "[dead xargs] {0} has no effect: {1} is a target name from targets in the conf (the one -t picks), but xargs namespaces only match a dataTarget (json, bin...) or a codeTarget (cs-simple-json...). To use a directory per target, pass -x {2}=... on each run.");
}

/// <summary>
/// 带 EsyLuban 错误码的报错。
///
/// 继承 <see cref="LubanException"/>，走上游同一条报错通道：文字模式打印 Message，
/// 带 SchemaOrigin 时多打 file: / sheet:；--errorFormat json 的 code 取 MessageKey，
/// args 取 Args。
/// </summary>
public sealed class EsyLubanException : LubanException
{
    private readonly string _message;

    public EsyLubanException(EsyMessage message, SchemaSource source, params object[] args)
        : this(null, message, source, args)
    {
    }

    public EsyLubanException(Exception inner, EsyMessage message, SchemaSource source, params object[] args)
        : base(inner, source, message.Code, args)
    {
        _message = message.Format(args);
    }

    // 基类拿码去查上游的消息目录，查不到就把码本身当文字
    public override string Message => _message;
}
