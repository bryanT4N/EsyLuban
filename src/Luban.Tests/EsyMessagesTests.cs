// Copyright 2026 EsyLuban
// Licensed under MIT License

using System.Reflection;
using System.Text.RegularExpressions;
using Luban.Diagnostics;
using Luban.Schema;
using Xunit;

namespace Luban.Tests;

// 断言别依赖语言：别的测试类会并行调用 MessageCatalog.Init("en")，而它改的是全局状态，
// 这里拿到的是中文还是英文取决于调度。所以只比码、参数和两种语言都有的片段。
public class EsyMessagesTests
{
    private static List<EsyMessage> AllMessages() => typeof(EsyMessages)
        .GetFields(BindingFlags.Public | BindingFlags.Static)
        .Select(f => (EsyMessage)f.GetValue(null))
        .ToList();

    private static string Placeholders(string template) => string.Join(",",
        Regex.Matches(template, @"\{(\d+)\}").Select(m => m.Groups[1].Value).Distinct().OrderBy(n => n));

    // 英文模板少一个 {2}，英文系统上这条报错就缺一块，而在中文开发机上永远看不出来
    [Fact]
    public void EveryMessage_HasAUniqueCodeAndTheSamePlaceholdersInBothLanguages()
    {
        var messages = AllMessages();
        Assert.NotEmpty(messages);
        Assert.Equal(messages.Count, messages.Select(m => m.Code).Distinct().Count());
        var args = Enumerable.Range(0, 8).Select(i => (object)$"arg{i}").ToArray();
        foreach (var m in messages)
        {
            Assert.StartsWith("esyluban.", m.Code);
            Assert.Equal(Placeholders(m.Zh), Placeholders(m.En));
            // 模板里落单的 { 会在报错那一刻抛 FormatException，把真正的错误盖掉
            string.Format(m.Zh, args);
            string.Format(m.En, args);
        }
    }

    [Fact]
    public void Exception_CarriesCodeArgsAndLocationIntoTheJsonReport()
    {
        var source = SchemaSource.Create("DataTables/item.xlsx", "Sheet1");
        var report = DiagnosticReport.FromException(new EsyLubanException(EsyMessages.B1BadMode, source, "dict"));

        var item = Assert.Single(report.Errors);
        Assert.Equal("esyluban.b1.bad_mode", item.Code);
        Assert.Equal(new[] { "dict" }, item.Args);
        Assert.Equal("DataTables/item.xlsx", item.File);
        Assert.Equal("Sheet1", item.Location);
        // 是模板填出来的文字，不是基类查不到码时的「码: 参数」
        Assert.Contains("'dict'", item.Message);
        Assert.DoesNotContain("esyluban.", item.Message);
    }

    [Fact]
    public void ImportFailed_KeepsTheUnderlyingReasonAsTheNextItem()
    {
        var inner = new IOException("file is locked");
        var report = DiagnosticReport.FromException(
            new EsyLubanException(inner, EsyMessages.ImportFailed, SchemaSource.Create("DataTables/item.xlsx")));

        Assert.Equal(2, report.Errors.Count);
        Assert.Equal("esyluban.import.failed", report.Errors[0].Code);
        Assert.Equal("DataTables/item.xlsx", report.Errors[0].File);
        Assert.Equal("file is locked", report.Errors[1].Message);
    }
}
