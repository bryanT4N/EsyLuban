# EsyLuban 完全手册（面向策划与程序）

这是一份**生产流程手册**，给真正使用的人看的：  
第一读者是策划，第二读者是程序员。  
策划只需要理解能正确写表与右键导表；  
程序员需要理解配置链路、每个参数的影响、完整示例与最佳实践。  

说明：本手册所有内容均基于源码与脚本行为验证，并对官方文档进行二次查证重写（参考 [Luban 官方文档](https://www.datable.cn/docs/intro)）。  

---

## A. 给策划的使用说明（只学你需要的）

### A1. 你只需要记住的 5 件事

1) **右键导表**是唯一入口。  
2) 每个 Sheet 都必须有 `A1=##export` 与 `B1=表定义`。  
3) 表头必须有 `##var`（字段名）与 `##type`（字段类型）。  
4) 类型写错会导致导出失败（尤其是 bool、enum、text）。  
5) 出错看提示：会告诉你哪个表、哪一行有问题。  

---

### A2. 你的日常工作流程（生产流程）

1) 按模板写表（A3）。  
2) 保存 Excel。  
3) 在 Excel 文件或数据目录上 **右键 -> Luban Export**。  
4) 等待生成完成。  

你不需要了解命令行或脚本细节。  

---

### A3. 表的标准写法（可视化示例）

#### A3.1 每张表必须有的两行

- **A1**：`##export`  
- **B1**：表定义  

```
A1: ##export
B1: full_name="item.TbItem"
```

**`full_name` 是唯一必填项**，其余字段都有缺省，能不写就不写：

| 字段 | 不写时 | 什么时候才需要写 |
|---|---|---|
| `value_type` | 由表名推导：`TbItem` → `Item` | 值类型名不遵循 `Tb` 前缀约定时 |
| `output` | 由全名生成：`item.TbItem` → `item_tbitem` | 想自定义输出文件名时 |
| `input` | 指向本 sheet 自己 | 数据在别的文件 / 多个数据源时 |
| `index` | 取值类型的第一个字段 | 主键不是第一个字段时 |
| `mode` | `map` | 单例表填 `one`，列表表填 `list` |
| `read_schema_from_file` | `false`（结构来自 XML 或 `__beans__`） | 想让结构也写在本表标题行里，填 `true` |

需要时再逐项添加，例如：

```
B1: full_name="item.TbItem" & index="uid" & mode="list" & comment="道具表"
```

补充：  
- `A1=##export=false` 表示该 Sheet 不导出  
- 输出文件的默认命名规则：`full_name` 中 `.` → `_` 并转小写  

#### A3.2 标准表头

```
##var   id    name    price    desc
##type  int   string  int      text
```

含义：  
- `##var`：字段名  
- `##type`：字段类型  

#### A3.3 完整表模板（可直接照抄）

```
┌────────┬───────────────────────────────────────────────────────────────────────┐
│ A1     │ ##export                                                              │
│ B1     │ full_name="item.TbItem"                                               │
├────────┼────────┬──────────┬────────┬──────────┬──────────┐
│ ##var  │ id     │ name     │ price  │ quality  │ desc     │
│ ##type │ int    │ string   │ int    │ int      │ text     │
├────────┼────────┼──────────┼────────┼──────────┼──────────┤
│ 1      │ 1001   │ Sword    │ 200    │ 1        │ /item_1001 │
│ 2      │ 1002   │ Shield   │ 150    │ 2        │ /item_1002 │
└────────┴────────┴──────────┴────────┴──────────┴──────────┘
```

说明：  
- `desc` 用 `text` 表示本地化 key。  
- `quality` 可以直接填枚举值或数字。  

---

### A4. 你会遇到的类型写法（含可视化例子）

#### A4.1 基础类型

- `int`：整数  
- `float`：小数  
- `bool`：只能写 `true/false/0/1`  
- `string`：字符串  
- `text`：本地化 key（如 `/item_1001`）  

#### A4.2 enum（枚举）

可以填：  
1) 枚举名字  
2) 枚举别名  
3) 数字值  

示例：
```
Common
Rare
3
```

#### A4.3 list（列表）

推荐写法（在一个单元格里填多值）：  
```
##var  ids#sep=;
##type list,int
```

数据填写：
```
1;2;3;4
```

#### A4.4 资源路径（路径校验）

如果字段是资源路径（图片、Prefab 等），通常由程序员定义为 `string#path=unity`，  
你只需要填写正确的资源相对路径。  

示例：
```
Assets/Prefabs/Item/Item_1001.prefab
```

#### A4.4.1 map（键值表，按模板填写）

map 的写法比较容易出错，**必须按程序员提供的模板填写**。  
常见模板如下（key/value 两列一组）：

```
##var   id   rewards   rewards
##var        $key      $value
##type  int  int       int

1       1001 2
```

含义：  
- `$key` 与 `$value` 成对出现  
- 如果需要多对 key/value，按模板继续扩展列或行  

#### A4.5 单例表（只配一条全局数据）

如果某张表只有一条全局数据（例如“全局配置”），  
程序员会在 B1 中把 `mode` 设为 `one`。  
你只需要填写**一行**数据即可。

示例（单例表写法）：
```
A1: ##export
B1: full_name="global.TbGlobal" & mode="one"

##var  openLevel  maxBag
##type int        int
      10          200
```

#### A4.6 text（本地化文本）

`text` 字段不是最终文案，而是“文案 key”。  
你只需要填 key，例如：
```
/item_1001_name
/ui_confirm_ok
```

这些 key 会在导出时被校验，如果不存在就会报错。  

---

### A5. 你可以放心忽略的内容

以下内容由程序员负责配置，你不需要修改：  
- 输出目录、校验参数、本地化参数（都在 `luban.conf` 里）  
- 字段类型上的校验标签，如 `string#path=unity`、`#sep=;`  

B1 里你会用到的只有 `full_name`（表的名字），偶尔加 `mode="one"`（单例表）。  
其余字段（`value_type` / `index` / `output` / `input` 等）都有默认值，
需要偏离默认时由程序员补写。

**原则：策划照模板写数据，不改字段类型与配置。**  

---

### A6. 常见错误与快速排查（策划版）

- **表不导出**：A1 不是 `##export`，或 B1 缺失。  
- **bool 报错**：写了 `Yes/No` 或其它非 `true/false/0/1`。  
- **枚举报错**：写了不存在的枚举名。  
- **text 报错**：写了不存在的 key。  
- **路径报错**：资源路径不存在或拼写错误。  

---

### A7. 导出结果在哪里（策划只需知道）

导出结果目录由程序员在 `luban.conf` 里配置。  
你只需要记住：  
- 右键导表后，配置文件会写入项目指定目录。  
- 如果失败，会告诉你具体表与行号。  

---

### A8. 策划常用表模板（拿来就用）

> B1 里**只有 `full_name` 必须写**。下面模板里出现的其它字段，都是"确实需要偏离默认"时才加的。

#### A8.1 道具表（最常见）

```
A1: ##export
B1: full_name="item.TbItem"

##var  id  name   price  iconPath               desc
##type int string int    string#path=unity      text
1001   Sword 200  Assets/Icons/Item/1001.png    /item_1001
```

注意：  
- `string#path=unity` 是程序员配置的校验标签，策划不要改  
- 值类型（`item.Item`）、主键（第一个字段 `id`）、输出文件名（`item_tbitem`）都是自动的，不用写  

#### A8.2 全局表（单例）

```
A1: ##export
B1: full_name="global.TbGlobal" & mode="one"

##var  openLevel  maxBag
##type int        int
10     200
```

> 单例表只有 `mode="one"` 需要写 —— 默认是 `map`（按主键查的普通表）。

#### A8.3 运营奖励表（列表）

```
A1: ##export
B1: full_name="mail.TbRewards"

##var  id  rewards#sep=;
##type int list,int
1      1001;1002;1003
```

> list 写法依赖 `#sep`，按模板填写，不要改结构。  
> 这里的 `list` 指字段类型；若要整张表以列表形式导出（无主键），才写 `mode="list"`。  

---

### A9. 策划填写习惯（减少错误）

- bool 只写 `true/false/0/1`  
- text 字段只写 key（不要写中文原文）  
- 路径字段必须确认资源真实存在  
- 不要随意改 B1 或表头结构  

---

### A10. 策划自检清单（右键前快速检查）

1) A1 是否为 `##export`  
2) B1 是否存在且完整  
3) 表头是否有 `##var` / `##type`  
4) bool 是否只用 `true/false/0/1`  
5) text 是否为合法 key  

## B. 给程序员的完整配置说明（含最佳实践）

这一部分按“影响链路”组织：  
- 配置如何影响导出  
- 参数应该如何写（推荐/不推荐）  
- 可执行的实战示例  

---

### B0. 环境准备（clone 之后第一件事）

**Luban 运行时不进版本控制**，clone 下来 `esyluban/runtime/` 是空的。
必须先构建，否则 `gen.bat` / `check.bat` / 右键菜单都会报
`Luban runtime not found`：

```
esyluban\scripts\build.bat
```

它从仓库的 `src/` 构建出完整运行时（含各语言代码生成器）到 `esyluban/runtime/`。
需要 .NET SDK（本项目在 .NET 9 上验证）。

为什么不把 dll 提交进仓库：60 个二进制每次重建都会在 git 历史里留下新 blob，
仓库体积会随开发次数线性且不可逆地膨胀。

**工具只存这一份。** 各示例工程的 `Tools/Luban/` 里只有自己的 `luban.conf` 与
`gen/check.bat`，它们会向上搜索定位共享运行时。因此工具更新后**不需要**再往
各工程复制副本。

其它常用入口：

```
esyluban\scripts\test\run_full_tests_example.bat   全量回归 + 双基线比对
esyluban\scripts\test\run_unit_tests.bat           B1Parser 单元测试
esyluban\scripts\contextmenu\install_luban_context_menu.bat   安装右键菜单（需管理员）
```

> 注册表指向的是 `%ProgramData%\EsyLuban` 下的脚本副本，
> 所以改动 `scripts/contextmenu/` 下的脚本后，需**重新运行一次安装脚本**才生效。

---

### B1. 生产配置原则（必须遵守）

1) **单一来源**  
   - 所有输出/L10N/校验参数只写在 `Tools/Luban/luban.conf` 的 `xargs`。  
   - **不推荐**：脚本中覆盖这些参数。  

2) **右键菜单只做一件事**  
   - 只覆盖 `tableImporter.scanPath`，其它参数来自 `luban.conf`。  
   - **不推荐**：在右键脚本里拼接输出目录或 L10N 参数。  

3) **相对路径统一基准**  
   - 所有相对路径以 `Tools/Luban` 为基准。  
   - **不推荐**：让脚本在随机目录执行。  

---

### B2. 生产级 `luban.conf` 完整示例（逐行解释）

#### B2.1 示例配置

```
{
  "groups": [
    {"names":["c"], "default": true},
    {"names":["s"], "default": true},
    {"names":["e"], "default": true},
    {"names":["t"], "default": false}
  ],
  "schemaFiles": [
    {"fileName":"../../DataTables/Defines", "type":""},
    {"fileName":"../../DataTables/__beans__.xlsx", "type":"bean"},
    {"fileName":"../../DataTables/__enums__.xlsx", "type":"enum"}
  ],
  "dataDir": "../../DataTables",
  "targets": [
    {"name":"test", "manager":"Tables", "groups":["t"], "topModule":"cfg"},
    {"name":"server", "manager":"Tables", "groups":["s"], "topModule":"cfg"},
    {"name":"client", "manager":"Tables", "groups":["c"], "topModule":"cfg"},
    {"name":"editor", "manager":"Tables", "groups":["c"], "topModule":"editor.cfg"},
    {"name":"all", "manager":"Tables", "groups":["c","s","e"], "topModule":"cfg"}
  ],
  "xargs": [
    "outputDataDir=../../TestOutputs/json/all",
    "all.outputDataDir=../../TestOutputs/json/all",
    "client.outputDataDir=../../TestOutputs/json/client",
    "server.outputDataDir=../../TestOutputs/json/server",
    "editor.outputDataDir=../../TestOutputs/json/editor",
    "test.outputDataDir=../../TestOutputs/json/test",
    "outputCodeDir=../../TestOutputs/code/all",
    "client.outputCodeDir=../../TestOutputs/code/client",
    "server.outputCodeDir=../../TestOutputs/code/server",
    "editor.outputCodeDir=../../TestOutputs/code/editor",
    "cs-simple-json.outputCodeDir=../../TestOutputs/code/cs-simple-json",
    "pathValidator.rootDir=../../DataTables",
    "l10n.provider=default",
    "l10n.textFile.path=../../DataTables/l10n/texts.xlsx",
    "l10n.textFile.keyFieldName=key",
    "l10n.textFile.languageFieldName=zh",
    "l10n.convertTextKeyToValue=1"
  ]
}
```

#### B2.2 每段的作用与推荐写法

- `groups`  
  - **作用**：决定表/字段是否被导出  
  - **推荐**：`c/s/e` 分工清晰  
  - **不推荐**：多个 group 重复或无默认值  

- `schemaFiles`  
  - **作用**：schema 定义入口  
  - **推荐**：统一放 `DataTables/Defines` / `__beans__` / `__enums__`  
  - **不推荐**：在多个目录分散 schema  

- `dataDir`  
  - **作用**：数据根目录  
  - **推荐**：固定为 `DataTables`  
  - **不推荐**：频繁变动，导致脚本与右键扫描混乱  

- `targets`  
  - **作用**：导出目标与命名空间  
  - **推荐**：保留 `client/server/editor/all`，并为每个 target 设计清晰的 group 范围  
  - **不推荐**：多个 target 共用同一输出目录  
  - **说明**：  
    - `client` 只导出 `c` 组  
    - `server` 只导出 `s` 组  
    - `editor` 使用独立命名空间 `editor.cfg`  
    - `all` 导出 `c/s/e`  
    - `test` 仅用于 `t` 组  

- `xargs`  
  - **作用**：所有运行参数的唯一来源  
  - **推荐**：输出/L10N/校验全部写在这里  
  - **不推荐**：脚本再次覆盖  

补充：  
- 如果需要生成代码，**推荐**在 `xargs` 中增加 `outputCodeDir`（或按 codeTarget 区分）  

---

#### B2.3 导出文件结构示意（基于上面的配置）

该配置使用 `all/client/server/editor/test.outputDataDir`，因此导出结果默认按 **表 target** 分目录。  
**规则**：`{target}.outputDataDir` 优先，其次 `{dataTarget}.outputDataDir`，最后 `outputDataDir`。  
不同 `target` 会导致**导出内容不同**（文件名来自 B1 `output` 或默认规则）。  
如需生成代码，请在 `xargs` 中补充 `{codeTarget}.outputCodeDir` 或全局 `outputCodeDir`。

**当导出 client（只包含 c 组）**：
```
TestOutputs/json/client/
├─ item_tbitem.json        # c 组表
├─ mail_tbrewards.json     # c 组表
└─ ...                     # 其它 c 组表
```

**当导出 server（只包含 s 组）**：
```
TestOutputs/json/server/
├─ combat_tbskill.json     # s 组表
├─ drop_tbdrop.json        # s 组表
└─ ...
```

**当导出 all（包含 c/s/e 组）**：
```
TestOutputs/json/all/
├─ item_tbitem.json        # c 组表
├─ combat_tbskill.json     # s 组表
├─ editor_tbscene.json     # e 组表
└─ ...
```

> **最佳实践**：为每个表显式写 `output`，确保输出文件名稳定且可读。  

#### B2.4 target 与 group 对照（速查）

| target | groups | 典型用途 |
|---|---|---|
| client | c | 客户端运行数据 |
| server | s | 服务端运行数据 |
| editor | c | 编辑器或工具数据 |
| test | t | 仅测试或内部数据 |
| all | c/s/e | 全量导出（生产常用） |

### B3. xargs 参数详解（必须掌握）

#### B3.1 输出目录与文件名

- `outputCodeDir`  
  - **作用**：代码输出目录  
  - **推荐**：写入 `xargs`  
  - **不推荐**：脚本覆盖或临时改动  

- `outputDataDir`  
  - **作用**：数据输出目录  
  - **推荐**：写入 `xargs`  
  - **不推荐**：输出到临时目录  

- `{target}.outputDataDir` / `{dataTarget}.outputDataDir`  
  - **作用**：按 target / dataTarget 细分**数据**输出目录  
  - **说明**：data 输出优先 `{target}.outputDataDir`，再回退到 `{dataTarget}.outputDataDir` 与全局 `outputDataDir`  
  - **推荐**：多 target 时配置  
  - **不推荐**：不同 target 共用目录  
- `{target}.outputCodeDir` / `{codeTarget}.outputCodeDir`  
  - **作用**：按 target / codeTarget 细分**代码**输出目录  
  - **说明**：code 输出优先 `{target}.outputCodeDir`，再回退到 `{codeTarget}.outputCodeDir` 与全局 `outputCodeDir`  
  - **推荐**：双端同语言但目录不同必须配置 `{target}.outputCodeDir`  
  - **不推荐**：不同 target 共用目录  

- `{dataTarget}.fileExt`  
  - **作用**：数据文件后缀  
  - **推荐**：仅在需要兼容旧系统时使用  
  - **不推荐**：随意改后缀导致加载失败  

#### B3.2 输出保存器

- `outputSaver`  
  - **作用**：决定是否落盘  
  - **推荐**：`local`  
  - **不推荐**：`null`（生产会导致无数据输出）  

- `outputSaver.{target}.cleanUpOutputDir`  
  - **作用**：导出前清理旧文件  
  - **推荐**：保持默认（true）  
  - **不推荐**：关闭导致旧文件残留  

#### B3.3 数据导出与后处理

- `dataExporter`  
  - **作用**：数据导出器  
  - **推荐**：默认 `default`  
  - **不推荐**：未经扩展验证自行替换  

- `codePostprocess` / `dataPostprocess`  
  - **作用**：导出后处理  
  - **推荐**：仅在明确需求时启用  
  - **不推荐**：无意义叠加多个处理器  

#### B3.4 命名与编码

- `codeStyle`  
  - **推荐**：使用内置语言默认风格  
  - **不推荐**：跨语言混用风格  
  - **示例**：`csharp-default` / `java-default`  

- `namingConvention.*`  
  - **推荐**：集中配置一套规范  
  - **不推荐**：同 target 内混乱配置  
  - **示例**：`namingConvention.cs-bin.field=pascal`  

- `{code|data}.lineEnding`  
  - **推荐**：默认值即可  
  - **不推荐**：跨平台频繁切换  

- `{codeTarget|dataTarget}.fileEncoding`  
  - **推荐**：必要时指定  
  - **不推荐**：用非 UTF8 导致工具链问题  

#### B3.5 JSON 输出

- `json.compact`  
  - **推荐**：生产可设为 1  
  - **不推荐**：调试期全局启用（影响阅读）  

#### B3.6 tableImporter

- `tableImporter.scanPath`  
  - **作用**：限制扫描范围  
  - **推荐**：仅由右键菜单覆盖  
  - **不推荐**：写死在 `xargs`（会限制全局扫描）  

#### B3.7 CodeTarget / DataTarget 匹配规则

必须确保代码目标与数据目标格式一致，否则运行时加载失败。  

常见匹配：  
- `cs-simple-json` + `json`  
- `cs-bin` + `bin`  
- `java-json` + `json`  
- `go-bin` + `bin`  

**推荐**：一个项目固定一套组合。  
**不推荐**：多个组合混用同一输出目录。  

#### B3.8 类型映射（Type Mapper）

如果你希望生成代码直接使用已有类型，可用 mapper 映射。  

**推荐**：只在必要时使用。  
**不推荐**：对所有类型强行映射导致代码不可维护。  

---

### B4. 表定义（B1）字段的真实影响

B1 字段决定表结构与导出行为。以下是必须掌握的链路。

- `full_name`  
  - **作用**：表的唯一身份  
  - **影响**：输出文件名、运行时代码访问名  
  - **不推荐**：上线后频繁修改（会破坏运行时引用）  

- `value_type`  
  - **作用**：记录结构  
  - **影响**：解析规则与校验类型  

- `index`  
  - **作用**：表的 key  
  - **影响**：访问方式与索引结构  
  - **规则**：  
    - 空 → 默认取第一个字段  
    - `a+b` → 联合索引  
    - `a,b` → 独立索引  

- `mode`  
  - `map`：key → record  
  - `list`：多 key 列表  
  - `one`：单例表  
  - **不推荐**：`one` 仍设置 index  

- `read_schema_from_file`  
  - true：从数据文件读取 schema  
  - false：从全局 schema 读取  
  - **推荐**：结构与数据同文件时 true  

- `input`  
  - **作用**：数据源路径  
  - **影响**：决定 DataLoader 的输入文件  
  - **不推荐**：写错导致数据为空  

- `output`  
  - **作用**：覆盖输出文件名  
  - **推荐**：生产环境**显式写 output**，保证文件名稳定  
  - **命名建议**：全小写、下划线、与表名对应  
  - **不推荐**：随意改名导致加载路径不一致  

---

### B5. 右键菜单链路（生产入口）

右键菜单分为两个入口：  
- **Luban Export (Data)**：按顺序导出 `client/server/editor` 的数据  
- **Luban Export (Code)**：生成 Unity 客户端代码（`client + cs-simple-json`）  

推荐在 `luban.conf` 中配置右键行为（无需改脚本）：  
```
"contextMenu": {
  "data": {
    "targets": ["client","server","editor"],
    "dataTarget": "json",
    "extraArgs": []
  },
  "code": {
    "target": "client",
    "codeTargets": ["cs-simple-json"],
    "extraArgs": []
  }
}
```
说明：  
- `data.targets` 中加入 `test` 可让右键导出 test 数据  
- `data.dataTarget` 控制 `-d`（json/bin 等）  
- `code.target` 控制表 target（client/server）  
- `code.codeTargets` 控制 `-c` 列表  
- `extraArgs` 可追加参数（如 `--variant` / `--includeTag` / `--validationFailAsError` / `-x key=val`）

通用流程：  
1) 右键 Excel 或目录  
2) 向上 5 层定位 `Tools/Luban`  
3) 调用对应脚本  
4) 数据入口会覆盖 `tableImporter.scanPath`，代码入口不覆盖  

程序员必须保证：  
- `Tools/Luban` 路径可被向上定位  
- `luban.conf` 可被找到  
- `xargs` 参数完整（尤其是 `{target}.outputDataDir` 与 `{target}.outputCodeDir`）  

---

### B6. 实战示例：Unity + JSON 的完整解释

#### B6.1 配置示例

```
"xargs": [
  "outputCodeDir=../../Projects/Csharp_Unity_json/Assets/Gen",
  "cs-simple-json.outputCodeDir=../../Projects/Csharp_Unity_json/Assets/Gen",
  "client.outputCodeDir=../../Projects/Csharp_Unity_json/Assets/Gen",
  "client.outputDataDir=../../Projects/Csharp_Unity_json/Assets/StreamingAssets/cfg",
  "outputDataDir=../../Projects/Csharp_Unity_json/Assets/StreamingAssets/cfg",
  "pathValidator.rootDir=../../Projects/Csharp_Unity_json",
  "l10n.provider=default",
  "l10n.textFile.path=../../DataTables/l10n/texts.xlsx",
  "l10n.textFile.keyFieldName=key",
  "l10n.textFile.languageFieldName=zh",
  "l10n.convertTextKeyToValue=1"
]
```

#### B6.2 每行的作用

- `outputCodeDir`：代码输出兜底目录  
- `client.outputCodeDir`：按 target 分离代码输出（推荐）  
- `cs-simple-json.outputCodeDir`：按 codeTarget 分离代码输出  
- `client.outputDataDir`：按 target 分离数据输出（推荐）  
- `outputDataDir`：数据输出兜底目录  
- `pathValidator.rootDir`：资源路径校验基准  
- `l10n.*`：本地化校验与静态替换  

#### B6.3 生成产物示例

- `Assets/Gen/cfg/Tables.cs`  
- `Assets/StreamingAssets/cfg/item_tbitem.json`  

---

### B7. 导表链路（从配置到产物）

导出链路用一句话总结：  
**配置 -> 读取表 -> 校验 -> 本地化 -> 生成代码/数据 -> 落盘**  

```mermaid
flowchart TD
  A["luban.conf + xargs"] --> B["SchemaCollector"]
  B --> C["RawAssembly"]
  C --> D["DefAssembly"]
  D --> E["DataLoader"]
  E --> F["DataValidator"]
  F --> G["L10N Processor"]
  D --> H["CodeTarget(s)"]
  G --> I["DataTarget(s)"]
  H --> J["OutputSaver"]
  I --> J
```

**关键影响点**：  
- `schemaFiles` 决定结构类型能否解析  
- `tableImporter.scanPath` 决定扫描范围  
- `xargs` 决定输出、校验、本地化  

---

### B8. 表头与字段标签（必须精通）

#### B8.1 表头行规则

- `##var`：字段名  
- `##type`：字段类型  
- `##group`：字段分组  
- `##comment` / `##desc`：注释  
- `##column` / `##vertical`：纵表  
- `##+`：补充子标题  

**推荐**：始终按 `##var` → `##type` → `##group` → `##comment` 结构写。  
**不推荐**：随意换顺序导致模板难以阅读。  

#### B8.2 字段标签（写在 `##var`）

格式：`field#tag=value#tag2=value`  

可用标签：  
- `sep`：分隔符  
- `non_empty`：不可为空  
- `multi_rows`：多行结构  
- `default`：默认值  
- `format`：紧凑格式  

示例：  
```
rewardIds#sep=;
position#format=lite
```

**推荐**：字段标签只用于“数据填写习惯”。  
**不推荐**：滥用字段标签改变业务意义。  

---

#### B8.3 常见表头组合（可视化）

示例：带 group 与 comment 的表头

```
##var     id   name   price
##type    int  string int
##group   c    c      s
##comment 道具ID 名称  价格
```

说明：  
- `##group` 空表示所有分组导出  
- `##comment` 或 `##desc` 为字段注释  

#### B8.4 字段标签逐项解释

- `sep`  
  - **作用**：把一个单元格拆成多个值  
  - **示例**：`ids#sep=;` 搭配 `list,int`  
  - **不推荐**：使用 `#` 或 `&` 作为分隔符  

- `format`  
  - **作用**：紧凑格式（`stream`/`lite`/`json`/`lua`）  
  - **推荐**：复杂嵌套用 `lite`  

- `default`  
  - **作用**：空值默认值  
  - **推荐**：用于有限字段  

- `non_empty`  
  - **作用**：禁止空值  
  - **推荐**：关键字段  

- `multi_rows`  
  - **作用**：多行结构  
  - **推荐**：大型结构列表  

#### B8.5 紧凑格式示例（lite）

字段：
```
##var  pos#format=lite
##type Vec3
```

填写：  
```
{1.0,2.0,3.0}
```

#### B8.6 多级标题头（限定列写法）

多级标题可以让复杂结构更清晰。  

示例（结构列表）：
```
##var  id   rewards     rewards
##var       id          count
##type int  int         int
```

说明：  
- `rewards` 被拆成两个子字段  
- 多级标题避免流式格式的歧义  

#### B8.7 纵表与横表

- 横表：默认方式，一行一条记录  
- 纵表：`##column` / `##vertical`  

纵表示例：
```
##column
##var   key    value
##type  string string
name    Sword
price   200
```



### B9. 类型系统与数据源

#### B9.1 基础类型

- `bool` / `byte` / `short` / `int` / `long`  
- `float` / `double`  
- `string`  
- `datetime`（输出为 UTC 秒）  
- `text`（本地化 key）  

补充规则：  
- `string` 空单元格表示空字符串  
- `text` 必须在本地化表中存在  
- `datetime` 支持格式：`yyyy-M-d HH:mm:ss` / `yyyy-M-d HH:mm` / `yyyy-M-d HH` / `yyyy-M-d`  

#### B9.2 容器类型

- `array,<T>`  
- `list,<T>`  
- `set,<T>`  
- `map,<K>,<V>`  

**推荐**：`map` 的 key 使用基础类型或 enum。  
**不推荐**：用复杂结构作为 map key。  

#### B9.3 可空类型

写法：`int?` / `MyBean?`  
**推荐**：明确需要空值时才用可空。  
**不推荐**：把所有字段都改成可空。  

#### B9.4 enum 与 flags

- 普通 enum：可填枚举名/别名/数值  
- flags enum：可用 `A|B` 表示组合  
- 如需指定分隔符，可用 `sep`  

示例：
```
QualityA|QualityB
```

#### B9.5 Bean 与多态 Bean

- Bean 在 Excel 中通常用多列展开  
- 多态 Bean 需要 `$type` 指定具体子类  

示例：
```
##var  id  effect
##var      $type  $value
##type int string string
```

#### B9.6 非 Excel 数据源（JSON/Lua/XML/YAML/Lite）

当表的 `input` 指向非 Excel 文件时：  
- JSON 多态字段使用 `$type`  
- Lua 多态字段使用 `_type_`  
- JSON 的 map 使用 `[[k,v]]` 列表形式  

示例（JSON 单条记录）：
```
{
  "id": 1001,
  "name": "Sword",
  "attrs": [[1,10],[2,20]],
  "skill": {"$type":"Fire","damage":10}
}
```

#### B9.7 input 写法（程序员必须精确配置）

- `sheet@file.xlsx`：读取指定 sheet  
- `file.xlsx`：读取所有可导出 sheet  
- `dir`：递归读取目录  
- `*@file.json`：读取记录列表  
- `*field@file.json`：读取 field 内的记录列表  
- `field@file.json`：读取 field 内单条记录  

**推荐**：相对路径以 `dataDir` 为基准。  
**不推荐**：混用相对与绝对路径。  



---

### B10. 多态与特殊列（Excel 写法）

- `$type`：多态 bean 的实际类型  
- `$value`：多态值列（限定列写法）  
- `$key`：map 的 key 列  

示例（多态 bean）：
```
##var  id  skill
##var      $type  $value
##type int string string
```

---

### B11. Schema 定义文件（结构模板）

#### B11.1 `__enums__.xlsx`

主列：  
- `full_name` / `flags` / `unique` / `group` / `comment` / `tags` / `*items`  

items 子列：  
- `name` / `alias` / `value` / `comment` / `tags`  

字段说明：  
- `flags`：是否为位枚举（true/false）  
- `unique`：枚举值是否唯一  
- `alias`：枚举别名（可空）  

示例：
```
full_name        flags unique  *items
item.EQuality    false true    Common  1
                               Rare    2
```

#### B11.2 `__beans__.xlsx`

主列：  
- `full_name` / `parent` / `valueType` / `sep` / `alias` / `group` / `comment` / `tags` / `*fields`  

fields 子列：  
- `name` / `type` / `alias` / `group` / `comment` / `tags` / `variants`  

字段说明：  
- `parent`：继承父类  
- `valueType`：是否为值类型  
- `sep`：默认分隔符  
- `variants`：字段变体  

#### B11.3 XML Schema（放在 `DataTables/Defines`）

常见元素：  
- `<module>`：模块命名空间  
- `<enum>`：枚举  
- `<bean>`：结构  
- `<table>`：表定义  
- `<refgroup>`：引用组  
- `<constalias>`：常量别名  
- `<mapper>`：类型映射  

示例（简化）：
```
<module name="item">
  <bean name="Item">
    <var name="id" type="int"/>
    <var name="name" type="string"/>
  </bean>
</module>
```


示例：
```
full_name      *fields
item.Item      id   int
               name string
               price int
```

**推荐**：全局结构写在 `__beans__` / `__enums__`。  
**不推荐**：重复定义导致类型冲突。  

---

### B12. 内联 schema（同文件局部定义）

在数据表 Excel 内加入 `__enums__` / `__beans__` 子表：  
- 作用域为 file-wide  
- 适合“仅该文件使用”的类型  

**推荐**：局部 schema 与表在同一文件时使用。  
**不推荐**：大量公共类型写成内联，导致重复维护。  

---

### B13. 校验器（每个都要理解）

#### B13.1 not-default

- 写法：`int!` / `string!` / `int?!`  
- 用途：防止默认值  
- **推荐**：主键或关键字段  
 - **不推荐**：对可空字段滥用导致无法留空  

#### B13.2 regex

- 写法：`string#(regex=^[A-Z]{3}$)`  
- **推荐**：固定格式字段  
 - **不推荐**：复杂正则造成维护困难  

#### B13.3 range

- 写法：`int#range=[1,10]`  
- **推荐**：等级、范围值  
 - 支持：`[1,10]` / `(1,10)` / `[1,)` / `(,100)`  

#### B13.4 set

- 写法：`int#(set=1;2;3)`  
- **推荐**：枚举值未定义时使用  
 - **不推荐**：忘记括号导致解析错误  

#### B13.5 size

- 写法：`(list#size=4),int`  
- **推荐**：固定长度配置  
 - 注意：`size` 必须写在容器类型上  

#### B13.6 index

- 写法：`(list#index=id),Foo`  
- **推荐**：列表中需要唯一索引时  
 - 生成代码会额外生成索引映射  

#### B13.7 ref

- 写法：`int#ref=item.TbItem`  
- **推荐**：所有跨表引用字段  
- **不推荐**：不设 ref 导致运行期错误  
 - `?`：允许空值不检查  
 - list 表：`key@table`  
 - 单例表：`key@table`（key 必须为 map）  

#### B13.8 path

- 写法：`string#path=unity`  
- **推荐**：资源路径字段  
 - 依赖 `pathValidator.rootDir`  

#### B13.9 text

- `text` 等价 `string#text=1`  
- **推荐**：所有本地化字段  
 - 未配置 l10n 时将跳过校验  

---

### B14. 本地化（L10N）完整示例

#### B14.1 文本表结构（JSON）

```
[
  {"key":"/item_1001","zh":"长剑","en":"Sword"},
  {"key":"/item_1002","zh":"盾牌","en":"Shield"}
]
```

注意：  
- JSON 列表必须用 `*@` 前缀读取  
- 字段名与 `l10n.textFile.*` 必须一致  

#### B14.2 xargs 对应配置

```
l10n.provider=default
l10n.textFile.path=../../DataTables/l10n/texts.xlsx
l10n.textFile.keyFieldName=key
l10n.textFile.languageFieldName=zh
l10n.convertTextKeyToValue=1
```

**推荐**：生产环境开启静态本地化。  
**不推荐**：`text` 字段不做校验。  

---

### B15. 输出文件命名规则（影响运行时）

- 默认输出名：`table.FullName` 中 `.` → `_` 并转小写  
  - 例：`item.TbItem` → `item_tbitem`  
- `B1 output=xxx` 可覆盖默认输出名  
- `{dataTarget}.fileExt` 可改变后缀  

**推荐**：生产环境显式填写 `output`，锁定文件名并避免误改。  
**不推荐**：完全依赖默认命名（易被表名变动影响）。  
**不推荐**：频繁改名导致运行时代码与配置不匹配。  

---

### B16. 右键菜单技术细节（程序员必须知道）

右键菜单全局安装逻辑：  
- 安装脚本会复制到 `%ProgramData%\EsyLuban\run_luban_context_menu_data.bat` 与 `run_luban_context_menu_code.bat`
- 注册到：  
  - `HKLM\Software\Classes\Directory\shell\LubanExport`  
  - `HKLM\Software\Classes\*\shell\LubanExport`  

运行逻辑：  
- 向上 5 层定位 `Tools/Luban/luban.conf`  
- 调用导出，仅覆盖 `tableImporter.scanPath`  

**推荐**：只改 `luban.conf`，不改右键脚本中的路径逻辑。  
**不推荐**：在右键脚本中堆叠其它参数。  

---

### B17. 实战示例（结构 + 数据 + 输出）

#### B17.1 B1 配置

```
full_name="item.TbItem" & value_type="item.Item" & index="id" & mode="map"
```

#### B17.2 `__beans__.xlsx`

```
full_name     *fields
item.Item     id    int
              name  string
              price int
              desc  text
```

#### B17.3 数据表

```
##var  id  name   price  desc
##type int string int    text
1001   Sword 200  /item_1001
```

#### B17.4 输出结果

- `client.outputDataDir/item_tbitem.json`  
- `Tables.TbItem.Get(1001)` 可访问对应记录  

---

### B18. 字段变体（Variants）

用途：同一字段为不同地区/版本提供不同值。  

定义方式：  
- 在 `__beans__.xlsx` 的 `variants` 字段写 `zh,en`  
- 在数据表头写 `field@zh`、`field@en`  

示例：
```
##var  id  name  name@en
##type int string
1      剑   Sword
```

导出选择：  
- `--variant Item.name=en`  
- `--variant default=en`  

**推荐**：用于本地化差异字段。  
**不推荐**：在同一字段上叠加多个业务维度。  

---

### B19. 记录标签与导出过滤

- 记录 tag 位置：Excel 第一列、JSON 中 `__tag__`。  
- 特殊 tag：  
  - `##`：永不导出  
  - `unchecked`：跳过校验  
- 导出过滤：`--includeTag` / `--excludeTag`  

**推荐**：用 `dev` / `test` 标识内部数据。  
**不推荐**：在正式数据中滥用过滤标签。  

---

### B20. 多目标导出与覆盖风险

多 target 时必须分别指定输出目录，否则互相覆盖。  

示例：
```
-x cs-bin.outputCodeDir=Gen/Cs
-x java-bin.outputCodeDir=Gen/Java
-x client.outputDataDir=Gen/Data/Client
-x server.outputDataDir=Gen/Data/Server
```

**推荐**：一个 target 一个目录。  
**不推荐**：多个 target 共用 outputCodeDir/outputDataDir。  

---

### B21. 表扫描规则（tableImporter）

扫描逻辑：  
- 默认扫描 `dataDir` 全目录  
- 支持文件或目录  
- 支持绝对路径或相对 `dataDir`  
- 自动忽略：`__tables__` / `__beans__` / `__enums__` / `Defines`  

**推荐**：右键导表时用 `scanPath` 限定范围。  
**不推荐**：在 `xargs` 里写死 `scanPath`。  

---

### B22. 批量导表不中断（错误处理）

策略：  
- 单表失败只记日志，不中断整批导表  
- 失败表会生成空数据列表  

**推荐**：把日志纳入上线前检查清单。  
**不推荐**：忽略日志导致线上错误。  

---

### B23. 命令行参数（底层参数表）

右键菜单内部就是命令行调用。程序员必须理解：  

- `--conf`：配置文件路径  
- `-t`：目标（来自 `targets`）  
- `-c`：代码目标  
- `-d`：数据目标  
- `-f`：强制加载数据（纯校验用）  
- `-i` / `-e`：tag 过滤  
- `--variant`：字段变体  
- `--timeZone`：datetime 时区  
- `-x`：运行参数（最重要）  

**推荐**：把参数统一收敛到 `luban.conf`。  
**不推荐**：在多个入口脚本里维护不同参数。  

---

### B24. JSON 输出结构与加载方式

JSON 输出结构示意：  
```
{
  "dataList": [
    {"id":1001,"name":"Sword","price":200},
    {"id":1002,"name":"Shield","price":150}
  ]
}
```

运行时加载：  
- `Tables.TbItem.Get(1001)`  
- `Tables.TbItem[1001]`  

**推荐**：统一通过 Tables 访问。  
**不推荐**：绕过生成代码直接解析 JSON。  


## C. 附录：策划模板（可复制）

```
A1: ##export
B1: full_name="demo.TbExample"

##var  id  name  type  desc
##type int string int   text
```

---

## D. 最佳实践总结（必读）

1) 右键菜单是策划唯一入口  
2) `luban.conf` 是唯一配置入口  
3) 输出/L10N/校验全部写在 `xargs`  
4) `tableImporter.scanPath` 只由右键覆盖  
5) 禁止脚本覆盖输出目录  
