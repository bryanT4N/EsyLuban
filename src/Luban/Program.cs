// Copyright 2025 Code Philosophy
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

using CommandLine;
using Luban.DataLoader;
using Luban.Pipeline;
using Luban.Schema;
using Luban.Tmpl;
using Luban.Utils;
using NLog;
using System.Text;

namespace Luban;

internal static class Program
{

    private class CommandOptions
    {

        [Option('s', "schemaCollector", Required = false, HelpText = "schema collector name")]
        public string SchemaCollector { get; set; } = "default";

        [Option("conf", Required = true, HelpText = "luban conf file")]
        public string ConfigFile { get; set; }

        [Option('t', "target", Required = true, HelpText = "target name")]
        public string Target { get; set; }

        [Option('c', "codeTarget", Required = false, HelpText = "code target name")]
        public IEnumerable<string> CodeTargets { get; set; }

        [Option('d', "dataTarget", Required = false, HelpText = "data target name")]
        public IEnumerable<string> DataTargets { get; set; }

        [Option('p', "pipeline", Required = false, HelpText = "pipeline name")]
        public string Pipeline { get; set; } = "default";

        [Option('f', "forceLoadTableDatas", Required = false, HelpText = "force load table datas when not any dataTarget")]
        public bool ForceLoadTableDatas { get; set; }

        [Option('i', "includeTag", Required = false, HelpText = "include tag")]
        public IEnumerable<string> IncludeTags { get; set; }

        [Option('e', "excludeTag", Required = false, HelpText = "exclude tag")]
        public IEnumerable<string> ExcludeTags { get; set; }

        [Option("variant", Required = false, HelpText = "field variants")]
        public IEnumerable<string> Variants { get; set; }

        [Option('o', "outputTable", Required = false, HelpText = "output table")]
        public IEnumerable<string> OutputTables { get; set; }

        // [EsyLuban] 列出指定路径下的表全名后直接退出，不做任何生成。
        // 供右键菜单"局部导表"使用：先取得所选范围内的表名，再以 -o 精确导出它们。
        // 之所以不能改用 tableImporter.scanPath 一步到位 —— schema 是全局加载的，
        // 只导入所选范围会让范围外的跨表引用悬空而中止。
        [Option("listTables", Required = false, HelpText = "list full names of tables under the given file or directory, then exit")]
        public string ListTables { get; set; }

        [Option("timeZone", Required = false, HelpText = "time zone")]
        public string TimeZone { get; set; }

        [Option("customTemplateDir", Required = false, HelpText = "custom template dirs")]
        public IEnumerable<string> CustomTemplateDirs { get; set; }

        [Option("validationFailAsError", Required = false, HelpText = "validation fail as error")]
        public bool ValidationFailAsError { get; set; }

        [Option('x', "xargs", Required = false, HelpText = "args like -x a=1 -x b=2")]
        public IEnumerable<string> Xargs { get; set; }

        [Option('l', "logConfig", Required = false, Default = "nlog.xml", HelpText = "nlog config file")]
        public string LogConfig { get; set; }

        [Option('w', "watchDir", Required = false, HelpText = "watch dir and regererate when dir changes")]
        public IEnumerable<string> WatchDirs { get; set; }

        [Option('v', "verbose", Required = false, HelpText = "verbose")]
        public bool Verbose { get; set; }
    }

    private static ILogger s_logger;

    private static void Main(string[] args)
    {
        CommandOptions opts = ParseArgs(args);
        SetupApp(opts);

        if (opts.WatchDirs != null && opts.WatchDirs.Any())
        {
            RunLoop(opts, opts.WatchDirs);
        }
        else
        {
            RunOnce(opts);
        }
    }

    private static void RunOnce(CommandOptions opts)
    {
        RunGeneration(opts, true);
    }

    private static volatile bool s_anyChange = false;

    private static void RunLoop(CommandOptions opts, IEnumerable<string> watchDirs)
    {
        var watcher = new DirectoryWatcher(opts.WatchDirs.ToArray(), () => s_anyChange = true);
        s_anyChange = true;
        while (true)
        {
            if (s_anyChange)
            {
                s_anyChange = false;
                RunGeneration(opts, false);
            }
            Thread.Sleep(1000);
        }
    }

    private static void RunGeneration(CommandOptions opts, bool exitOnError)
    {
        try
        {
            IConfigLoader rootLoader = new GlobalConfigLoader();
            var config = rootLoader.Load(opts.ConfigFile);
            GenerationContext.GlobalConf = config;


            var xargs = ParseXargs(config.Xargs, opts.Xargs);
            bool listTablesOnly = !string.IsNullOrWhiteSpace(opts.ListTables);
            if (listTablesOnly)
            {
                // [EsyLuban] 借 tableImporter 的扫描范围限定"所选路径下有哪些表"
                xargs["tableImporter.scanPath"] = opts.ListTables;
            }

            var launcher = new SimpleLauncher();
            launcher.Start(xargs);
            AddCustomTemplateDirs(opts.CustomTemplateDirs);

            if (listTablesOnly)
            {
                ListTables(opts, config);
                return;
            }

            var pipeline = PipelineManager.Ins.CreatePipeline(opts.Pipeline);
            pipeline.Run(CreatePipelineArgs(opts, config));
            if (exitOnError && opts.ValidationFailAsError && GenerationContext.Current.AnyValidatorFail)
            {
                s_logger.Error("encounter some validation failure. exit code: 1");
                Environment.Exit(1);
            }
            s_logger.Info("bye~");
        }
        catch (Exception e)
        {
            PrettyPrintException(e);
            s_logger.Error("run failed!!!");
            if (exitOnError)
            {
                Environment.Exit(1);
            }
        }
    }

    /// <summary>
    /// [EsyLuban] 输出所选路径下的表全名，每行一个，然后结束。
    ///
    /// 只做 schema 收集，不编译、不校验、不生成 —— 因此即便所选范围之外存在
    /// 跨表引用也不会中止（真正导出时仍是全量加载 schema，再以 -o 精确指定输出表）。
    /// 表名写到 stdout，日志走 stderr，便于调用方直接按行读取。
    /// </summary>
    private static void ListTables(CommandOptions opts, LubanConfig config)
    {
        var collector = SchemaManager.Ins.CreateSchemaCollector(opts.SchemaCollector);
        collector.Load(config);
        foreach (var table in collector.CreateRawAssembly().Tables)
        {
            Console.WriteLine(TypeUtil.MakeFullName(table.Namespace, table.Name));
        }
    }

    private static void PrettyPrintException(Exception e)
    {
        if (TryExtractDataCreateException(e, out var dce))
        {
            s_logger.Error($"=======================================================================");
            s_logger.Error("解析失败!");
            s_logger.Error($"文件:        {dce.OriginDataLocation}");
            s_logger.Error($"错误位置:    {dce.DataLocationInFile}");
            s_logger.Error($"Err:         {dce.OriginErrorMsg}");
            s_logger.Error($"字段:        {dce.VariableFullPathStr}");
            s_logger.Error($"=======================================================================");
            return;
        }
        do
        {
            s_logger.Error("===> {}", e.Message);
            e = e.InnerException;
        } while (e != null);
    }

    private static bool TryExtractDataCreateException(Exception e, out DataCreateException extract)
    {
        if (e is DataCreateException dce)
        {
            extract = dce;
            return true;
        }

        if (e is AggregateException ae)
        {
            foreach (var innerException in ae.InnerExceptions)
            {
                if (TryExtractDataCreateException(innerException, out extract))
                {
                    return true;
                }
            }
        }

        if (e.InnerException != null)
        {
            if (TryExtractDataCreateException(e.InnerException, out extract))
            {
                return true;
            }
        }
        extract = null;
        return false;
    }

    private static void AddCustomTemplateDirs(IEnumerable<string> dirs)
    {
        foreach (var dir in dirs)
        {
            TemplateManager.Ins.AddTemplateSearchPath(dir, true, true);
        }
    }

    private static CommandOptions ParseArgs(string[] args)
    {
        var helpWriter = new StringWriter();
        var parser = new Parser(settings =>
        {
            settings.AllowMultiInstance = true;
            settings.HelpWriter = helpWriter;
        });

        var result = parser.ParseArguments<CommandOptions>(args);
        if (result.Tag == ParserResultType.NotParsed)
        {
            Console.Error.WriteLine(helpWriter.ToString());
            Environment.Exit(1);
        }
        return ((Parsed<CommandOptions>)result).Value;
    }


    private static Dictionary<string, string> ParseXargs0(IEnumerable<string> xargs)
    {
        var result = new Dictionary<string, string>();
        if (xargs == null)
        {
            return result;
        }
        foreach (var arg in xargs)
        {
            string[] pair = arg.Split('=', 2);
            if (pair.Length != 2)
            {
                throw new Exception($"invalid xargs:{arg}");
            }

            if (!result.TryAdd(pair[0], pair[1]))
            {
                throw new Exception($"duplicate xargs:{arg}");
            }
        }
        return result;
    }

    private static Dictionary<string, string> ParseXargs(IEnumerable<string> defaultXargs, IEnumerable<string> cmdXargs)
    {
        var defaultXargsMap = ParseXargs0(defaultXargs);
        var cmdXargsMap = ParseXargs0(cmdXargs);
        foreach (var kv in cmdXargsMap)
        {
            defaultXargsMap[kv.Key] = kv.Value;
        }
        return defaultXargsMap;
    }

    private static Dictionary<string, string> ParseVariants(IEnumerable<string> variants)
    {
        var result = new Dictionary<string, string>();
        if (variants == null)
        {
            return result;
        }
        foreach (var variant in variants)
        {
            string[] pair = variant.Split('=', 2);
            if (pair.Length != 2)
            {
                throw new Exception($"invalid variant:{variant}");
            }

            if (!result.TryAdd(pair[0], pair[1]))
            {
                throw new Exception($"duplicate variant:{variant}");
            }
        }
        return result;
    }

    private static PipelineArguments CreatePipelineArgs(CommandOptions opts, LubanConfig config)
    {
        return new PipelineArguments()
        {
            Target = opts.Target,
            ForceLoadTableDatas = opts.ForceLoadTableDatas,
            SchemaCollector = opts.SchemaCollector,
            Config = config,
            OutputTables = opts.OutputTables?.ToList() ?? new List<string>(),
            CodeTargets = opts.CodeTargets?.ToList() ?? new List<string>(),
            DataTargets = opts.DataTargets?.ToList() ?? new List<string>(),
            IncludeTags = opts.IncludeTags?.ToList() ?? new List<string>(),
            ExcludeTags = opts.ExcludeTags?.ToList() ?? new List<string>(),
            Variants = ParseVariants(opts.Variants),
            TimeZone = opts.TimeZone,
        };
    }

    private static void SetupApp(CommandOptions opts)
    {
        ConsoleUtil.EnableQuickEditMode(false);
        Console.OutputEncoding = Encoding.UTF8;
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);

        int processorCount = Environment.ProcessorCount;
        ThreadPool.SetMinThreads(Math.Max(4, processorCount), 0);
        ThreadPool.SetMaxThreads(Math.Max(16, processorCount * 2), 2);

        NLog.LogManager.Setup().LoadConfigurationFromFile(opts.LogConfig);
        s_logger = LogManager.GetCurrentClassLogger();

        // [EsyLuban] --listTables 的 stdout 是给调用方逐行读取的表名清单，
        // 因此 banner 与 INFO 日志不能混进去。但**只能改流向，不能丢弃**：
        // 之前这里装的是一个空 LoggingConfiguration（无 target = 全部丢弃），
        // 于是 B1 语法写错、路径不存在这类失败连一个字都不输出，调用方唯一能
        // 看到的就是「stdout 为空」。右键菜单据此打出 "No exportable tables
        // found"，把「表定义坏了」和「这里确实没有表」说成了同一件事。
        if (!string.IsNullOrWhiteSpace(opts.ListTables))
        {
            var config = new NLog.Config.LoggingConfiguration();
            var stderrTarget = new NLog.Targets.ConsoleTarget("stderr")
            {
                StdErr = true,
                Layout = "${level:uppercase=true}|${message}${onexception:${newline}${exception:format=Message}}",
            };
            config.AddRule(NLog.LogLevel.Warn, NLog.LogLevel.Fatal, stderrTarget);
            NLog.LogManager.Configuration = config;
            return;
        }

        PrintCopyRight();
    }

    private static void PrintCopyRight()
    {
        s_logger.Info(" ==========================================================================================");
        s_logger.Info("");
        s_logger.Info("  Luban is developed by Code Philosophy Technology Co., LTD. https://code-philosophy.com");
        s_logger.Info("");
        s_logger.Info(" ==========================================================================================");
    }
}
