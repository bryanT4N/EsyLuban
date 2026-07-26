# 内部文档（不随项目发布）

本目录面向**维护者**，不属于交付给使用者的文档集。

发布集只有三份：

| 文件 | 作用 |
|---|---|
| `esyluban/README.md` | 子树导览 |
| `esyluban/docs/esyluban_beginner_guide.md` | 完全手册（A 给策划 / B 给程序员） |
| `esyluban/examples/README.md` | 数据出处与 MIT 归属声明（合规必需） |

## 判断标准

一份文档该不该发布，看的不是它有多重要，而是**它写的是上游 Luban 的知识，
还是 EsyLuban 自己的行为约定**：

- **上游知识** → 不发布。用户查 [Luban 官方文档](https://www.datable.cn/docs/intro)
  更权威、更及时。
- **自己的约定** → 必须发布。上游文档里永远不会有，用户只能从我们这里知道。

按这个标准，凡是 EsyLuban 自身造成的约束（`luban.conf` 不能写注释、
目录名不得以 `_` 开头、`contextMenu.data.outputDataDir` 的配法、`--listTables`、
右键套件名等）都已并入完全手册；本目录留下的是背景资料与开发过程记录。

## 目录

| 位置 | 内容 |
|---|---|
| `reference/luban_config_reference.md` | Luban 配置/脚本/定义文件的全量参考。多为上游知识，另含少量已同步进手册的 EsyLuban 约束 |
| `reference/luban_full_analysis.md` | 对上游 Luban 的源码分析笔记 |
| `dev/esyluban_optimization_log.md` | 项目演进记录（V1 九个阶段 + V2 结构重构与功能修复） |
| `dev/coverage_matrix.md` | 功能 → 测例的对应关系 |
| `dev/integration_full_chain.md` | 配置到导表的全链路串讲 |
| `archive/` | 已废弃的分析稿、2026-01 的迁移报告 |

## 维护提醒

改动这些文档时，若涉及**使用者会踩到的行为**，记得同步进
`docs/esyluban_beginner_guide.md` —— 否则发布出去的手册就漏了那条信息。
