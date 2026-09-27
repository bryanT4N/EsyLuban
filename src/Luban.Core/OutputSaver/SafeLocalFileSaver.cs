// Copyright 2025 EsyLuban
// Licensed under MIT License

using Luban.Diagnostics;
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

    // 变体的数据放在默认版的数据目录下，一个变体一个子目录
    protected override string GetOutputDir(OutputFileManifest manifest)
    {
        string dir = base.GetOutputDir(manifest);
        return manifest.OutputType == OutputType.Data && VariantFolders.IsVariantRun
            ? $"{dir}/{VariantFolders.Current}"
            : dir;
    }

    protected override void BeforeSave(OutputFileManifest outputFileManifest, string outputDir)
    {
        if (!EnvManager.Current.GetBoolOptionOrDefault($"{BuiltinOptionNames.OutputSaver}.{outputFileManifest.TargetName}", BuiltinOptionNames.CleanUpOutputDir,
                true, true))
        {
            return;
        }

        var savedFiles = outputFileManifest.DataFiles.Select(f => f.File).ToList();
        // 默认版那一遍不清各变体的子目录，它们由各自那一遍清理
        var keptFiles = outputFileManifest.OutputType == OutputType.Data
            ? savedFiles.Concat(VariantFiles(outputDir)).ToList()
            : savedFiles;
        if (!IsCleanupSane(outputDir, savedFiles.Count, keptFiles, outputFileManifest.TargetName))
        {
            return;
        }
        FileCleaner.Clean(outputDir, keptFiles);
    }

    private static IEnumerable<string> VariantFiles(string outputDir)
    {
        if (VariantFolders.IsVariantRun)
        {
            yield break;
        }
        string fullRoot = Path.GetFullPath(outputDir);
        foreach (string variant in VariantFolders.Declared)
        {
            string variantDir = Path.Combine(fullRoot, variant);
            if (!Directory.Exists(variantDir))
            {
                continue;
            }
            foreach (string file in Directory.GetFiles(variantDir, "*", SearchOption.AllDirectories))
            {
                yield return Path.GetRelativePath(fullRoot, file).Replace('\\', '/');
            }
        }
    }

    private static bool IsCleanupSane(string outputDir, int produced, List<string> keptFiles, string targetName)
    {
        if (EnvManager.Current.GetBoolOptionOrDefault("", ForceCleanUpOutputDir, true, false))
        {
            return true;
        }
        if (!Directory.Exists(outputDir))
        {
            return true;
        }

        int toDelete = CountDoomedFiles(outputDir, keptFiles);
        if (toDelete == 0)
        {
            return true;
        }

        // 一个产物都没有却要删东西 —— 几乎总是 group 过滤把表全滤掉了，
        // 而不是"这个目录该空了"。
        if (produced == 0)
        {
            s_logger.Warn(EsyMessages.CleanupNoOutput.Format(targetName, toDelete));
            return false;
        }

        // 删得比产出的还多，说明这个目录里主要是别人的东西。
        if (toDelete > produced)
        {
            s_logger.Warn(EsyMessages.CleanupTooMany.Format(targetName, toDelete, produced));
            return false;
        }
        return true;
    }

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
