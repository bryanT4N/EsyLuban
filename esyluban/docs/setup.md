# 接入你的项目

**给谁看**：把 EsyLuban 装进一个真实工程的程序员。一个项目只做一次。

**读完你能做什么**：从下载发布包到导出第一批产物，并确认这条链路真的通了。

**不该在这里找什么**：`luban.conf` 每一项的含义在[配置参考](configuration.md)；右键菜单怎么装、怎么配在[右键菜单](context-menu.md)；任何报错在[出错了怎么办](troubleshooting.md)。

策划不需要读这份 —— 他们要的是[写一张表](writing-tables.md)。

---

## 下载哪个包

不需要 clone，也不需要构建。Releases 里两个包功能完全一致，区别只在要不要预装 .NET：

| 包 | 下载体积 | 前置条件 | 每个项目占用 |
|---|---|---|---|
| `EsyLuban-<版本>-win-x64-standalone.zip` | 约 34 MB | 无，解压即用 | 约 76 MB |
| `EsyLuban-<版本>-win-x64.zip` | 约 2 MB | 机器上要有 .NET 8 运行时 | 约 6 MB |

> 版本号形如 `0.1.0+luban4.10.2` —— 前半是 EsyLuban 自己的版本，`+luban` 之后是
> 它基于的上游 Luban 代码基线。同一个上游基线下可以有多个 EsyLuban 版本。


因为约定是「每个项目自带一套 `Tools/Luban/`」，取舍就是**一次性安装成本 vs 每个项目的磁盘占用**。
团队机器统一装了 .NET 8 就用小包，否则 standalone 省事。

用小包的话先确认运行时在位：

```
dotnet --list-runtimes
```

输出里要出现 `Microsoft.NETCore.App 8.x.x`。没有就装
[.NET 8 Runtime](https://dotnet.microsoft.com/download/dotnet/8.0)（选 **Runtime**，不需要 SDK），
或者改用 standalone 包。

维护这个 fork 的人才需要从源码构建：`esyluban\scripts\build.bat`（要 .NET SDK）。
运行时不进版本控制，clone 下来 `runtime/` 是空的，必须先构建。

---

## 先确认它能跑

解压后**什么都别改**，在解压出来的目录里执行：

```
Tools\Luban\gen.bat -t client -d json
```

`Generated\Data\` 下应当出现两个文件：

```
demo_tbitem.json
demo_tbmonster.json
```

它们来自包里自带的 `DataTables\items.xlsx` 与 `monsters.xlsx`。
**看到它们就说明工具链完整可用**，剩下的步骤只是把路径改成你项目的。

这一步跑不出来几乎只有一个原因：用了小包但机器上没有 .NET 8。`gen.bat` 会直接报出缺什么。

`-t` 是 target 名（取自 `luban.conf` 里 `targets` 的 `name`），`-d` 是数据格式。
不带参数运行 `gen.bat` 会打印用法。日常导表用[右键菜单](context-menu.md)，不用敲命令行。

---

## 目录布局

发布包解压出来的结构**就是推荐布局本身**。把 `Tools\` 和 `DataTables\`
两个目录整体拷进你的开发目录根下：

```
你的开发目录/
├─ DataTables/               <- 从包里拷来。策划的地盘，Excel 都放这
│  ├─ items.xlsx
│  └─ monsters.xlsx
├─ Tools/                    <- 从包里拷来
│  └─ Luban/
│     ├─ runtime/             工具本体，不要动
│     ├─ luban.conf           唯一需要你改的文件
│     ├─ gen.bat              命令行导表
│     ├─ check.bat            只校验不导出
│     └─ contextmenu/         右键菜单的安装脚本与导表实现（不能删）
└─ Source/                   游戏工程
   └─ 你的游戏/
      ├─ Code/Generated/      <- 导出的代码落在这
      └─ Run/Data/Generated/  <- 导出的数据落在这
```

三条原则：

| 原则 | 为什么 |
|---|---|
| **Excel 只放 `DataTables/`** | 游戏工程里不该出现源表，只该有产物。策划改表不碰游戏工程，程序员的构建产物也不污染策划的目录 |
| **`Tools/` 与 `DataTables/` 平级** | 工具既不属于数据也不属于某个工程，它服务于整个开发目录。有多个客户端/服务端工程时尤其明显 |
| **`luban.conf` 与 `runtime/` 必须同级** | 右键菜单先向上找 `Tools\Luban\luban.conf`，再在它旁边找 `runtime\Luban.exe`。拆开就找不到运行时 |

这与官方 `luban_examples` 的做法一致（`DataTables/`、`Tools/`、`Projects/` 三者平级，
游戏工程内无源表），不是自创的约定。

**每个项目自带一套 `Tools/Luban/`。** 代价是磁盘上有多份副本，换来的是各项目工具版本
互相独立 —— 老项目不会因为别处升级了 Luban 而被动出问题。

> 本仓库 `esyluban/examples/` 下的示例工程是例外：它们的 `Tools/Luban/` 里没有
> `runtime/`，共享 `esyluban/runtime/` 一份，由脚本向上搜索命中。这是为了避免每次
> rebuild 都复制多份。外部项目不要模仿 —— 自带一份才有版本独立性。

---

## 改 `luban.conf`

打开 `Tools\Luban\luban.conf`，与你的项目有关的只有输出路径这两行：

```json
{
  "dataDir": "../../DataTables",
  "xargs":
  [
    "outputDataDir=../../Generated/Data",
    "outputCodeDir=../../Generated/Code"
  ]
}
```

**所有相对路径都以 `Tools/Luban/` 自身为基准。** 按上面的布局改成：

```json
  "xargs":
  [
    "outputDataDir=../../Source/你的游戏/Run/Data/Generated",
    "outputCodeDir=../../Source/你的游戏/Code/Generated"
  ]
```

`dataDir` 通常不用改，`../../DataTables` 在推荐布局下已经是对的。

> **`outputDataDir` 必须是一个 Luban 专用目录。**
> 全量导出前，Luban 会清空输出目录里所有不属于本次产物的文件 —— 不管是不是它生成的。
> 别把它指向混放美术资源或手写配置的目录。用 `.../Run/Data/Generated/` 这种一眼看出
> 是生成物的路径。（右键菜单的局部导表不受影响，它会关掉这个清理。）

顺手确认右键菜单的输出格式，`dataTarget` 是数据格式，`codeTargets` 是代码语言：

```json
  "contextMenu":
  {
    "data": { "targets": ["client"], "dataTarget": "json" },
    "code": { "targets": ["client"], "codeTargets": ["cs-simple-json"] }
  }
```

Unity + JSON 用这份默认值即可。各字段的完整含义见[右键菜单](context-menu.md)，
选格式与分目录见[目标与输出](targets-and-output.md)。

> **别给 `luban.conf` 加 JSON 注释或尾逗号。** Luban 自己接受，右键脚本不接受 ——
> 原因见[右键菜单](context-menu.md)。要写说明就写在项目文档里。

---

## 确认接入成功

改完再跑一次：

```
Tools\Luban\gen.bat -t client -d json
```

这次产物应当落在你 `outputDataDir` 指向的目录里，而不是 `Generated/Data/`。
看到文件出现在游戏工程下，整条链路就通了。

`check.bat` 只做校验不导出，参数与 `gen.bat` 相同，适合放进提交前检查。

---

## 项目里已经在用 Luban 了怎么办

**不用一次性迁移，两种写法可以共存。**

已有的 `__tables__.xlsx` 继续有效，新建的表用 A1/B1 自包含写法，同一个工程里
混着来没有问题。老表什么时候改、改不改，由你决定。

有一件事需要先确认：**EsyLuban 的产物与上游逐字节相同**，所以换过来不需要改
运行时加载代码，也不会有数据差异。这一点由回归守着 —— `baselines/core/` 是上游
在未迁移语料上跑出来的产物，每次都拿它逐文件比对 SHA256。

一处会变的行为：上游那套「文件名以 `#` 开头就自动导表」的约定在 EsyLuban 里
不生效，原因见[数据从哪来](data-sources.md)。用过这套约定的表要补上 A1/B1。

> 存量表暂无自动迁移工具。`scripts/authoring/migrate_xlsx.py` 仍是禁用状态，
> 理由写在它的文件头里。

---

## 接下来

- 装右键菜单，把导表入口交给策划 → [右键菜单](context-menu.md)
- 客户端服务端分字段、产物分目录、测试数据不进包 → [常见需求怎么配](recipes.md)
- 格式怎么配套、target 是三个不同的东西 → [目标与输出](targets-and-output.md)
- `xargs` 里其余的键都在做什么 → [配置参考](configuration.md)
- 让策划开始填表 → [写一张表](writing-tables.md)
