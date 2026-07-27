# EsyLuban 回归基线

五套基线，供 `scripts/test/run_full_tests_example.bat` 逐文件 SHA256 比对。
每套回答一个不同的问题：

| 目录 | 内容 | 它证明什么 |
|---|---|---|
| `core/` | 上游语料的 json 输出 | **没弄坏你的数据**：源自上游 `luban_examples` 未迁移版本。用它证明「改用 A1/B1 自包含定义后，结果与上游逐字节相同」。**不可再生** |
| `coverage/` | `examples/dev` 全量 json | **没有意外变化**：由当前输出刷新而来，用它发现任何非预期的输出改动 |
| `xml/` | 同上，xml 格式 | 换一种数据格式，同一份数据仍然稳定 |
| `code_cs/` | 同上，`cs-simple-json` 生成代码 | 生成代码也进基线 —— 模板改动会改变每个接入方的代码 |
| `json_l10n/` | 同上，开启 l10n | 文本 key → 实际文案的替换链路。它此前每次都跑，却从不比对 |

各目录的文件数由回归在比对时报出（如 `core baseline : 53 files match`），
本文不再重复记录 —— 手写的数字会漂移，而且已经漂过：这份 README 曾长期写着
「两份基线」「coverage 56 个 json」，实际是五套、60 个。

## 两类基线，两种对待方式

**`core/` 是历史证据，不可再生。** 它是上游在未迁移语料上跑出来的输出，一旦
覆盖就再也拿不回来。所以它没有刷新脚本，这是有意的。

`core` 的 `missing` 恒含 3 个 `tbautoimport*.json` —— 那是上游 `__tables__.xlsx`
自动导入机制的产物，已被 EsyLuban 的自包含定义取代，属预期缺口。比对时对
`core` 允许 extra（我们的表比上游多），但 missing 与 diff 仍算失败。

**其余四套是当前输出的快照，可以刷新。**

```
esyluban\scripts\test\refresh_baselines.bat [coverage | xml | code | l10n | all]
```

不带参数等同于 `all`。刷新前先跑一次回归，产物才是齐的。它以
`examples/dev/TestOutputs/` 下对应的导出为源做镜像同步（`robocopy /MIR`，会删除
源中已不存在的文件），并在 `baseline_log.md` 追加记录。

两道保护：

- **拒绝刷新 `core/`** —— 传 `core` 会被明确拒绝并说明理由，不是静默跳过。
- **拒绝以空目录覆盖** —— `robocopy /MIR` 在源为空时会清空目标**并返回成功**。
  一次「导出失败但脚本继续跑」就足以毁掉整套基线且毫无痕迹，所以刷新前先数文件。

**仅在确认输出变化符合预期时才刷新。** 基线一旦刷错，后续回归就永久失去了参照。
刷完看一眼 `git diff --stat esyluban/baselines` 再提交。

## 为什么它们被标记为二进制

`esyluban/.gitattributes` 把 `baselines/**` 标为 `-text`，关闭 git 的换行规范化。

这不是洁癖。在此之前基线入库存 LF、检出时按本机 `core.autocrlf` 决定给 LF 还是
CRLF，而 Luban 在 Windows 上生成 CRLF。于是基线能否通过取决于**克隆者的 git
配置**：`autocrlf=true` 全绿，`false` 则所有基线文件同时报错，且失败信息只打印
文件名，完全不指向真因。SHA256 基线按定义就是字节资产，必须逐字节可复现。

## 回滚

基线在版本控制内，直接 `git checkout -- esyluban/baselines` 即可回退。
