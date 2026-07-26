# EsyLuban 回归基线

两份基线，供 `scripts/test/run_full_tests_example.bat` 逐文件 SHA256 比对。

| 目录 | 内容 | 作用 |
|---|---|---|
| `core/` | 53 个 json | **核心一致性**：源自上游 `luban_examples` 未迁移版本的输出。用它证明"改用 A1/B1 自包含定义后，结果与上游逐字节相同" |
| `coverage/` | 56 个 json | **覆盖一致性**：由 `examples/dev` 当前输出刷新而来。用它发现任何非预期的输出变化 |

比对结果写入 `examples/dev/TestOutputs/compare_report.json`（核心）
与 `compare_report_coverage.json`（覆盖）。

`core` 的 `missing` 恒含 3 个 `tbautoimport*.json` —— 那是上游已被 EsyLuban
取代的 `__tables__.xlsx` 自动导入机制的产物，属预期缺口。

## 刷新覆盖基线

```
esyluban\scripts\test\refresh_coverage_baseline.bat
```

它以 `examples/dev/TestOutputs/json_nol10n` 为源做镜像同步（`robocopy /MIR`，
会删除源中已不存在的文件），并在 `baseline_log.md` 追加一条记录（时间 + 来源）。

**仅在确认输出变化符合预期时才刷新** —— 基线一旦刷错，后续回归就失去了参照。

## 回滚

基线在版本控制内，直接 `git checkout -- esyluban/baselines` 即可回退。
