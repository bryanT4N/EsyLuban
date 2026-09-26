// Copyright 2026 EsyLuban
// Licensed under MIT License

using Luban.Defs;
using Luban.Diagnostics;
using Luban.RawDefs;
using Luban.Schema;
using Luban.Schema.Builtin;
using Luban.Utils;
using Xunit;

namespace Luban.Tests;

/// <summary>
/// 同名 B1 表只能是同一张表的几个变体：一份默认版、变体名不重复、output/mode/index 一致。
/// </summary>
public class B1VariantTests
{
    private static RawTable Def(string sheet, string variant = "", TableMode mode = TableMode.MAP, string index = "", string output = "")
        => new()
        {
            Namespace = "item",
            Name = "TbItem",
            Variants = DefUtil.ParseVariant(variant),
            Mode = mode,
            Index = index,
            OutputFile = output,
            Source = SchemaSource.Create("items.xlsx", sheet),
        };

    private static EsyLubanException Rejected(params RawTable[] tables)
        => Assert.Throws<EsyLubanException>(() => SelfContainedTableImporter.CheckVariants(tables));

    [Fact]
    public void DefaultAndVariantsOfTheSameShape_Pass()
    {
        SelfContainedTableImporter.CheckVariants(new[] { Def("Default"), Def("En", "en"), Def("JpKr", "jp,kr") });
    }

    // 只有变体、没有默认版在这里不算错：不带 --variant 导出时由上游报 variant_not_set
    [Fact]
    public void VariantsWithoutADefault_PassHere()
    {
        SelfContainedTableImporter.CheckVariants(new[] { Def("En", "en"), Def("Jp", "jp") });
    }

    [Fact]
    public void TwoDefaults_NameEveryPlace()
    {
        var e = Rejected(Def("A"), Def("B"), Def("En", "en"));
        Assert.Equal("esyluban.b1.duplicate_full_name", e.MessageKey);
        Assert.Equal("A@items.xlsx, B@items.xlsx", (string)e.Args[2]);
    }

    [Fact]
    public void TheSameVariantTwice_IsRejected()
    {
        var e = Rejected(Def("Default"), Def("En", "en"), Def("JpEn", "jp,en"));
        Assert.Equal("esyluban.b1.duplicate_variant", e.MessageKey);
        Assert.Equal("en", (string)e.Args[1]);
        Assert.Equal("En@items.xlsx, JpEn@items.xlsx", (string)e.Args[3]);
    }

    [Theory]
    [InlineData("mode")]
    [InlineData("index")]
    [InlineData("output")]
    public void AVariantOfADifferentShape_IsRejected(string key)
    {
        var variant = key switch
        {
            "mode" => Def("En", "en", mode: TableMode.LIST),
            "index" => Def("En", "en", index: "name"),
            _ => Def("En", "en", output: "tbitem_en"),
        };
        var e = Rejected(Def("Default"), variant);
        Assert.Equal("esyluban.b1.variant_mismatch", e.MessageKey);
        Assert.Equal(key, (string)e.Args[1]);
    }

    // 没写的缺省值要到读了表头才知道，这里比的是写法：一份没写、一份写了，就算不一致
    [Fact]
    public void LeavingIndexOutWhileAVariantWritesIt_IsRejected()
    {
        var e = Rejected(Def("Default"), Def("En", "en", index: "id"));
        Assert.Equal("esyluban.b1.variant_mismatch", e.MessageKey);
        Assert.Equal("Default@items.xlsx='', En@items.xlsx='id'", (string)e.Args[2]);
    }

    // 一张 sheet 里写两遍 en 留给上游报：列在这里会是同一处两遍
    [Fact]
    public void AVariantRepeatedWithinOneSheet_IsLeftToUpstream()
    {
        SelfContainedTableImporter.CheckVariants(new[] { Def("Default"), Def("En", "en,en") });
    }

    [Fact]
    public void DifferentTablesDoNotCountAsVariants()
    {
        var other = Def("Other");
        other.Name = "TbOther";
        SelfContainedTableImporter.CheckVariants(new[] { Def("Default"), other });
    }
}
