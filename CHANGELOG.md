# 更新日志

EsyLuban 每个版本的改动，新版本在前。格式参照 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)：「升级须知」写换版本时要你动手的事，有才写；其余按新增、变更、修复分组。

升级方式：替换项目里的整个 `Tools/Luban/`，`luban.conf` 和表格不动。版本号形如 `0.3.0+luban5.1.0`，加号后面是本 fork 基于的上游 Luban 版本。

## [未发布]

### 变更

- A1 写 `##export=true` 和 `##export` 一样导出。0.3.0 起它会告警、不导出；还留着这种写法的表，升级后会开始导出。

### 修复

- A1 写成 `#export`（少一个 `#`）时也给 `[bad A1]` 告警。以前只有 `##` 开头的写错才告警，这张表会悄悄不导出。

### 文档

- 改正：`sep` 写在类型里是生效的，要加括号写成 `(list#sep=;),int`，原来踩坑一节说「写在类型上不生效」是错的；A1 不分大小写，`##Export` 也会导出。
- 补上变体漏写的几处：变体的产物在输出目录下以变体命名的子目录里（`docs/targets-and-output.md`）；导表流程图去掉了本地化那一步（`docs/how-it-works.md`）。
- 标明不推荐用上游的字段变体和表变体（`--variant`），同一份数据的几个版本只用 `variant_` 文件夹（`docs/table-format.md`）；README 的「与 Luban 的区别」加上变体这一行。

## [0.4.0+luban5.1.0] - 2026-09-27

不写 `esyluban.variants` 的项目，写表和导出方式不变。

### 升级须知

- 用了 0.3.0 B1 表变体的：把写了 `variant` 的 sheet 挪进 `variant_<名字>` 文件夹、删掉 B1 里的 `variant`，在 `luban.conf` 写 `esyluban.variants`，再删掉 `contextMenu` 的 `extraArgs` 里的 `--variant`。

### 新增

- 变体：同一张表的几个版本放进 `variant_<名字>` 文件夹，表名不变。`luban.conf` 写 `esyluban.variants=en`，一次导出出默认版和每个变体各一份，变体在输出目录下以名字命名的子目录里。主键相同的行整行替换，新主键追加，单例表和 list 表整张替换；代码只生成一份，`--strict` 和 `check.bat` 每个版本都校验。见 `docs/writing-tables.md`。
- 右键只导选中的表影响到的版本：选中 `variant_en` 里的表只导 `en`，改默认版的表每个版本都导。
- `-o 表名@变体` 只导那个变体。
- 示例表改成一个中英双语的项目：文字字段填 key、一张每种语言一列的文本表、`variant_en` 里的英文配音。
- 发布包带上 `CHANGELOG.md`。

### 移除

- B1 的 `variant`（0.3.0 加入），写了会报 `esyluban.b1.variant_key`。同一张表的几个版本改用 `variant_<名字>` 文件夹。

### 文档

- 多语言改为推荐运行时按语言取文字，玩家能在游戏里随时切换：文字字段填 key、用 `ref` 校验，文本表作为普通的表原样导出；文本表可以每种语言一列，也可以每种语言一张。不再推荐 Luban 自带的本地化（导出时把 key 换成文字）。见 `docs/localization.md`。
- 仓库里的 Unity 示例（`examples/release`）也改成这套做法：不再配 `l10n.*`，文本表作为普通的表导出，`Main.cs` 演示按语言取文字。

## [0.3.0+luban5.1.0] - 2026-09-26

不用表变体的话，写表和导出方式不变，数据输出与 0.2.0 逐字节相同。

### 新增

- B1 表支持表变体：同一个 `full_name` 再建一张 sheet，B1 写 `variant="en"`；导出用 `--variant` 选，右键由 `contextMenu` 的 `extraArgs` 决定。同一张表各份的 `output`、`mode`、`index` 要写成一样的。见 `docs/localization.md`。
- EsyLuban 自己的报错带 `esyluban.*` 错误码，`--errorFormat json` 里可见。

### 变更

- EsyLuban 的报错和告警跟随系统语言，和上游一致；B1 写错时直接给出文件和 sheet。
- 两条告警改为以 `[bad A1]`、`[empty B1]` 开头。按旧文字（如 `no table metadata in B1`）匹配日志的脚本，要改成匹配标签或错误码。
- 右键只导出选中范围里的表。XML 或 `__tables__.xlsx` 里定义的表，只在选中它的数据文件时导出。
- A1 写 `##export=true` 这类无效标记会给出 `[bad A1]` 告警；导不导出的规则没变。
- B1 写 `variants`（字段变体的写法）会报错，并说明该怎么写。

### 修复

- 默认版留在 B1、其余几份在 XML 里标 `variant` 时，右键别的目录不再报「没有 fallback」而中止。

### 文档

- 新增：`convertTextKeyToValue=1` 时写错的文本 key 不算校验失败，会原样进产物；`docs/localization.md` 写了怎样用 `check.bat` 拦下。
- 新增：字段里常有逗号、分号时，可以把数据放进 tsv，见 `docs/data-sources.md`。

## [0.2.0+luban5.1.0] - 2026-09-26

跟进上游 Luban 5.1.0，此前基于 4.10.2。数据输出不变，只有一张表的生成代码多了一段注释。上游的 AI 工具链（Luban.Agent、MCP）不在发布包里。

### 升级须知

- 这次 `gen.bat`、`check.bat` 和右键脚本都改了，要替换整个 `Tools/Luban/`，只换 `runtime/` 不够。
- `--validationFailAsError` 改名为 `--strict`，旧名字会让整次运行直接失败。写进了 CI、提交钩子、自己的脚本或 `contextMenu` 的 `extraArgs` 的要改；`check.bat` 已经改好。

### 新增

- `--errorFormat json`（上游）：报错以 JSON 写到 stderr，带稳定的错误码，适合 CI 解析。
- `schema-json` codeTarget（上游）：导出工程结构描述，列出每张表、结构和枚举定义在哪个文件的哪张 sheet。

### 变更

- 报错语言跟随 Windows 界面语言，英文系统上是英文，加 `--locale zh` 切回中文（右键写进 `extraArgs`）。文档提到报错改写错误码，排错页的速查表列出中英文原文。
- 表级报错（如 `index` 写了不存在的字段）会给出文件和 sheet。
- 两张 sheet 写了同一个 `full_name`，报错列出每一处，以前是 `table:'x' duplicated`。
- B1 写 `variant` 会报错：上游 5.1 的表变体 B1 表暂不支持，以前会被悄悄忽略。
- 右键菜单的 `extraArgs` 也传给「列出选中的表」这一步。
- B1 写了 `comment`、又从数据表读结构的表，生成的记录类带上这段注释（上游的修复）。

## [0.1.1+luban4.10.2] - 2026-09-26

基线仍是 Luban 4.10.2。只有 `runtime/` 和 `docs/` 变了，升级不需要改任何东西。

### 修复

- B1 的 `group` 也认分号。`group="c;s"` 以前会报 `group:c;s not found`，现在和 `__tables__.xlsx`、XML 一样解析。

### 文档

- 新增 `data-sources.md`（数据从哪来）、`filling-structures.md`（列表、字典、嵌套结构怎么填）、`recipes.md`（常见需求的配法）。
- 排错文档新增「没报错，但结果不对」一节，报错速查表多收 8 条。
- 改正「多格」「多行」两种填法的示例；多格原来用的 `Vector3` 在 Luban 4.x 里已经移除。
- 讲清 `editor` target 为什么绑 `c` 组；`setup.md` 补已在用 Luban 的项目怎么接入；`localization.md` 补按语言分目录出包；右键菜单文档加了截图。

## [0.1.0+luban4.10.2] - 2026-07-27

首个公开版本，基于 Luban 4.10.2。可以和已有的 `__tables__.xlsx` 共存，数据输出与上游逐字节相同（`baselines/core/` 每次回归比对）。工具链仅支持 Windows；小包需要 .NET 8，standalone 包不需要。暂无自动迁移工具。

### 新增

- 自包含表定义：A1 写 `##export`、B1 写表定义，不再需要 `__tables__.xlsx`。B1 只有 `full_name` 必填。
- Windows 右键导表：右键文件夹或表格即可导出。注册表指向转发器，随项目升级不用重装；多个项目用 `--suite <名字>` 各装一套。
- 内联 bean / enum：在数据表文件里加 `__beans__` 或 `__enums__` sheet，就地声明嵌套结构。
- 输出目录清理的安全闸：一个产物都没有、或要删的比产出的多时，拒绝清理并说明理由，`-x forceCleanUpOutputDir=1` 放行。
- 无效 xargs 键告警：`client.outputDataDir=` 这类永远不生效的写法会给出 `[dead xargs]` 警告。

首个公开版本之前的开发历史不列在这里，`git log` 里每条提交都写了什么坏了、为什么。

[未发布]: https://github.com/bryanT4N/EsyLuban/compare/v0.4.0%2Bluban5.1.0...HEAD
[0.4.0+luban5.1.0]: https://github.com/bryanT4N/EsyLuban/compare/v0.3.0%2Bluban5.1.0...v0.4.0%2Bluban5.1.0
[0.3.0+luban5.1.0]: https://github.com/bryanT4N/EsyLuban/compare/v0.2.0%2Bluban5.1.0...v0.3.0%2Bluban5.1.0
[0.2.0+luban5.1.0]: https://github.com/bryanT4N/EsyLuban/compare/v0.1.1%2Bluban4.10.2...v0.2.0%2Bluban5.1.0
[0.1.1+luban4.10.2]: https://github.com/bryanT4N/EsyLuban/compare/v0.1.0%2Bluban4.10.2...v0.1.1%2Bluban4.10.2
[0.1.0+luban4.10.2]: https://github.com/bryanT4N/EsyLuban/releases/tag/v0.1.0%2Bluban4.10.2
