// Copyright 2026 EsyLuban
// Licensed under MIT License

using System.Runtime.CompilerServices;
using Luban.DataLoader;
using Luban.Defs;
using Luban.Diagnostics;
using Luban.Pipeline;
using Luban.Schema;
using Luban.Utils;

namespace Luban;

/// <summary>
/// [EsyLuban] 多语言版本：<c>l10n.languages</c> 声明的语言，和 <c>variant_&lt;语言&gt;</c>
/// 文件夹里的差异。
///
/// Program 为每种语言各跑一遍导出，每一遍都在自己的 PipelineScope 里，用
/// <c>esyluban.language</c> 说明这一遍是哪种语言。默认语言那一遍不叠加任何差异；
/// 其它语言那一遍，导入器把 <c>variant_&lt;语言&gt;</c> 里的表登记在这里，读完默认版的
/// 数据后按主键叠加上去。叠加用的是上游 TableDataInfo 现成的 patch 合并（Luban 1.x
/// 「main + patch」留下的代码），这里只负责把差异行读出来交给它。
/// </summary>
public static class LanguageVariants
{
    public const string FolderPrefix = "variant_";

    private static readonly ConditionalWeakTable<PipelineScope, Dictionary<string, List<string>>> s_overlays = new();

    /// <summary><c>l10n.languages</c> 声明的语言，第一种是默认语言；没声明时为空。</summary>
    public static List<string> Declared => Parse(EnvManager.Current.GetOptionOrDefault("l10n", "languages", false, ""));

    /// <summary>这一遍导出的语言。单语言项目为空。</summary>
    public static string Current => EnvManager.Current.GetOptionOrDefault("esyluban", "language", false, "");

    /// <summary>这一遍要叠加差异：声明了多种语言，且这一遍不是默认语言。</summary>
    public static bool IsVariantRun
    {
        get
        {
            var declared = Declared;
            string current = Current;
            return declared.Count > 0 && current.Length > 0 && current != declared[0];
        }
    }

    public static List<string> Parse(string languages)
    {
        var result = new List<string>();
        foreach (string language in languages.Split(',').Select(s => s.Trim()).Where(s => s.Length > 0))
        {
            if (result.Contains(language))
            {
                throw new EsyLubanException(EsyMessages.DuplicateLanguage, null, language);
            }
            result.Add(language);
        }
        return result;
    }

    /// <summary>
    /// 文件是哪种语言的差异。只有声明了 l10n.languages 的项目，<c>variant_</c> 文件夹才有这层
    /// 含义；没声明时它就是普通文件夹，里面的表和别处的一样，所以不用多语言的项目升级后不变。
    /// </summary>
    public static string VariantOf(string dataDir, string file)
    {
        return Declared.Count > 0 ? VariantFolderOf(dataDir, file) : null;
    }

    /// <summary>
    /// 文件在哪个 <c>variant_</c> 文件夹里（返回文件夹名里的语言），不在任何 <c>variant_</c> 文件夹里
    /// 时为 null。只看数据目录以下的各级目录名；文件夹前缀不分大小写，语言名原样返回。
    /// </summary>
    public static string VariantFolderOf(string dataDir, string file)
    {
        string relative = Path.GetRelativePath(Path.GetFullPath(dataDir), Path.GetFullPath(file));
        string[] segments = relative.Split('/', '\\');
        string language = null;
        for (int i = 0; i < segments.Length - 1; i++)
        {
            if (!segments[i].StartsWith(FolderPrefix, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }
            if (language != null)
            {
                throw new EsyLubanException(EsyMessages.NestedVariant, SchemaSource.Create(file), FileUtil.Standardize(relative));
            }
            language = segments[i].Substring(FolderPrefix.Length);
        }
        return language;
    }

    /// <summary>
    /// l10n.textFile.path 里哪些文本表是默认版、哪些是 <paramref name="language"/> 的差异；
    /// <paramref name="language"/> 为 null 时只要默认版。每一项是文件（可带 sheet@）时，差异是它
    /// 旁边 variant_&lt;语言&gt; 文件夹里的同名文件；是目录时，目录里 variant_&lt;语言&gt; 文件夹下
    /// 的都是差异，variant_ 文件夹里的文件都不算默认版。路径的写法和上游一样，相对当前目录。
    /// </summary>
    public static (List<string> Defaults, List<string> Overlays) TextFiles(string textFiles, string language)
    {
        string inputDataDir = GenerationContext.GetInputDataPath();
        var defaults = new List<string>();
        var overlays = new List<string>();
        foreach (string entry in textFiles.Split(';', ','))
        {
            if (!Directory.Exists(entry))
            {
                defaults.Add(entry);
                if (language != null)
                {
                    var (actualFile, sheetName) = FileUtil.SplitFileAndSheetName(FileUtil.Standardize(entry));
                    string sibling = FileUtil.Standardize(Path.Combine(Path.GetDirectoryName(actualFile) ?? "", FolderPrefix + language, Path.GetFileName(actualFile)));
                    if (File.Exists(sibling))
                    {
                        overlays.Add(sheetName != null ? $"{sheetName}@{sibling}" : sibling);
                    }
                }
                continue;
            }
            foreach (string file in FileUtil.GetFileOrDirectory(inputDataDir, entry))
            {
                string fileLanguage = VariantOf(entry, file);
                if (fileLanguage == null)
                {
                    defaults.Add(file);
                }
                else if (fileLanguage == language)
                {
                    overlays.Add(file);
                }
            }
        }
        return (defaults, overlays);
    }

    /// <summary>这一遍要叠加到 <paramref name="tableFullName"/> 上的差异数据来自哪里（写法同表的 input）。</summary>
    public static void RegisterOverlay(string tableFullName, IEnumerable<string> inputs)
    {
        var overlays = s_overlays.GetValue(PipelineScope.Current, _ => new Dictionary<string, List<string>>());
        if (!overlays.TryGetValue(tableFullName, out var list))
        {
            list = new List<string>();
            overlays.Add(tableFullName, list);
        }
        list.AddRange(inputs);
    }

    /// <summary>
    /// 读完一张表的默认版之后调用：没有差异原样返回；有差异时读出差异行，交给 TableDataInfo 合并。
    /// map 与单例表作为 patch 交给它（按主键覆盖、追加；单例整张替换）。list 表没有主键可比，
    /// 有差异就整张替换，而上游的 patch 合并对 list 表直接报错，所以这里直接换掉主数据。
    /// </summary>
    public static (List<Record> Main, List<Record> Patch) Apply(DefTable table, List<Record> records)
    {
        if (!PipelineScope.HasCurrent
            || !s_overlays.TryGetValue(PipelineScope.Current, out var overlays)
            || !overlays.TryGetValue(table.FullName, out var inputs))
        {
            return (records, null);
        }

        string inputDataDir = GenerationContext.GetInputDataPath();
        var overlay = new List<Record>();
        foreach (string input in inputs)
        {
            var (actualFile, sheetName) = FileUtil.SplitFileAndSheetName(FileUtil.Standardize(input));
            foreach (string atomFile in FileUtil.GetFileOrDirectory(inputDataDir, Path.Combine(inputDataDir, actualFile)))
            {
                overlay.AddRange(DataLoaderManager.Ins.LoadTableFile(table, atomFile, sheetName, new Dictionary<string, string>()));
            }
        }
        return table.IsListTable ? (overlay, null) : (records, overlay);
    }
}
