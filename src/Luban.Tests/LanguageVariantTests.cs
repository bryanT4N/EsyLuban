// Copyright 2026 EsyLuban
// Licensed under MIT License

using Luban.Defs;
using Luban.Diagnostics;
using Luban.RawDefs;
using Luban.Schema;
using Luban.Schema.Builtin;
using Xunit;

namespace Luban.Tests;

/// <summary>
/// 多语言版本：l10n.languages 的写法、variant_ 文件夹怎么认、差异那份怎么对上默认版。
/// </summary>
public class LanguageVariantTests
{
    private static readonly string s_dataDir = Path.Combine(Path.GetTempPath(), "esyluban-data");

    private static string Data(string relative) => Path.Combine(s_dataDir, relative);

    private static RawTable Def(string sheet, string name = "TbItem", TableMode mode = TableMode.MAP, string index = "", string output = "")
        => new()
        {
            Namespace = "item",
            Name = name,
            Mode = mode,
            Index = index,
            OutputFile = output,
            InputFiles = new List<string> { $"{sheet}@items.xlsx" },
            Source = SchemaSource.Create("items.xlsx", sheet),
        };

    [Fact]
    public void Languages_AreTrimmedAndTheFirstIsTheDefault()
    {
        Assert.Equal(new[] { "zh", "en", "ja" }, LanguageVariants.Parse(" zh, en ,,ja "));
        Assert.Empty(LanguageVariants.Parse(""));
    }

    [Fact]
    public void Languages_ListedTwice_AreRejected()
    {
        var e = Assert.Throws<EsyLubanException>(() => LanguageVariants.Parse("zh,en,zh"));
        Assert.Equal("esyluban.l10n.duplicate_language", e.MessageKey);
    }

    [Fact]
    public void VariantFolders_AreRecognisedAtAnyDepth()
    {
        Assert.Null(LanguageVariants.VariantFolderOf(s_dataDir, Data("shop/shop.xlsx")));
        Assert.Equal("en", LanguageVariants.VariantFolderOf(s_dataDir, Data("shop/variant_en/shop.xlsx")));
        Assert.Equal("en", LanguageVariants.VariantFolderOf(s_dataDir, Data("variant_en/shop/shop.xlsx")));
        // 前缀不分大小写，语言名原样返回，之后再和 l10n.languages 比对
        Assert.Equal("EN", LanguageVariants.VariantFolderOf(s_dataDir, Data("Variant_EN/shop.xlsx")));
        // 只看目录名：文件自己叫 variant_ 开头不算
        Assert.Null(LanguageVariants.VariantFolderOf(s_dataDir, Data("shop/variant_en.xlsx")));
    }

    [Fact]
    public void VariantFolders_CannotBeNested()
    {
        var e = Assert.Throws<EsyLubanException>(() => LanguageVariants.VariantFolderOf(s_dataDir, Data("variant_en/variant_ja/shop.xlsx")));
        Assert.Equal("esyluban.variant.nested", e.MessageKey);
    }

    [Fact]
    public void TwoDefaultsWithOneName_NameEveryPlace()
    {
        var e = Assert.Throws<EsyLubanException>(() => SelfContainedTableImporter.CheckDuplicates(new[] { Def("A"), Def("B") }));
        Assert.Equal("esyluban.b1.duplicate_full_name", e.MessageKey);
        Assert.Equal("A@items.xlsx, B@items.xlsx", (string)e.Args[2]);

        SelfContainedTableImporter.CheckDuplicates(new[] { Def("A"), Def("B", name: "TbOther") });
    }

    // 没声明 l10n.languages 时 variant_ 是普通文件夹，忘了声明的人撞上的就是这条报错
    [Fact]
    public void TheDuplicateNameError_SaysToDeclareTheLanguage()
    {
        Assert.Contains("l10n.languages", EsyMessages.B1DuplicateFullName.Zh);
        Assert.Contains("l10n.languages", EsyMessages.B1DuplicateFullName.En);
    }

    [Fact]
    public void VariantFolderLanguages_MustBeDeclared()
    {
        var declared = new List<string> { "zh", "en" };
        SelfContainedTableImporter.CheckDeclared(new[] { "en", "en" }, declared);

        var e = Assert.Throws<EsyLubanException>(() => SelfContainedTableImporter.CheckDeclared(new[] { "en", "fr" }, declared));
        Assert.Equal("esyluban.variant.undeclared_language", e.MessageKey);
        Assert.Equal("fr", (string)e.Args[0]);
    }

    // 默认语言那一遍不读任何 variant_ 文件夹，variant_zh 里改了也没效果
    [Fact]
    public void AFolderForTheDefaultLanguage_IsRejected()
    {
        var e = Assert.Throws<EsyLubanException>(() => SelfContainedTableImporter.CheckDeclared(new[] { "zh" }, new List<string> { "zh", "en" }));
        Assert.Equal("esyluban.variant.default_language", e.MessageKey);
    }

    [Fact]
    public void Overlays_MatchTheirDefaultByFullName()
    {
        var matched = SelfContainedTableImporter.MatchOverlays(new List<RawTable> { Def("Default") }, new[] { Def("En") }, "en");
        var (fullName, overlay) = Assert.Single(matched);
        Assert.Equal("item.TbItem", fullName);
        Assert.Equal("En@items.xlsx", overlay.Source.Display);
    }

    // 某种语言独有的表要在默认版里先建一张空表，各语言的代码才一样
    [Fact]
    public void AnOverlayWithoutADefault_IsRejectedWithItsLocation()
    {
        var e = Assert.Throws<EsyLubanException>(() =>
            SelfContainedTableImporter.MatchOverlays(new List<RawTable> { Def("Default") }, new[] { Def("En", name: "TbEvent") }, "en"));
        Assert.Equal("esyluban.variant.no_default", e.MessageKey);
        Assert.Equal("En", e.SchemaOrigin.Sheet);
    }

    [Theory]
    [InlineData("mode")]
    [InlineData("index")]
    [InlineData("output")]
    public void AnOverlayOfADifferentShape_IsRejected(string key)
    {
        var overlay = key switch
        {
            "mode" => Def("En", mode: TableMode.LIST),
            "index" => Def("En", index: "name"),
            _ => Def("En", output: "tbitem_en"),
        };
        var e = Assert.Throws<EsyLubanException>(() =>
            SelfContainedTableImporter.MatchOverlays(new List<RawTable> { Def("Default") }, new[] { overlay }, "en"));
        Assert.Equal("esyluban.b1.variant_mismatch", e.MessageKey);
        Assert.Equal(key, (string)e.Args[2]);
    }

    // 没写的缺省值要到读了表头才知道，这里比的是写法：一份没写、一份写了，就算不一致
    [Fact]
    public void LeavingIndexOutWhileTheOverlayWritesIt_IsRejected()
    {
        var e = Assert.Throws<EsyLubanException>(() =>
            SelfContainedTableImporter.MatchOverlays(new List<RawTable> { Def("Default") }, new[] { Def("En", index: "id") }, "en"));
        Assert.Equal("Default@items.xlsx='', En@items.xlsx='id'", (string)e.Args[3]);
    }
}
