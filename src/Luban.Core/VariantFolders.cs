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
/// [EsyLuban] 变体：同一份数据的几个版本。<c>esyluban.variants</c> 声明有哪些变体，
/// <c>variant_&lt;名字&gt;</c> 文件夹里放这个版本和默认版不一样的地方。最常见的是按语言分，
/// 但变体本身不限于语言。
///
/// Program 先导出默认版，再为每个变体各跑一遍，每一遍都在自己的 PipelineScope 里，用
/// <c>esyluban.currentVariant</c> 说明这一遍是哪个变体。默认版那一遍不叠加任何差异；变体那一遍，
/// 导入器把 <c>variant_&lt;名字&gt;</c> 里的表登记在这里，读完默认版的数据后按主键叠加上去。
/// 叠加用的是上游 TableDataInfo 现成的 patch 合并（Luban 1.x「main + patch」留下的代码），
/// 这里只负责把差异行读出来交给它。
/// </summary>
public static class VariantFolders
{
    public const string FolderPrefix = "variant_";

    /// <summary>Program 给每一遍导出设置的变体名，默认版那一遍不设。</summary>
    public const string CurrentVariantOption = "esyluban.currentVariant";

    private static readonly ConditionalWeakTable<PipelineScope, Dictionary<string, List<string>>> s_overlays = new();

    /// <summary><c>esyluban.variants</c> 声明的变体；没声明时为空。</summary>
    public static List<string> Declared => Parse(EnvManager.Current.GetOptionOrDefault("esyluban", "variants", false, ""));

    /// <summary>这一遍导出的变体，默认版那一遍为空。</summary>
    public static string Current => EnvManager.Current.GetOptionOrDefault("esyluban", "currentVariant", false, "");

    /// <summary>这一遍要叠加某个变体的差异。</summary>
    public static bool IsVariantRun => Current.Length > 0 && Declared.Contains(Current);

    public static List<string> Parse(string variants)
    {
        var result = new List<string>();
        foreach (string variant in variants.Split(',').Select(s => s.Trim()).Where(s => s.Length > 0))
        {
            if (result.Contains(variant))
            {
                throw new EsyLubanException(EsyMessages.DuplicateVariant, null, variant);
            }
            result.Add(variant);
        }
        return result;
    }

    /// <summary>
    /// 文件是哪个变体的差异。只有声明了 esyluban.variants 的项目，<c>variant_</c> 文件夹才有这层
    /// 含义；没声明时它就是普通文件夹，里面的表和别处的一样，所以不用变体的项目升级后不变。
    /// </summary>
    public static string VariantOf(string dataDir, string file)
    {
        return Declared.Count > 0 ? VariantFolderOf(dataDir, file) : null;
    }

    /// <summary>
    /// 文件在哪个 <c>variant_</c> 文件夹里（返回文件夹名里的变体名），不在任何 <c>variant_</c> 文件夹里
    /// 时为 null。只看数据目录以下的各级目录名；文件夹前缀不分大小写，变体名原样返回。
    /// </summary>
    public static string VariantFolderOf(string dataDir, string file)
    {
        string relative = Path.GetRelativePath(Path.GetFullPath(dataDir), Path.GetFullPath(file));
        string[] segments = relative.Split('/', '\\');
        string variant = null;
        for (int i = 0; i < segments.Length - 1; i++)
        {
            if (!segments[i].StartsWith(FolderPrefix, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }
            if (variant != null)
            {
                throw new EsyLubanException(EsyMessages.NestedVariant, SchemaSource.Create(file), FileUtil.Standardize(relative));
            }
            variant = segments[i].Substring(FolderPrefix.Length);
        }
        return variant;
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
