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
/// 变体：esyluban.variants 的写法、variant_ 文件夹怎么认、差异那份怎么对上默认版。
/// </summary>
public class VariantFolderTests
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
    public void Variants_AreTrimmed()
    {
        Assert.Equal(new[] { "en", "ja" }, VariantFolders.Parse(" en ,,ja "));
        Assert.Empty(VariantFolders.Parse(""));
    }

    [Fact]
    public void Variants_ListedTwice_AreRejected()
    {
        var e = Assert.Throws<EsyLubanException>(() => VariantFolders.Parse("en,ja,en"));
        Assert.Equal("esyluban.variant.duplicate", e.MessageKey);
    }

    [Fact]
    public void VariantFolders_AreRecognisedAtAnyDepth()
    {
        Assert.Null(VariantFolders.VariantFolderOf(s_dataDir, Data("shop/shop.xlsx")));
        Assert.Equal("en", VariantFolders.VariantFolderOf(s_dataDir, Data("shop/variant_en/shop.xlsx")));
        Assert.Equal("en", VariantFolders.VariantFolderOf(s_dataDir, Data("variant_en/shop/shop.xlsx")));
        // 前缀不分大小写，变体名原样返回，之后再和 esyluban.variants 比对
        Assert.Equal("EN", VariantFolders.VariantFolderOf(s_dataDir, Data("Variant_EN/shop.xlsx")));
        // 只看目录名：文件自己叫 variant_ 开头不算
        Assert.Null(VariantFolders.VariantFolderOf(s_dataDir, Data("shop/variant_en.xlsx")));
    }

    [Fact]
    public void VariantFolders_CannotBeNested()
    {
        var e = Assert.Throws<EsyLubanException>(() => VariantFolders.VariantFolderOf(s_dataDir, Data("variant_en/variant_ja/shop.xlsx")));
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

    // 没声明 esyluban.variants 时 variant_ 是普通文件夹，忘了声明的人撞上的就是这条报错
    [Fact]
    public void TheDuplicateNameError_SaysToDeclareTheVariant()
    {
        Assert.Contains("esyluban.variants", EsyMessages.B1DuplicateFullName.Zh);
        Assert.Contains("esyluban.variants", EsyMessages.B1DuplicateFullName.En);
    }

    [Fact]
    public void VariantFolders_MustBeDeclared()
    {
        var declared = new List<string> { "en" };
        SelfContainedTableImporter.CheckDeclared(new[] { "en", "en" }, declared);

        var e = Assert.Throws<EsyLubanException>(() => SelfContainedTableImporter.CheckDeclared(new[] { "en", "fr" }, declared));
        Assert.Equal("esyluban.variant.undeclared", e.MessageKey);
        Assert.Equal("fr", (string)e.Args[0]);
    }

    [Fact]
    public void Overlays_MatchTheirDefaultByFullName()
    {
        var matched = SelfContainedTableImporter.MatchOverlays(new List<RawTable> { Def("Default") }, new[] { Def("En") }, "en");
        var (fullName, overlay) = Assert.Single(matched);
        Assert.Equal("item.TbItem", fullName);
        Assert.Equal("En@items.xlsx", overlay.Source.Display);
    }

    // 只有某个版本才有的表要在默认版里先建一张空表，各版本的代码才一样
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
