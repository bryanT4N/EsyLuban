# EsyLuban —— 接入指南

EsyLuban 让**策划直接用 Excel 配表，右键导出**，不需要维护集中式的表登记文件。
每张表在自己的第一行声明自己（`A1=##export`、`B1=full_name="..."`），改哪张表就右键哪张表。

本包是**已编译好的成品**，不需要你构建任何东西。

---

## 0. 前置条件：看你下载的是哪个版本

发布有两个版本，功能完全一样，区别只在要不要装 .NET：

| 下载的文件名 | 体积 | 前置条件 |
|---|---|---|
| `EsyLuban-<版本>-win-x64-standalone.zip` | 约 34 MB | **无。解压即用**，运行时已打包在内 |
| `EsyLuban-<版本>-win-x64.zip` | 约 2 MB | 需要机器上装了 .NET 8 |

**下载的是 standalone 版就直接跳到第 1 节。**

用小包的话，先确认 .NET 8 在位：

```
dotnet --list-runtimes
```

输出里应当出现 `Microsoft.NETCore.App 8.x.x`。没有的话，要么去装
[.NET 8 Runtime](https://dotnet.microsoft.com/download/dotnet/8.0)
（选 **.NET Runtime**，不需要 SDK），要么改用 standalone 版。

小包的好处是每个项目自带一份工具只占 6 MB；standalone 每个项目要占 76 MB。
团队机器统一装了 .NET 8 就用小包，否则用 standalone 省事。

这一步只有接入的人做一次。**策划完全不需要碰**——他们只右键。

---

## 1. 先确认它能跑（不改任何东西）

在解压出来的目录里打开命令行，执行：

```
Tools\Luban\gen.bat -t client -d json
```

跑完看 `Generated\Data\`，应当出现：

```
demo_tbitem.json
demo_tbmonster.json
```

这两个产物来自本包自带的 `DataTables\items.xlsx` 与 `monsters.xlsx`。
**看到它们就说明工具链完整可用**，接下来只是把路径改成你项目的。

跑不出来的话，99% 是第 0 步没做——`gen.bat` 会直接报出缺什么。

`-t client` 指定导出目标（`luban.conf` 里 `targets` 的名字），`-d json` 指定数据格式。
不带参数直接运行 `gen.bat` 会打印用法说明。日常导表用第 4 节的右键菜单，不用敲命令。

---

## 2. 接入你的项目：目录怎么摆

本包解压出来的结构**就是推荐布局本身**。把 `Tools\` 和 `DataTables\`
两个目录整体拷进你的开发目录根下即可：

```
你的开发目录/
├─ Docs/                     文档
├─ DataTables/               <- 从本包拷来，策划的地盘，Excel 都放这
│  ├─ items.xlsx
│  └─ monsters.xlsx
├─ Tools/                    <- 从本包拷来
│  └─ Luban/
│     ├─ runtime/             工具本体，不要动
│     ├─ luban.conf           唯一需要你改的文件
│     ├─ gen.bat              命令行导表
│     ├─ check.bat            只校验不导出
│     └─ contextmenu/         右键菜单：安装脚本 + 导表实现（不能删）
└─ Source/                   游戏工程
   └─ 你的游戏/
      ├─ Code/
      │  └─ Generated/        <- 导出的代码落在这
      └─ Run/Data/Generated/  <- 导出的数据落在这
```

三条原则，照着摆就不会错：

| 原则 | 为什么 |
|---|---|
| **Excel 只放 `DataTables/`** | 游戏工程里不该出现源表，只该有导出产物。策划改表不碰游戏工程。 |
| **`Tools/` 和 `DataTables/` 平级** | 工具不属于数据，也不属于某个工程；它服务于整个开发目录。 |
| **`luban.conf` 和 `runtime/` 必须放在一起** | 右键菜单靠 `Tools\Luban\luban.conf` 定位配置，再在旁边找 `runtime\`。拆开就找不到。 |

这也是官方 `luban_examples` 的做法（`DataTables/`、`Tools/`、`Projects/` 三者平级，
游戏工程内无源表），不是我们自创的约定。

**每个项目自带一套 `Tools/Luban/`**（约 6MB）。这样各项目的工具版本互相独立，
老项目不会因为别处升级 Luban 而被动出问题。

---

## 3. 改 `luban.conf`：三处路径

打开 `Tools\Luban\luban.conf`，只有三处和你的项目有关：

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

所有路径都**相对于 `Tools/Luban/` 自身**。按上面的布局，改成：

```json
{
  "dataDir": "../../DataTables",
  "xargs":
  [
    "outputDataDir=../../Source/你的游戏/Run/Data/Generated",
    "outputCodeDir=../../Source/你的游戏/Code/Generated"
  ]
}
```

`dataDir` 通常不用改——`../../DataTables` 在推荐布局下已经是对的。

> **`outputDataDir` 必须是 Luban 专用目录。**
> 全量导出前，Luban 会**清空输出目录里所有不属于本次产物的文件**——不管是不是它生成的。
> 所以别把它指向混放美术资源或手写配置的目录，那些文件会被删掉。
> 推荐用 `.../Run/Data/Generated/` 这类一眼看出是生成物的路径。
>
> （右键菜单的局部导表不受影响：脚本会关掉这个清理，否则导一张表就会删光其他表的产物。）

> **绝对不要给 `luban.conf` 加 JSON 注释（`//` 或 `/* */`）。**
> 右键菜单用 Windows 自带的 PowerShell 5.1 解析这个文件，它不支持 JSON 注释。
> 加了之后右键菜单**不会报错，而是静默读不到配置**然后走默认值——极难排查。
> 要写说明就写在本文件或项目文档里。

### 顺手确认两处输出格式

```json
"contextMenu":
{
  "data": { "targets": ["client"], "dataTarget": "json" },
  "code": { "targets": ["client"], "codeTargets": ["cs-simple-json"] }
}
```

`dataTarget` 是数据格式（`json` / `bin` / `xml` / `lua` / `yaml` …），
`codeTargets` 是代码语言（`cs-simple-json` / `cpp-rawptr-bin` / `java-json` …）。
按你的引擎改。Unity + JSON 用上面的默认值就行。

改完再跑一次 `gen.bat`，确认产物落到了你游戏工程的目录里。

---

## 4. 装右键菜单（给策划用的入口）

**以管理员身份**运行一次：

```
Tools\Luban\contextmenu\install_luban_context_menu.bat
```

装好后，在**任意文件夹、文件夹空白处、或单个 xlsx 上**右键，会多出两项：

- **Luban Export (Data)** —— 只导出所选范围内那些表的数据
- **Luban Export (Code)** —— 生成代码

它是全机器生效的（写 HKLM），**一台机器装一次**。菜单被点击时，脚本从你右键的位置
**向上最多 5 层**寻找 `Tools\Luban\luban.conf`，所以同一台机器上的多个项目各用各的配置，
互不干扰。

> **以后升级 EsyLuban 不需要再装一次。** 注册表指向的只是一个转发器，真正的导表逻辑
> 在你项目的 `Tools\Luban\contextmenu\` 里——下载新版发布包、替换掉 `Tools\Luban\`，
> 右键行为就跟着更新了。
>
> ⚠ 也因此，**`Tools\Luban\contextmenu\` 不能删**。它不是"装完就没用的安装器"，
> 右键每次导表都要调用它。删了会报 `Export script not found`。

想让多套工具并存（比如同时维护两个用不同 Luban 版本的项目），安装时加个名字：

```
install_luban_context_menu.bat MyGame
```

菜单会变成 `Luban Export (Data) - MyGame`，与默认安装互不覆盖。

卸载：`uninstall_luban_context_menu.bat`（同样需要管理员）。

---

## 5. 日常工作流

**策划**：

1. 打开 `DataTables/` 下自己那张 Excel，改数据
2. 存盘、关闭 Excel（**必须关掉**，否则文件被占用会导出失败）
3. 右键那个文件（或它所在的文件夹）→ **Luban Export (Data)**
4. 看窗口里有没有报错，没报错就完事了

**程序员**：

- 表结构变了（加/删列、改类型）→ 需要重新生成代码：右键 → **Luban Export (Code)**
- 想批量全量导出 → 命令行 `Tools\Luban\gen.bat`
- 只想校验数据不导出 → `Tools\Luban\check.bat`
- 把 `Generated/` 加不加版本控制，看团队习惯；加的话注意它是生成物，冲突时以源表为准

---

## 6. 新建一张表

最省事的办法是**复制 `items.xlsx` 改**。它就是一张标准表：

| | A | B | C | D | E |
|---|---|---|---|---|---|
| **1** | `##export` | `full_name="demo.TbItem" & read_schema_from_file="true"` | | | |
| **2** | `##var` | id | name | price | desc |
| **3** | `##type` | int | string | int | string |
| **4** | | 1001 | 木剑 | 50 | 新手用的练习剑 |
| **5** | | 1002 | 铁剑 | 300 | 标准铁剑 |

- **A1 固定写 `##export`**。想临时停掉这张表就写 `##export=false`。
- **B1 只有 `full_name` 是必填的**——它是这张表的身份，推导不出来。
  `read_schema_from_file="true"` 表示"结构就看下面的 `##var`/`##type` 两行"，
  自包含写法都要带上它。
  其余（`value_type`、`index`、`mode`、`output` …）**都有缺省，不需要写**。
- **`##var` 行是字段名，`##type` 行是字段类型**，从 B 列开始（A 列留给标记）。
- **第 4 行起是数据**，A 列留空。

一个 Excel 文件里可以放多张表，每张 sheet 都要有自己的 `A1`/`B1`。

完整的类型写法、校验器、多语言、多目标导出等等，看 `docs/esyluban_beginner_guide.md`。

---

## 7. 出问题先看这里

| 现象 | 原因 |
|---|---|
| `Luban runtime not found` | `runtime/` 没和 `luban.conf` 放在一起 |
| 提示缺少 .NET / 无法启动 | 用的是小包但没装 .NET 8，见第 0 节；换 standalone 版也行 |
| `Tools\Luban not found within 5 levels` | 右键的位置离 `Tools/Luban/` 超过 5 层，或没按推荐布局摆 |
| `No exportable tables found under: ...` | 右键的范围内没有带 `##export` 的表；A1 拼错也会这样 |
| 右键菜单没反应 / 菜单不出现 | 安装脚本没用管理员身份跑 |
| `Export script not found` | `Tools\Luban\contextmenu\` 被删了，见第 4 节的警告 |
| 右键能跑但配置像没生效 | `luban.conf` 里加了 JSON 注释，见第 3 节的警告 |
| 导出报文件被占用 | Excel 还开着，关掉再导 |
| 表改了但产物没变 | 改的表不在右键选中的范围内，或 A1 写成了 `##export=false` |
| 导出后输出目录里别的文件不见了 | `outputDataDir` 指向了非专用目录，见第 3 节的警告 |
| 目录名以 `_` 或 `.` 开头，里面的表全被忽略 | 这是 Luban 的规则：`_`/`.`/`~` 开头的路径段一律跳过。改名即可 |

---

## 8. 完整文档

- `docs/esyluban_beginner_guide.md` —— 完全手册。A 章给策划，B 章给程序员。
- 上游 Luban 官方文档：<https://www.datable.cn/>（类型系统、校验器等通用能力完全一致）

EsyLuban 基于 [Luban](https://github.com/focus-creative-games/luban)，MIT 许可证。
