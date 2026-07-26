// Copyright 2025 EZLuban
// Licensed under MIT License

using System.Text;

namespace Luban.Utils;

/// <summary>
/// B1 格式解析器
/// 解析格式: field1="value1" &amp; field2="value2" &amp; field3="value3"
/// </summary>
public static class B1Parser
{
    /// <summary>
    /// 解析 B1 元数据字符串
    /// </summary>
    /// <param name="b1Content">B1 单元格内容</param>
    /// <returns>字段名到值的映射</returns>
    /// <exception cref="Exception">格式错误时抛出异常</exception>
    public static Dictionary<string, string> Parse(string b1Content)
    {
        if (string.IsNullOrWhiteSpace(b1Content))
        {
            throw new Exception("B1 content is empty");
        }

        var result = new Dictionary<string, string>();

        // 按 " & " 分割字段（注意两端的空格）
        var fields = SplitByDelimiterWithQuotes(b1Content, " & ");

        foreach (var field in fields)
        {
            if (string.IsNullOrWhiteSpace(field)) continue;

            // 查找 = 的位置
            int equalsIndex = FindUnquotedEquals(field);
            if (equalsIndex < 0)
            {
                throw new Exception($"Invalid field format (missing '='): {field}");
            }

            // 提取键和值
            string key = field.Substring(0, equalsIndex).Trim();
            string value = field.Substring(equalsIndex + 1).Trim();

            if (string.IsNullOrWhiteSpace(key))
            {
                throw new Exception($"Empty key in field: {field}");
            }

            // 去除值两端的引号并处理转义
            value = UnescapeValue(value);

            result[key] = value;
        }

        // 验证必填字段
        ValidateRequiredFields(result);

        return result;
    }

    /// <summary>
    /// 按分隔符分割字符串，忽略引号内的分隔符
    /// </summary>
    private static string[] SplitByDelimiterWithQuotes(string content, string delimiter)
    {
        var result = new List<string>();
        var buffer = new StringBuilder();
        bool inQuote = false;
        bool inEscape = false;

        for (int i = 0; i < content.Length; i++)
        {
            char c = content[i];

            // 处理转义
            if (inEscape)
            {
                buffer.Append(c);
                inEscape = false;
                continue;
            }

            if (c == '\\')
            {
                inEscape = true;
                buffer.Append(c);
                continue;
            }

            // 处理引号
            if (c == '"')
            {
                inQuote = !inQuote;
                buffer.Append(c);
                continue;
            }

            // 检查分隔符（仅在引号外）
            if (!inQuote && StartsWithDelimiter(content, i, delimiter))
            {
                result.Add(buffer.ToString());
                buffer.Clear();
                i += delimiter.Length - 1;  // 跳过分隔符
                continue;
            }

            buffer.Append(c);
        }

        if (buffer.Length > 0)
        {
            result.Add(buffer.ToString());
        }

        if (inQuote)
        {
            throw new Exception("Unmatched quote in B1 content");
        }

        return result.ToArray();
    }

    /// <summary>
    /// 检查指定位置是否以分隔符开始
    /// </summary>
    private static bool StartsWithDelimiter(string content, int index, string delimiter)
    {
        if (index + delimiter.Length > content.Length)
        {
            return false;
        }

        for (int i = 0; i < delimiter.Length; i++)
        {
            if (content[index + i] != delimiter[i])
            {
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// 查找未被引号包裹的 = 符号位置
    /// </summary>
    private static int FindUnquotedEquals(string field)
    {
        bool inQuote = false;
        bool inEscape = false;

        for (int i = 0; i < field.Length; i++)
        {
            char c = field[i];

            if (inEscape)
            {
                inEscape = false;
                continue;
            }

            if (c == '\\')
            {
                inEscape = true;
                continue;
            }

            if (c == '"')
            {
                inQuote = !inQuote;
                continue;
            }

            if (!inQuote && c == '=')
            {
                return i;
            }
        }

        return -1;
    }

    /// <summary>
    /// 去除值两端的引号并处理转义字符
    /// </summary>
    private static string UnescapeValue(string value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return value;
        }

        // 去除两端引号
        if (value.StartsWith("\"") && value.EndsWith("\"") && value.Length >= 2)
        {
            value = value.Substring(1, value.Length - 2);
        }

        // 处理转义字符
        value = value.Replace("\\\"", "\"");
        value = value.Replace("\\\\", "\\");

        return value;
    }

    /// <summary>
    /// 验证必填字段
    /// </summary>
    private static void ValidateRequiredFields(Dictionary<string, string> fields)
    {
        // full_name 是 B1 唯一必填项：它是这张表的身份，无从推导。
        // 其余字段一律可省 —— value_type 由表名推导（TbItem -> Item），
        // output / index / input 等则各有缺省语义，不应强迫每张表重复书写。
        if (!fields.ContainsKey("full_name") || string.IsNullOrWhiteSpace(fields["full_name"]))
        {
            throw new Exception("Missing required field: full_name");
        }
    }
}
