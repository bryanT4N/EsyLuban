# EsyLuban

Excel 配置表导出工具。让不写代码的策划**右键自己那张表**就能导出，不必开命令行。
每张表在自己的第一行声明自己（`A1=##export`、`B1=full_name="..."`），改哪张表就
右键哪张表，不必维护集中式的表登记文件。

基于 [Luban](https://github.com/focus-creative-games/luban) 的 fork，数据输出与
上游逐字节相同。本包是**已编译好的成品**，不需要构建任何东西。

---

## 先确认它能跑

解压后**什么都别改**，在解压出来的目录里执行：

```
Tools\Luban\gen.bat -t client -d json
```

看到 `Generated\Data\` 下出现 json 文件，说明这个包在你的机器上是好的。先确认这
一步，再去改配置 —— 否则出了问题分不清是包的问题还是配置的问题。

跑不起来：

| 现象 | 处置 |
|---|---|
| 提示缺少 .NET | 你下的是小包（约 2 MB）。装 [.NET 8 运行时](https://dotnet.microsoft.com/download/dotnet/8.0)，或换 `standalone` 版（约 34 MB，解压即用） |
| 其它报错 | 见 [出错了怎么办](docs/troubleshooting.md) |

两个版本功能完全一样。小包每个项目自带一份只占约 6 MB，standalone 约 76 MB —— 
团队机器统一装了 .NET 8 就用小包，否则用 standalone 省事。

这一步只有接入的人做一次，**策划完全不需要碰**。

## 接下来读哪一份

完整文档在 `docs/` 目录，和仓库里是同一套。按你要做的事挑：

| 我想…… | 读这份 |
|---|---|
| 把它装进我的工程 | [接入你的项目](docs/setup.md) |
| 让策划能右键导表 | [右键菜单](docs/context-menu.md) |
| 教策划怎么填表 | [写一张表](docs/writing-tables.md) |
| 弄清楚每个配置项 | [配置参考](docs/configuration.md) |
| 决定导什么格式、放哪个目录 | [目标与输出](docs/targets-and-output.md) |
| 报错了 | [出错了怎么办](docs/troubleshooting.md) |

不确定就先看 [文档索引](docs/README.md)，它按「你是谁」分好了。

## 这个包里有什么

```
Tools/Luban/
  gen.bat            导表
  check.bat          只校验不导出
  luban.conf         配置（要改的是这个）
  runtime/           Luban 本体
  contextmenu/       右键菜单的安装脚本与导表实现
DataTables/          示例表，可以直接改成你自己的
docs/                完整文档
```

`contextmenu/` 是**运行时依赖**，每次右键导表都会调用它，不是「装完就能删的安装
包」。删掉之后右键会报 `Export script not found`。

## 升级

替换 `Tools/Luban/` 整个目录即可，`luban.conf` 和你的表都不用动。

右键菜单**不必重装** —— 注册表里指向的是转发器，真正的脚本在这个目录里，替换目录
就等于升级了行为。

需要你动手的改动会写在 CHANGELOG 里。
