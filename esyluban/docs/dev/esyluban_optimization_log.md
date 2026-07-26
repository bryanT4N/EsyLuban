# EsyLuban 优化日志 (V1)

日期: 2026-01-22

## 1. 自包含表定义
- Excel/CSV 表采用 A1 `##export` 控制导出, B1 存储表元数据。
- 原 `##var/##type/##group/##comment` 行整体下移一行。
- `__tables__.xlsx` 不再作为表定义入口。

## 2. 新目录结构与集中工具
- `Tools/Luban/` 集中 `Luban.dll` 与脚本入口。
- `DataTables/` 直接放数据表; XML Schema 位于 `DataTables/__Defines__/`。
- 示例项目仅保留 `Tools/Luban`，测试脚本统一放在根 `scripts/`。

## 3. 右键菜单入口
- 提供全局安装/卸载脚本, 默认菜单名 `LubanExport`（始终唯一）。
- 支持向上 5 层自动定位 `Tools/Luban`。
- 支持选中文件/目录导表, 默认排除 `__beans__/__enums__/__tables__`。
- 新增可配置菜单名参数, 避免多套工具冲突。

## 4. 全覆盖测试模板
- 覆盖类型系统、容器、多态、变体、本地化、校验器、混合数据源与错误用例。
- 统一入口：`scripts/run_full_tests_example.bat`，输出到 `Projects/EsyLuban_Example_dev/TestOutputs`。
- 增加无 L10N 基线对比：`Projects/EsyLuban_Example_dev/TestOutputs/compare_report.json`。
- 基线来源：`luban_examples_pristine/Projects/GenerateDatas/json`。

## 5. EsyLuban 示例项目
- 基于 `luban_examples` 迁移到 `Projects/EsyLuban_Example_dev`。
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
  - 覆盖一致性：`EsyLuban_Baselines/json` + `compare_report_coverage.json`
  - 覆盖基线刷新：`scripts/refresh_coverage_baseline.bat`

## 8. 配置单一来源与脚本规范
- 示例项目 `luban.conf` 统一写入 `xargs`（输出/L10N/校验只在此配置）。
- 右键入口脚本仅覆盖 `tableImporter.scanPath`，其余参数不再被脚本覆盖。
- `gen.bat` / `check.bat` 固定切换到脚本目录，避免相对路径错乱。

## 9. 功能矩阵补全与新手文档
- 新增覆盖矩阵测例与负例：`DataTables/matrix/feature_tables.xlsx`、`DataTables/negatives/path_fail.xlsx`
- 新增矩阵文档：`docs/coverage_matrix.md`
- 新增新手指南：`docs/esyluban_beginner_guide.md`
- 新增矩阵用例生成脚本：`scripts/create_matrix_cases.py`
