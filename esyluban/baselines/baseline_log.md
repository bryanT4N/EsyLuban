# 覆盖基线刷新记录
- 2026-01-23T21:19:35 refresh from C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\scripts\..\Projects\EsyLuban_Example\TestOutputs\json_nol10n
- 2026-01-24T00:23:27 refresh from C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\scripts\..\Projects\EsyLuban_Example\TestOutputs\json_nol10n
- 2026-01-24T16:02:23 refresh from C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\scripts\..\Projects\EsyLuban_Example\TestOutputs\json_nol10n
- 2026-01-24T20:11:44 refresh from C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\scripts\..\Projects\EsyLuban_Example_dev\TestOutputs\json_nol10n
- 2026-07-26T02:20:14 refresh from C:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\esyluban\scripts\test\..\..\examples\dev\TestOutputs\json_nol10n
- 2026-07-26T17:38:24 refresh from c:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\esyluban\scripts\test\..\..\examples\dev\TestOutputs\json_nol10n
- 2026-07-26T17:44:22 refresh from c:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\esyluban\scripts\test\..\..\examples\dev\TestOutputs\json_nol10n
- 2026-07-26T17:54:21 refresh from c:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\esyluban\scripts\test\..\..\examples\dev\TestOutputs\json_nol10n

## 2026-07-26 新增 xml 与代码基线

此前 16 个 dataTarget 里只有 json 被验证过，29 个 codeTarget 全部零覆盖 ——
而真实接入项目用的正是从未被测过的 xml。代码生成链路同样一次都没跑过，
这意味着 B1 的 mode / index 等字段对基线完全不可见（它们只影响生成代码，
不影响 json 数据）。

- baselines/xml/      examples/dev 全量导出 -d xml
- baselines/code_cs/  examples/dev 全量生成 -c cs-simple-json

两者均已验证为确定性输出（连续两次生成逐字节一致），可安全用作基线。

## 2026-07-26 新增 l10n 基线

本地化转换（text key -> 实际文案）此前跑了但从不比对：回归导出两份 json，
只拿 no-l10n 那份比基线，with-l10n 那份写完就没人看。实测两份有 8 个文件不同
（如 "/apple" -> "苹果"），也就是说整条 l10n 链路一直处于零覆盖。

- baselines/json_l10n/  examples/dev 全量导出，convertTextKeyToValue=1
- 2026-07-27T01:28:21 refresh coverage from c:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\esyluban\scripts\test\..\..\examples\dev\TestOutputs\json_nol10n
- 2026-07-27T01:28:21 refresh xml from c:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\esyluban\scripts\test\..\..\examples\dev\TestOutputs\xml
- 2026-07-27T01:28:22 refresh code_cs from c:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\esyluban\scripts\test\..\..\examples\dev\TestOutputs\code_cs
- 2026-07-27T01:28:22 refresh json_l10n from c:\Users\BryanT\Documents\WORK_PROJECTS\APP_PROJECTS\EsyLuban\esyluban\scripts\test\..\..\examples\dev\TestOutputs\json
