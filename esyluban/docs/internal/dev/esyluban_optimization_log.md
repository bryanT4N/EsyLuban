# EsyLuban 优化日志 (V1)

日期: 2026-01-22

## 1. 自包含表定义
- Excel/CSV 表采用 A1 `##export` 控制导出, B1 存储表元数据。
- 原 `##var/##type/##group/##comment` 行整体下移一行。
- `__tables__.xlsx` 不再作为表定义入口。

## 2. 新目录结构与集中工具
- `Tools/Luban/` 集中 `Luban.dll` 与脚本入口。
- `DataTables/` 直接放数据表; XML Schema 位于 `DataTables/Defines/`。
- 示例项目仅保留 `Tools/Luban`，测试脚本统一放在根 `scripts/`。

## 3. 右键菜单入口
- 提供全局安装/卸载脚本, 默认菜单名 `LubanExport`（始终唯一）。
- 支持向上 5 层自动定位 `Tools/Luban`。
- 支持选中文件/目录导表, 默认排除 `__beans__/__enums__/__tables__`。
- 新增可配置菜单名参数, 避免多套工具冲突。

## 4. 全覆盖测试模板
- 覆盖类型系统、容器、多态、变体、本地化、校验器、混合数据源与错误用例。
- 统一入口：`esyluban/scripts/test/run_full_tests_example.bat`，输出到 `esyluban/examples/dev/TestOutputs`。
- 增加无 L10N 基线对比：`esyluban/examples/dev/TestOutputs/compare_report.json`。
- 基线来源：`luban_examples_pristine/Projects/GenerateDatas/json`。

## 5. EsyLuban 示例项目
- 基于 `luban_examples` 迁移到 `esyluban/examples/dev`。
- 采用复制同步（根目录 `scripts/sync_example_tools.bat`）。
- 集成右键菜单脚本与测试入口。
- 内置 Unity 示例工程 `Projects/Csharp_Unity_json`。

## 6. 风险与提示
- **复制同步**: 工具更新后需手动执行 `scripts/sync_example_tools.bat`。
- **公式缓存**: Excel 公式值可能因迁移写入而失效，需打开表格触发重算。
- **CSV 编码**: 迁移脚本会重写 CSV 为 UTF-8（编码测试用例需注意）。

## 7. 第二优化点阶段总结（内联 Enum/Bean 子表）
- `__enums__` / `__beans__` 子表在同一 Excel 内自动识别，file-wide 作用域。
- 新增测例：`DataTables/test/inline_defs.xlsx`，并同步等价基线。
- 测试矩阵与负例完善：
  - 新增 `DataTables/matrix/` 与 `DataTables/negatives/`。
  - 负例独立运行，日志 `TestOutputs/negative_tests.log`。
- 基线策略升级为双基线：
  - 核心一致性：`luban_examples_pristine` + `compare_report.json`
  - 覆盖一致性：`esyluban/baselines/coverage` + `compare_report_coverage.json`
  - 覆盖基线刷新：`esyluban/scripts/test/refresh_coverage_baseline.bat`

## 8. 配置单一来源与脚本规范
- 示例项目 `luban.conf` 统一写入 `xargs`（输出/L10N/校验只在此配置）。
- 右键入口脚本仅覆盖 `tableImporter.scanPath`，其余参数不再被脚本覆盖。
- `gen.bat` / `check.bat` 固定切换到脚本目录，避免相对路径错乱。

## 9. 功能矩阵补全与新手文档
- 新增覆盖矩阵测例与负例：`DataTables/matrix/feature_tables.xlsx`、`DataTables/negatives/path_fail.xlsx`
- 新增矩阵文档：`docs/coverage_matrix.md`
- 新增新手指南：`docs/esyluban_beginner_guide.md`
- 新增矩阵用例生成脚本：`esyluban/scripts/authoring/create_matrix_cases.py`

---

# V2（2026-07-26）：结构重构、上游跟进与功能修复

> 上文第 1~9 节为 V1 阶段记录，保留原貌。其中**第 5、6 节提到的
> `sync_example_tools.bat` 复制同步机制已退役**，原因见下文 10.3。

## 10.1 目录结构重构
- fork 仓库提升为工作区根，消灭 `EsyLuban/EsyLuban` 同名嵌套。
- 分界线：**仓库根 = 上游 Luban 原物，`esyluban/` = 全部自有资产**。
- 示例工程 → `esyluban/examples/{dev,release}`；两份基线并列到
  `esyluban/baselines/{core,coverage}`；脚本按用途分为
  `scripts/{test,contextmenu,authoring}/`；文档分为
  `docs/{guides,reference,dev,archive}/`；调试沙盒 → `esyluban/sandbox`。
- 新增分层 `esyluban/.gitignore`（不改上游根 `.gitignore`），其中须保留
  `!examples/release/` —— 上游 `.gitignore` 的 `[Rr]elease/` 会静默吞掉整个
  release 示例工程。

## 10.2 跟进上游 v4.10.2
- `main` 由 v4.5.0 快进 30 个提交至 v4.10.2，`esyluban` 分支 rebase 零冲突。
- 分支模型：`main` 为纯上游镜像，自有工作全在 `esyluban` 分支。

## 10.3 工具与配置解耦（同步机制退役）
- 此前右键脚本假定 `luban.conf` 与 `Luban.dll` 同目录，迫使每个工程复制整套
  工具（3 份 × 60 个二进制）。
- 改为二者分别向上寻址：运行时全仓库只存 `esyluban/runtime/` 一份（构建产物，
  不进版本控制，由 `scripts/build.bat` 生成），各工程只保留自己的 `luban.conf`
  与 `gen/check.bat`。
- `sync_example_tools.bat` 随之退役，"忘记同步"的风险消失。

## 10.4 功能修复（此前自包含表实际不可用）
- **补上缺失的 `SelfContainedTableImporter`**：此前只实现了 SchemaLoader，
  而 SchemaLoader 仅处理 `schemaFiles` 显式列出的文件，无法承担"扫描数据目录、
  发现表"的职责 —— 实测自包含表发现数为 0。
- **内联 `__beans__`/`__enums__` 子表**：新增 `SelfContainedSchemaCollector`
  实现第 7 节描述但未落地的 file-wide 定义。
- **XML 定义目录改名** `__Defines__` → `Defines`：Luban 忽略任何以 `_` 开头的
  路径段，原目录下 7 个 xml 从未被加载，症状是所有 XML 类型"未定义"。
- **`pathValidator.rootDir` 修正**：应指向工程根而非 `Assets` 目录，
  否则与表中自带 `Assets/` 前缀的值拼成重复路径。
- **负例回归修复**：移除多余的 `tableImporter.scanPath` 限制。schema 是全局
  加载的，只导入负例目录会让跨表引用悬空，运行在到达待测校验器前就中止
  （日志末尾的 `run failed!!!` 是假象，一条负例都没跑到）。

## 10.5 B1 简化：只有 `full_name` 必填
统计 58 张表后发现，B1 的冗长大多来自把上游已有的缺省行为在每张表重抄一遍：
`output` 58/58 显式书写却 100% 等于上游对空值的 fallback；
`read_schema_from_file` 58/58 书写而 false 占 93%；
`input` 中 72% 就指向 sheet 自己。

现缺省语义为：`value_type` 由表名推导（`TbItem`→`Item`）、`output` 由全名生成、
`input` 指向自身、`index` 取值类型首字段、`read_schema_from_file` 为 `false`。
最简写法见 `DataTables/test/minimal_b1.xlsx`。

## 10.6 对上游的改动
`SheetLoadUtil.cs` 一个文件：`TryParseMeta` 读到 `##export` 时续读下一行作为
真正的 meta 行（必须在读取时跳过 —— `orientRow` 就在此处定下，否则纵向表会被
误判为横向表），外加两处 tag 白名单加入 `export`。三个扩展点
（TableImporter / SchemaCollector / SchemaLoader）均以 `Priority` 覆盖上游默认
实现，属于 Luban 预留的扩展通道，无需侵入上游。

## 10.7 验证
- 核心基线：`diff 0`（`missing` 3 项为已废弃的 autoimport 机制）
- 覆盖基线：56/56，`missing`/`extra`/`diff` 全 0
- 单元测试：28/28 通过（`scripts/test/run_unit_tests.bat`）
- `release` 示例工程实跑通过（56 张表 / 55 个输出文件）
