# 功能覆盖矩阵

本文用于记录 **EsyLuban 功能 → 测例** 的对应关系，便于补例与回归测试。

## 1. 范围与原则
- 正向用例集中于 `esyluban/examples/dev/DataTables/matrix/`。
- 负向用例集中于 `esyluban/examples/dev/DataTables/negatives/`，仅用于“不中断但记录日志”。
- 以 **可导出的表** 为准（A1=`##export` 且 B1 含元数据）。

## 2. 正向用例覆盖

### 2.1 `matrix/feature_tables.xlsx`

- `basic`：自包含表定义（A1+B1）、基础类型、nullable、not-default、L10N text、path 校验
  - 表：`matrix.TbBasic`
  - 关键字段：`textKey(text)`、`res(string#(path=unity))`、`optName(string?)`、`notDefault(int!)`
- `containers`：容器类型与 sep 拆分
  - 表：`matrix.TbContainers`
  - 关键字段：`list<int>`、`set<string>`、`map<int,string>`、`list<InnerBean>`
- `singleton`：单例表
  - 表：`matrix.TbMatrixSingleton`（mode=one）
- `list`：列表表
  - 表：`matrix.TbMatrixList`（mode=list）

### 2.2 全局 Schema
- `__enums__.xlsx`：`matrix.EQuality`
- `__beans__.xlsx`：`matrix.BasicRecord` / `matrix.ContainerRecord` / `matrix.InnerBean` / `matrix.SingleConfig` / `matrix.ListRecord` / `matrix.PathRecord`

### 2.3 `matrix/validators.xlsx`
- 表：`matrix.TbValidators`
- 覆盖：`regex` / `range` / `set` / `not-default`

## 3. 负向用例覆盖

### 3.1 `negatives/validators_fail.xlsx`
- 表：`matrix.TbValidatorsFail`
- 覆盖：`regex` / `range` / `set` / `not-default` 失败路径

### 3.2 `negatives/path_fail.xlsx`
- 表：`matrix.TbPathFail`
- 覆盖：`path` 失败路径（资源不存在）

## 4. 内联 Enum/Bean 覆盖

- `test/inline_defs.xlsx`：内联 `__enums__` / `__beans__`（file-wide）

## 5. 依赖资源

- L10N 文本源：`esyluban/examples/dev/DataTables/l10n/texts.xlsx`
- path 资源根：`esyluban/examples/dev/DataTables/Assets`
  - 示例资源：`Assets/Scenes/SampleScene.unity`

## 6. 矩阵快照输出

- 输出 JSON：`esyluban/examples/dev/TestOutputs/coverage_matrix_report.json`
- 生成脚本：`esyluban/scripts/test/report_coverage_matrix.bat`
