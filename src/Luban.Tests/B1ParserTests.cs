// Copyright 2025 EZLuban
// Licensed under MIT License

using Luban.Utils;
using Xunit;

namespace Luban.Tests;

/// <summary>
/// B1Parser 单元测试
/// </summary>
public class B1ParserTests
{
    #region 正常格式测试

    [Fact]
    public void Test_Parse_MinimalFormat()
    {
        // 最小格式：仅必填字段
        string b1 = "full_name=\"TbItem\" & value_type=\"Item\"";
        var result = B1Parser.Parse(b1);

        Assert.Equal("TbItem", result["full_name"]);
        Assert.Equal("Item", result["value_type"]);
        Assert.Equal(2, result.Count);
    }

    [Fact]
    public void Test_Parse_FullFormat()
    {
        // 完整格式：所有字段
        string b1 = "full_name=\"item.TbItem\" & value_type=\"Item\" & mode=\"map\" & read_schema_from_file=\"1\" & index=\"id\" & comment=\"道具表\" & group=\"c,s\" & tags=\"priority=high#category=core\" & output=\"tbitem.bytes\"";
        var result = B1Parser.Parse(b1);

        Assert.Equal("item.TbItem", result["full_name"]);
        Assert.Equal("Item", result["value_type"]);
        Assert.Equal("map", result["mode"]);
        Assert.Equal("1", result["read_schema_from_file"]);
        Assert.Equal("id", result["index"]);
        Assert.Equal("道具表", result["comment"]);
        Assert.Equal("c,s", result["group"]);
        Assert.Equal("priority=high#category=core", result["tags"]);
        Assert.Equal("tbitem.bytes", result["output"]);
    }

    [Fact]
    public void Test_Parse_WithCommaInValue()
    {
        // 值包含逗号
        string b1 = "full_name=\"TbItem\" & value_type=\"Item\" & comment=\"道具表,包含所有道具\"";
        var result = B1Parser.Parse(b1);

        Assert.Equal("道具表,包含所有道具", result["comment"]);
    }

    [Fact]
    public void Test_Parse_WithQuoteInValue()
    {
        // 值包含引号（转义）
        string b1 = "full_name=\"TbItem\" & value_type=\"Item\" & comment=\"这是一个\\\"特殊\\\"注释\"";
        var result = B1Parser.Parse(b1);

        Assert.Equal("这是一个\"特殊\"注释", result["comment"]);
    }

    [Fact]
    public void Test_Parse_WithMultipleGroups()
    {
        // group 包含多个值（逗号分隔）
        string b1 = "full_name=\"TbItem\" & value_type=\"Item\" & group=\"c,s,e\"";
        var result = B1Parser.Parse(b1);

        Assert.Equal("c,s,e", result["group"]);
    }

    [Fact]
    public void Test_Parse_WithComplexTags()
    {
        // tags 复杂格式（#和=分隔）
        string b1 = "full_name=\"TbItem\" & value_type=\"Item\" & tags=\"priority=high#desc=测试#author=策划A\"";
        var result = B1Parser.Parse(b1);

        Assert.Equal("priority=high#desc=测试#author=策划A", result["tags"]);
    }

    [Fact]
    public void Test_Parse_WithNamespace()
    {
        // full_name 包含命名空间
        string b1 = "full_name=\"item.gear.TbWeapon\" & value_type=\"Weapon\"";
        var result = B1Parser.Parse(b1);

        Assert.Equal("item.gear.TbWeapon", result["full_name"]);
    }

    [Fact]
    public void Test_Parse_WithUnicodeCharacters()
    {
        // Unicode 字符
        string b1 = "full_name=\"TbItem\" & value_type=\"Item\" & comment=\"道具🎮配置表\"";
        var result = B1Parser.Parse(b1);

        Assert.Equal("道具🎮配置表", result["comment"]);
    }

    #endregion

    #region 错误格式测试

    [Fact]
    public void Test_Parse_MissingFullName()
    {
        // 缺少 full_name
        string b1 = "value_type=\"Item\"";

        var exception = Assert.Throws<Exception>(() => B1Parser.Parse(b1));
        Assert.Contains("full_name", exception.Message);
    }

    [Fact]
    public void Test_Parse_ValueTypeIsOptional()
    {
        // value_type 可省略：由调用方按表名推导（TbItem -> Item）。
        // full_name 是 B1 唯一必填项。
        string b1 = "full_name=\"TbItem\"";

        var result = B1Parser.Parse(b1);

        Assert.Equal("TbItem", result["full_name"]);
        Assert.False(result.ContainsKey("value_type"));
    }

    [Fact]
    public void Test_Parse_InvalidFormat_NoEquals()
    {
        // 缺少 = 号
        string b1 = "full_name\"TbItem\" & value_type=\"Item\"";

        var exception = Assert.Throws<Exception>(() => B1Parser.Parse(b1));
        Assert.Contains("missing '='", exception.Message);
    }

    [Fact]
    public void Test_Parse_InvalidFormat_UnmatchedQuote()
    {
        // 引号未闭合
        string b1 = "full_name=\"TbItem & value_type=\"Item\"";

        var exception = Assert.Throws<Exception>(() => B1Parser.Parse(b1));
        Assert.Contains("quote", exception.Message);
    }

    [Fact]
    public void Test_Parse_EmptyContent()
    {
        // 空内容
        string b1 = "";

        var exception = Assert.Throws<Exception>(() => B1Parser.Parse(b1));
        Assert.Contains("empty", exception.Message);
    }

    [Fact]
    public void Test_Parse_WhitespaceOnly()
    {
        // 仅空白
        string b1 = "   ";

        var exception = Assert.Throws<Exception>(() => B1Parser.Parse(b1));
        Assert.Contains("empty", exception.Message);
    }

    #endregion

    #region 边界情况测试

    [Fact]
    public void Test_Parse_EmptyValue()
    {
        // 值为空字符串
        string b1 = "full_name=\"TbItem\" & value_type=\"Item\" & comment=\"\"";
        var result = B1Parser.Parse(b1);

        Assert.Equal("", result["comment"]);
    }

    [Fact]
    public void Test_Parse_WhitespaceHandling()
    {
        // 前后空格应被正确处理
        string b1 = "  full_name = \"TbItem\"  &  value_type = \"Item\"  ";
        var result = B1Parser.Parse(b1);

        Assert.Equal("TbItem", result["full_name"]);
        Assert.Equal("Item", result["value_type"]);
    }

    [Fact]
    public void Test_Parse_ValueWithoutQuotes()
    {
        // 值不带引号
        string b1 = "full_name=\"TbItem\" & value_type=\"Item\" & mode=map";
        var result = B1Parser.Parse(b1);

        Assert.Equal("map", result["mode"]);
    }

    [Fact]
    public void Test_Parse_MultipleAmpersandInValue()
    {
        // 值中包含多个 & (需要引号包裹)
        string b1 = "full_name=\"TbItem\" & value_type=\"Item\" & comment=\"A & B & C\"";
        var result = B1Parser.Parse(b1);

        Assert.Equal("A & B & C", result["comment"]);
    }

    [Fact]
    public void Test_Parse_BackslashInValue()
    {
        // 值包含反斜杠
        string b1 = "full_name=\"TbItem\" & value_type=\"Item\" & comment=\"路径\\\\是C:\\\\Data\"";
        var result = B1Parser.Parse(b1);

        Assert.Equal("路径\\是C:\\Data", result["comment"]);
    }

    [Fact]
    public void Test_Parse_EqualsInValue()
    {
        // 值包含 = 号（在引号内）
        string b1 = "full_name=\"TbItem\" & value_type=\"Item\" & comment=\"公式: a=b+c\"";
        var result = B1Parser.Parse(b1);

        Assert.Equal("公式: a=b+c", result["comment"]);
    }

    [Fact]
    public void Test_Parse_NewlineInValue()
    {
        // 值包含换行（少见但可能）
        string b1 = "full_name=\"TbItem\" & value_type=\"Item\" & comment=\"第一行\\n第二行\"";
        var result = B1Parser.Parse(b1);

        Assert.Contains("\\n", result["comment"]);
    }

    [Fact]
    public void Test_Parse_SingleFieldOnly()
    {
        // 单个字段（不符合最小要求）
        string b1 = "full_name=\"TbItem\"";

        var exception = Assert.Throws<Exception>(() => B1Parser.Parse(b1));
        Assert.Contains("value_type", exception.Message);
    }

    [Fact]
    public void Test_Parse_CaseSensitiveKeys()
    {
        // 键名区分大小写
        string b1 = "full_name=\"TbItem\" & value_type=\"Item\" & Full_Name=\"TbItem2\"";
        var result = B1Parser.Parse(b1);

        Assert.Equal("TbItem", result["full_name"]);
        Assert.Equal("TbItem2", result["Full_Name"]); // 不同的键
    }

    [Fact]
    public void Test_Parse_DuplicateKeys()
    {
        // 重复的键（后者覆盖前者）
        string b1 = "full_name=\"TbItem\" & value_type=\"Item\" & comment=\"第一次\" & comment=\"第二次\"";
        var result = B1Parser.Parse(b1);

        Assert.Equal("第二次", result["comment"]); // 覆盖
    }

    #endregion

    #region 实际使用场景测试

    [Fact]
    public void Test_Parse_RealWorld_Minimal()
    {
        // 实际场景：最简配置
        string b1 = "full_name=\"TbItem\" & value_type=\"Item\"";
        var result = B1Parser.Parse(b1);

        Assert.True(result.ContainsKey("full_name"));
        Assert.True(result.ContainsKey("value_type"));
    }

    [Fact]
    public void Test_Parse_RealWorld_Common()
    {
        // 实际场景：常见配置
        string b1 = "full_name=\"item.TbItem\" & value_type=\"Item\" & mode=\"map\" & read_schema_from_file=\"1\" & comment=\"道具配置表\"";
        var result = B1Parser.Parse(b1);

        Assert.Equal(5, result.Count);
        Assert.Equal("item.TbItem", result["full_name"]);
        Assert.Equal("1", result["read_schema_from_file"]);
    }

    [Fact]
    public void Test_Parse_RealWorld_Complex()
    {
        // 实际场景：复杂配置（带标签和分组）
        string b1 = "full_name=\"item.TbItem\" & value_type=\"Item\" & group=\"c,s\" & tags=\"priority=high#category=gameplay#module=inventory\" & comment=\"道具系统核心配置表\"";
        var result = B1Parser.Parse(b1);

        Assert.Contains("tags", result.Keys);
        Assert.Contains("#", result["tags"]);
    }

    #endregion
}
