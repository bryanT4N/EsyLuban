
> ## 这是 EsyLuban —— Luban 的一个 fork
>
> 在上游 Luban 之上增加**自包含表定义**：每张 Excel 用 `A1=##export` 与 `B1` 元数据
> 自我描述，不再需要集中式的 `__tables__.xlsx`；配套 Windows 右键菜单，让策划右键
> 自己那张表就能导出。
>
> ### 要用它
>
> **不需要 clone，也不需要构建。** 从 Releases 下载，解压后读里面的 `README.md`——
> 那份文档讲从下载到接入游戏项目的完整过程。两个版本功能一致：
>
> - `EsyLuban-<版本>-win-x64-standalone.zip`（约 34 MB）—— **解压即用**，无需安装
> - `EsyLuban-<版本>-win-x64.zip`（约 2 MB）—— 需要 [.NET 8 运行时](https://dotnet.microsoft.com/download/dotnet/8.0)
>
> 完全手册：[esyluban/docs/esyluban_beginner_guide.md](./esyluban/docs/esyluban_beginner_guide.md)
> （A 章给策划，B 章给程序员；发布包内也附一份）
>
> ### 要改它
>
> 自有内容全部位于 [`esyluban/`](./esyluban/) 目录；仓库根是上游 Luban 原物，
> `src/` 下除两个文件外只做新增。入口文档：[esyluban/README.md](./esyluban/README.md)。
> clone 后请先运行 `esyluban\scripts\build.bat` 构建运行时（不进版本控制）。
>
> 以下为上游 Luban 的原始 README。

- [README 中文](./README.md)
- [README English](./README_EN.md)

# Luban

![icon](docs/images/logo.png)

[![license](http://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](https://opensource.org/licenses/MIT) ![star](https://img.shields.io/github/stars/focus-creative-games/luban?style=flat-square)


luban是一个强大、易用、优雅、稳定的游戏配置解决方案。它设计目标为满足从小型到超大型游戏项目的简单到复杂的游戏配置工作流需求。

luban可以处理丰富的文件类型，支持主流的语言，可以生成多种导出格式，支持丰富的数据检验功能，具有良好的跨平台能力，并且生成极快。
luban有清晰优雅的生成管线设计，支持良好的模块化和插件化，方便开发者进行二次开发。开发者很容易就能将luban适配到自己的配置格式，定制出满足项目要求的强大的配置工具。

luban标准化了游戏配置开发工作流，可以极大提升策划和程序的工作效率。

## 核心特性

- 丰富的源数据格式。支持excel族(csv,xls,xlsx,xlsm)、json、xml、yaml、lua等
- 丰富的导出格式。 支持生成binary、json、bson、xml、lua、yaml等格式数据
- 增强的excel格式。可以简洁地配置出像简单列表、子结构、结构列表，以及任意复杂的深层次的嵌套结构
- 完备的类型系统。不仅能表达常见的规范行列表，由于**支持OOP类型继承**，能灵活优雅表达行为树、技能、剧情、副本之类复杂GamePlay数据
- 支持多种的语言。内置支持生成c#、java、go、cpp、lua、python、javascript、typescript、rust、php、erlang、godot 等语言代码，同时还能通过protobuf之类消息方案支持其他语言
- 支持主流的消息方案。 protobuf(schema + binary + json)、flatbuffers(schema + json)、msgpack(binary)
- 强大的数据校验能力。ref引用检查、path资源路径、range范围检查等等
- 完善的本地化支持
- 支持所有主流的游戏引擎和平台。支持Unity、Unreal、Cocos2x、Godot、微信小游戏等
- 良好的跨平台能力。能在Win,Linux,Mac平台良好运行。
- 支持所有主流的热更新方案。hybridclr、ilruntime、{x,t,s}lua、puerts等
- 生成的代码未调用任何反射接口，兼容[Obfuz](https://github.com/focus-creative-games/obfuz)、Obfuscator、Confuser、.Net Refactor等常见代码混淆和加固工具。
- 清晰优雅的生成管线，很容易在luban基础上进行二次开发，定制出适合自己项目风格的配置工具。

## 文档

- [官方文档](https://www.datable.cn/)
- [快速上手](https://www.datable.cn/docs/beginner/quickstart)
- **示例项目** ([github](https://github.com/focus-creative-games/luban_examples)) ([gitee](https://gitee.com/focus-creative-games/luban_examples))

## 支持与联系

- QQ群: 692890842 （Luban开发交流群）
- discord: <https://discord.gg/dGY4zzGMJ4>
- 邮箱: <luban@code-philosophy.com>

## license

Luban is licensed under the [MIT](https://github.com/focus-creative-games/luban/blob/main/LICENSE) license
