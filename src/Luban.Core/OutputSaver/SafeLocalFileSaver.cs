// Copyright 2025 EsyLuban
// Licensed under MIT License

using Luban.Utils;

namespace Luban.OutputSaver;

/// <summary>
/// [EsyLuban] 给 cleanUpOutputDir 加一道闸：产物为 0、或要删的比产出的还多时，
/// 拒绝清理并告警。
///
/// 内置 LocalFileSaver 会无条件删掉输出目录里所有"不属于本次产物"的文件，
/// 不判断是不是 Luban 生成的，也不管本次到底产出了几个文件。有四条互不相干的
/// 路径通向"静默批量删除"，且全部退出码为 0：
///
///   1. target 绑定的 group 全是 default:false  -> 一张表都导不出，目录被清空
///   2. 多个 dataTarget 共用同一输出目录         -> 并行清理器互删对方产物
///   3. -o 限定局部导出而未关闭清理              -> 只留下所选的那张表
///   4. outputDataDir 指向了混放其他资源的目录   -> 无关文件一并删除
///
/// 闸门用「本次产物数」与「将删除数」的关系来识别这些异常。正常的全量导出里
/// 要删的只是已废弃表的残留，数量远小于产物数，因此不受影响。
///
/// 通过 [OutputSaver("local", Priority = 100)] 覆盖内置实现，
/// 不改动上游任何一行代码。确需强行清理时用 -x forceCleanUpOutputDir=1。
/// </summary>
[OutputSaver("local", Priority = 100)]
public class SafeLocalFileSaver : OutputSaverBase
{
    private static readonly NLog.Logger s_logger = NLog.LogManager.GetCurrentClassLogger();

    public const string ForceCleanUpOutputDir = "forceCleanUpOutputDir";

    protected override void BeforeSave(OutputFileManifest outputFileManifest, string outputDir)
    {
        if (!EnvManager.Current.GetBoolOptionOrDefault($"{BuiltinOptionNames.OutputSaver}.{outputFileManifest.TargetName}", BuiltinOptionNames.CleanUpOutputDir,
                true, true))
        {
            return;
        }

        var savedFiles = outputFileManifest.DataFiles.Select(f => f.File).ToList();
        if (!IsCleanupSane(outputDir, savedFiles, outputFileManifest.TargetName))
        {
            return;
        }
        FileCleaner.Clean(outputDir, savedFiles);
    }

    private static bool IsCleanupSane(string outputDir, List<string> savedFiles, string targetName)
    {
        if (EnvManager.Current.GetBoolOptionOrDefault("", ForceCleanUpOutputDir, true, false))
        {
            return true;
        }
        if (!Directory.Exists(outputDir))
        {
            return true;
        }

        int produced = savedFiles.Count;
        int toDelete = CountDoomedFiles(outputDir, savedFiles);
        if (toDelete == 0)
        {
            return true;
        }

        // 一个产物都没有却要删东西 —— 几乎总是 group 过滤把表全滤掉了，
        // 而不是"这个目录该空了"。
        if (produced == 0)
        {
            s_logger.Warn("[skip cleanup] {} 本次没有产出任何文件，却要删除 {} 个已有文件，已跳过清理。"
                          + " 通常是该 target 绑定的 group 全部 default:false，导致一张表都没被导出。"
                          + " 确需清空请加 -x forceCleanUpOutputDir=1",
                Describe(targetName), toDelete);
            return false;
        }

        // 删得比产出的还多，说明这个目录里主要是别人的东西。
        if (toDelete > produced)
        {
            s_logger.Warn("[skip cleanup] {} 将删除 {} 个文件，多于本次产出的 {} 个，已跳过清理。"
                          + " 通常是多个 target 或 dataTarget 共用了同一个 outputDataDir，"
                          + " 或该目录混放了非 Luban 生成的文件。确需清理请加 -x forceCleanUpOutputDir=1",
                Describe(targetName), toDelete, produced);
            return false;
        }
        return true;
    }

    // manifest.TargetName 装的是 dataTarget / codeTarget（json、cs-simple-json…），
    // 不是 targets 里的那个 target。日志里说清楚，免得照着去查错东西。
    private static string Describe(string targetName)
        => $"输出目标 '{targetName}'";

    private static int CountDoomedFiles(string outputDir, List<string> savedFiles)
    {
        var saved = new HashSet<string>(
            savedFiles.Select(f => f.Replace('\\', '/')), StringComparer.OrdinalIgnoreCase);
        string fullRoot = Path.GetFullPath(outputDir);
        int count = 0;
        foreach (string file in Directory.GetFiles(outputDir, "*", SearchOption.AllDirectories))
        {
            // 与 FileCleaner 保持一致：Unity/Godot 的伴生文件从不参与清理
            string ext = FileUtil.GetFileExtension(file);
            if (ext == "meta" || ext == "uid")
            {
                continue;
            }
            string rel = Path.GetFullPath(file)[(fullRoot.Length + 1)..].Replace('\\', '/');
            if (!saved.Contains(rel))
            {
                ++count;
            }
        }
        return count;
    }

    public override void SaveFile(OutputFileManifest fileManifest, string outputDir, OutputFile outputFile)
    {
        string fullOutputPath = $"{outputDir}/{outputFile.File}";
        Directory.CreateDirectory(Path.GetDirectoryName(fullOutputPath));
        string tag = File.Exists(fullOutputPath) ? "overwrite" : "new";
        if (FileUtil.WriteAllBytes(fullOutputPath, outputFile.GetContentBytes()))
        {
            s_logger.Info("[{0}] {1} ", tag, fullOutputPath);
        }
    }
}
