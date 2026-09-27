// Copyright 2026 EsyLuban
// Licensed under MIT License

using Xunit;
using static Luban.Schema.Builtin.SelfContainedTableImporter;

namespace Luban.Tests;

/// <summary>
/// A1 的写法：哪些导出，哪些不吭声地跳过，哪些算写错、要告警。
/// </summary>
public class A1MarkerTests
{
    [Theory]
    [InlineData("##export")]
    [InlineData("##Export")]
    [InlineData("##EXPORT")]
    [InlineData("  ##export  ")]
    [InlineData("##export=true")]
    [InlineData("##Export=TRUE")]
    public void Exports(string a1) => Assert.Equal(A1Marker.Export, ClassifyA1(a1));

    [Theory]
    [InlineData("##export=false")]
    [InlineData("##Export=FALSE")]
    [InlineData("##var")]
    [InlineData("##")]
    [InlineData("")]
    [InlineData("export")]
    [InlineData("道具表")]
    public void SkipsQuietly(string a1) => Assert.Equal(A1Marker.Skip, ClassifyA1(a1));

    // 写的人想导出，却写错了。以前只认 ## 开头的，少一个 # 的 #export 会悄悄跳过
    [Theory]
    [InlineData("#export")]
    [InlineData("#Export")]
    [InlineData("# export")]
    [InlineData("##exportt")]
    [InlineData("## export")]
    [InlineData("##export=1")]
    [InlineData("##export=yes")]
    [InlineData("###export")]
    public void WarnsOnTypos(string a1) => Assert.Equal(A1Marker.Bad, ClassifyA1(a1));
}
