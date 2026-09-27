// Copyright 2026 EsyLuban
// Licensed under MIT License

using Luban.DataLoader;
using Luban.Datas;
using Luban.Defs;
using Luban.Diagnostics;
using Luban.RawDefs;
using Luban.Types;
using Luban.Utils;

namespace Luban.L10N;

/// <summary>
/// [EsyLuban] 文本表的多语言版本。默认语言那一遍和上游 DefaultTextProvider 一样；其它语言那一遍
/// 再读 variant_&lt;语言&gt; 文件夹里的文本表，同一个 key 覆盖默认版，新 key 追加。哪些文件算
/// 默认版、哪些算差异，见 LanguageVariants.TextFiles。
///
/// 上游读文本表的代码是私有的，而且 textFile.path 写成目录时会把 variant_ 文件夹里的文本表
/// 也当成默认版读进来、报一串重复 key，所以这里整个接管 "default"，读表部分照抄上游。
/// 跟进上游时 DefaultTextProvider 有改动，这里要跟着改。
/// </summary>
[TextProvider("default", Priority = 100)]
public class LanguageTextProvider : ITextProvider
{
    private static readonly NLog.Logger s_logger = NLog.LogManager.GetCurrentClassLogger();

    private string _keyFieldName;
    private string _valueFieldName;

    private bool _convertTextKeyToValue;

    private readonly Dictionary<string, string> _texts = new();

    private readonly HashSet<string> _unknownTextKeys = new();

    public void Load()
    {
        EnvManager env = EnvManager.Current;

        _keyFieldName = env.GetOptionOrDefault(BuiltinOptionNames.L10NFamily, BuiltinOptionNames.L10NTextFileKeyFieldName, false, "");
        if (string.IsNullOrWhiteSpace(_keyFieldName))
        {
            throw new LubanException("error.l10n.missing_key_field", BuiltinOptionNames.L10NFamily, BuiltinOptionNames.L10NTextFileKeyFieldName);
        }

        _convertTextKeyToValue = DataUtil.ParseBool(env.GetOptionOrDefault(BuiltinOptionNames.L10NFamily, BuiltinOptionNames.L10NConvertTextKeyToValue, false, "false"));
        if (_convertTextKeyToValue)
        {
            _valueFieldName = env.GetOptionOrDefault(BuiltinOptionNames.L10NFamily, BuiltinOptionNames.L10NTextFileLanguageFieldName, false, "");
            if (string.IsNullOrWhiteSpace(_valueFieldName))
            {
                throw new LubanException("error.l10n.missing_language_field", BuiltinOptionNames.L10NFamily, BuiltinOptionNames.L10NTextFileLanguageFieldName);
            }
        }

        string textFiles = env.GetOption(BuiltinOptionNames.L10NFamily, BuiltinOptionNames.L10NTextFilePath, false);
        var (defaults, overlays) = LanguageVariants.TextFiles(textFiles, LanguageVariants.IsVariantRun ? LanguageVariants.Current : null);
        var recordType = CreateRecordType();
        foreach (string file in defaults)
        {
            LoadTexts(recordType, file, null);
        }
        var overlaid = new HashSet<string>();
        foreach (string file in overlays)
        {
            LoadTexts(recordType, file, overlaid);
        }
    }

    public bool ConvertTextKeyToValue => _convertTextKeyToValue;

    public bool IsValidKey(string key)
    {
        return _texts.ContainsKey(key);
    }

    public bool TryGetText(string key, out string text)
    {
        return _texts.TryGetValue(key, out text);
    }

    private TBean CreateRecordType()
    {
        var ass = new DefAssembly(new RawAssembly()
        {
            Targets = new List<RawTarget> { new() { Name = "default", Manager = "Tables" } },
        }, "default", new List<string>(), null, null);

        var rawFields = new List<RawField> { new() { Name = _keyFieldName, Type = "string" }, };
        if (_convertTextKeyToValue)
        {
            rawFields.Add(new() { Name = _valueFieldName, Type = "string" });
        }
        var defTableRecordType = new DefBean(new RawBean()
        {
            Namespace = "__intern__",
            Name = "__TextInfo__",
            Parent = "",
            Alias = "",
            IsValueType = false,
            Sep = "",
            Fields = rawFields,
        })
        {
            Assembly = ass,
        };

        ass.AddType(defTableRecordType);
        defTableRecordType.PreCompile();
        defTableRecordType.Compile();
        defTableRecordType.PostCompile();
        return TBean.Create(false, defTableRecordType, null);
    }

    /// <summary>
    /// 读一个文本表文件。默认版里 key 重复算错，先出现的生效；差异里的 key 覆盖默认版，
    /// 同一种语言的差异里 key 重复同样算错。
    /// </summary>
    private void LoadTexts(TBean recordType, string atomFile, HashSet<string> overlaid)
    {
        var (actualFile, sheetName) = FileUtil.SplitFileAndSheetName(FileUtil.Standardize(atomFile));
        foreach (var record in DataLoaderManager.Ins.LoadTableFile(recordType, actualFile, sheetName, new Dictionary<string, string>()))
        {
            DBean data = record.Data;

            string key = ((DString)data.GetField(_keyFieldName)).Value;
            string value = _convertTextKeyToValue ? ((DString)data.GetField(_valueFieldName)).Value : key;
            if (string.IsNullOrEmpty(key))
            {
                s_logger.Error(MessageCatalog.Format("error.l10n.empty_key", atomFile, key));
                continue;
            }
            bool duplicate = overlaid == null ? _texts.ContainsKey(key) : !overlaid.Add(key);
            if (duplicate)
            {
                s_logger.Error(MessageCatalog.Format("error.l10n.duplicate_key", atomFile, key));
                continue;
            }
            _texts[key] = value;
        }
    }

    public void AddUnknownKey(string key)
    {
        _unknownTextKeys.Add(key);
    }

    public void ProcessDatas()
    {
        if (_convertTextKeyToValue)
        {
            var trans = new TextKeyToValueTransformer(this);
            foreach (var table in GenerationContext.Current.Tables)
            {
                foreach (var record in GenerationContext.Current.GetTableAllDataList(table))
                {
                    record.Data = (DBean)record.Data.Apply(trans, table.ValueTType);
                }
            }
        }
    }
}
