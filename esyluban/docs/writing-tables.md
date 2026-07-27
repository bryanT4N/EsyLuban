# 写一张表

**给谁看**：策划。手里有一张 Excel，想让它变成程序读得到的配置。

**读完你能做什么**：从空文件写出一张能导出的表，知道每种字段该填什么、填错会怎样。

**不该在这里找什么**：一个字段要填一串东西（列表、字典、嵌套、多态）——
在[填复杂结构](filling-structures.md)。类型与校验器的完整清单在
[表格式参考](table-format.md)。导出报了错，查[出错了怎么办](troubleshooting.md)。

---

## 一张表长什么样

一张表就是 Excel 里的一个 sheet。头三行是给工具看的，从第四行起是数据：

|  | A | B | C | D | E |
|---|---|---|---|---|---|
| **1** | `##export` | `full_name="item.TbItem" & read_schema_from_file="true"` | | | |
| **2** | `##var` | `id` | `name` | `price` | `desc` |
| **3** | `##type` | `int` | `string` | `int` | `text` |
| **4** | | 1001 | Sword | 200 | `/item_1001` |
| **5** | | 1002 | Shield | 150 | `/item_1002` |

| 行 | 作用 |
|---|---|
| **A1 单元格** | `##export` 表示这张 sheet 要导出，`##export=false` 表示不导。大小写不敏感，`##Export` 也认；但拼错了这张表就不导出，而导表命令仍然算成功 |
| **B1 单元格** | 表定义。至少要有 `full_name` |
| `##var` 行 | 字段名。程序里就用这些名字访问 |
| `##type` 行 | 字段类型 |
| 数据行 | 一行一条记录。**A 列留空** |

三件不那么显然的事：

- **A 列不是行号。** 它是记录标签（用来做导出过滤）。在数据行的 A 列填 `1`、`2`
  就等于给这两条记录各挂了一个名叫 "1"、"2" 的标签。留空。
- **数据中间的空行会被跳过**，不会截断表。但连续空行超过 300 行会有一条性能告警。
- **一个 Excel 文件里可以放多张表**，每个 sheet 各写各的 A1 / B1 就行，互不影响。

---

## 起名：字段用小写下划线，表名用 `Tb` 开头

**字段名写 `max_pile_num` 这样的小写下划线形式**，不要写 `maxPileNum` 或
`MaxPileNum`。

理由是 Luban 会按各语言的习惯自动转换 —— 你写一次，程序那边拿到的是符合他们
语言规范的名字：

| 你在 `##var` 里写 | C# 里是 | Java / TypeScript 里是 | Lua / Python 里是 |
|---|---|---|---|
| `max_pile_num` | `MaxPileNum` | `maxPileNum` | `max_pile_num` |

写成 `maxPileNum` 的话，转换器认不出词的边界，各语言就都得将就着用同一个名字。

**表名习惯以 `Tb` 开头**（`TbItem`、`TbGlobalConfig`）。这不只是好看：`full_name`
不写 `value_type` 时，Luban 按 `TbItem` → `Item` 推导出记录类型名。

模块名（`full_name` 里 `.` 前面那段）按业务分：`item`、`skill`、`mail`。
**别嫌麻烦省掉它** —— 表名在整个工程里唯一，两个人各建一张 `TbConfig` 就撞了。

---

## B1 单元格：只有 `full_name` 必填

`full_name` 是 `模块名.表名`，表名习惯以 `Tb` 开头。其余每一项都有缺省值，
能不写就不写：

| 字段 | 不写时 | 什么时候才写 |
|---|---|---|
| `value_type` | 由表名推导：`TbItem` → `Item` | 表名不以 `Tb` 开头时 |
| `read_schema_from_file` | `false`，表示结构写在别处 | **本表有 `##type` 行时必须填 `true`**，见下 |
| `mode` | `map`（按主键查） | 单例表填 `one`，无主键的列表填 `list` |
| `index` | 取第一个字段 | 主键不是第一个字段时 |
| `input` | 就是本 sheet | 数据在别的文件里时（一般由程序员配） |
| `output` | 由全名生成：`item.TbItem` → `item_tbitem` | 想自定义输出文件名时 |
| `comment` | 空 | 想给表写一句说明时 |

多项之间用 `&` 连接，值用双引号包起来：

```
full_name="item.TbItem" & mode="list" & comment="道具表"
```

### `read_schema_from_file="true"` 是什么

它的意思是「这张表的结构就写在本表的 `##var` / `##type` 两行里」。
默认值是 `false` —— 那表示结构在别处（程序员维护的 schema 文件或
`__beans__.xlsx`），Luban 不会去看你的 `##type` 行。

所以规矩很简单：**你自己写了 `##type` 行，B1 就要带 `read_schema_from_file="true"`。**
漏掉会报 `invalid type. module:'item' type:'Item'` —— Luban 去找一个并不存在的结构了。

程序员已经把结构定义好、表里没有 `##type` 行时，不要加这一项。

---

## 导出

1. 存盘，关掉 Excel（文件开着会报占用）。
2. 在 Excel 文件或数据目录上**右键 → `Luban Export (Data)`**。
3. 改了表结构（加字段、删字段、改类型）时，再点一次 `Luban Export (Code)`。

产物去哪、导出了什么，由 `luban.conf` 决定，那是程序员的事。

---

## 字段类型

### 数字与文字

| `##type` 写法 | 单元格里填 |
|---|---|
| `int` / `long` | 整数：`1001` |
| `float` / `double` | 小数：`1.5` |
| `bool` | 只接受 `true` / `false` / `0` / `1`。`Yes`、`是`、`√` 都会报错 |
| `string` | 任意文字。空单元格 = 空字符串，不是报错 |
| `datetime` | `2025-01-01 00:00:00`。也接受 `2025-1-1 00:00`、`2025-1-1 00`、`2025-1-1` |

### `text`：本地化文本

`text` 字段填的不是文案本身，是**文案的 key**：

```
/item_1001_name
/ui_confirm_ok
```

key 必须在本地化表里存在，否则导出报错。不要在这里写中文原文。

### 枚举

枚举名、枚举别名、数字值三种都接受：

```
Common      枚举名
1           数字值
```

枚举名**区分大小写**，写错了会报错。可选的名字由程序员在枚举定义里维护。

### 一个字段要填一串东西

最简单的形态是「一个格子，用分隔符隔开」：

|  | A | B | C |
|---|---|---|---|
| **2** | `##var` | `id` | `reward_ids` |
| **3** | `##type` | `int` | `(list#sep=;),int` |
| **4** | | 1 | `1001;1002;1003` |

分隔符跟这一列的数据对得上就行，`;`、`,`、`|` 都常见。

**元素超过三五个、或者元素本身有好几个字段，就不要挤在一格里了** ——
还可以占多列、或者一行一个元素。三种怎么选、字典和多态怎么填，
见[填复杂结构](filling-structures.md)。

### 资源路径

程序员会把资源字段定义成 `string#path=unity` 这类写法，你只管填相对路径：

```
Assets/Scenes/SampleScene.unity
```

路径会在导出时逐个去磁盘上找，找不到就报错。拼写和大小写都要与真实文件一致。

---

## 单例表

只有一条全局数据的表（全局配置、开关之类），B1 加 `mode="one"`，然后**只填一行**：

|  | A | B | C |
|---|---|---|---|
| **1** | `##export` | `full_name="global.TbGlobal" & mode="one" & read_schema_from_file="true"` | |
| **2** | `##var` | `openLevel` | `maxBag` |
| **3** | `##type` | `int` | `int` |
| **4** | | 10 | 200 |

单例表只能有一行数据，多一行就导不出来。

---

## 三张能直接抄的模板

### 道具表

|  | A | B | C | D | E |
|---|---|---|---|---|---|
| **1** | `##export` | `full_name="item.TbItem" & read_schema_from_file="true"` | | | |
| **2** | `##var` | `id` | `name` | `price` | `iconPath` |
| **3** | `##type` | `int` | `string` | `int` | `string#path=unity` |
| **4** | | 1001 | Sword | 200 | `Assets/Icons/Item/1001.png` |

`string#path=unity` 是程序员配的路径校验，不要动它。值类型（`item.Item`）、
主键（第一个字段 `id`）、输出文件名（`item_tbitem`）都是自动的。

### 全局配置表

|  | A | B | C |
|---|---|---|---|
| **1** | `##export` | `full_name="global.TbGlobal" & mode="one" & read_schema_from_file="true"` | |
| **2** | `##var` | `version` | `title` |
| **3** | `##type` | `int` | `string` |
| **4** | | 1 | Config |

### 带列表字段的奖励表

|  | A | B | C |
|---|---|---|---|
| **1** | `##export` | `full_name="mail.TbRewards" & read_schema_from_file="true"` | |
| **2** | `##var` | `id` | `rewardIds#sep=;` |
| **3** | `##type` | `int` | `list,int` |
| **4** | | 1 | `1001;1002;1003` |

---

## 容易写错的几处

**字段名不要和值类型名撞车。** 上面那张奖励表的字段叫 `rewardIds` 而不是
`rewards`，是因为 `mail.TbRewards` 会推导出值类型 `Rewards`，C# 里字段 `rewards`
与类型 `Rewards` 只差大小写，生成的代码编译不过。Luban 会直接报
`生成的c#字段名与类型名相同，会引起编译错误` 并中止整次导出。

**第一个字段不能留空。** 它默认就是主键，Luban 自动把它当作非空字段，
空单元格不会被当成 `0`，而是报错。

**`##var` 行里以 `#` 开头的列会被忽略。** 想临时停用一列而不删掉它，
把字段名改成 `#count` 就行。列名整个留空也一样被忽略 —— 「备注」「策划自己
算的中间值」这类列就这么放，不会进产物。

**想停用某一行数据，在它的 A 列填 `##`。** 这一行永不导出，比删掉安全 ——
要恢复只需删掉那两个井号。

---

## 草稿、算表、给自己看的说明，放哪

**放在同一个 Excel 文件里就行，只要那张 sheet 的 A1 不是 `##export`。**

Luban 会看这个文件的每一张 sheet，但只导出 A1 写了 `##export` 的那些。所以
数据 sheet 和你的工作 sheet 可以共存于一个文件，不必分开管理。

---

## 不归你管的

以下都在 `luban.conf` 里，由程序员维护：输出目录、校验参数、本地化配置、
各 target 导出哪些 group。

`##type` 行里 `#` 后面的东西（`#path=unity`、`#ref=`、`#range=` 之类）
是程序员加的校验规则，改了会让校验失效或直接报错。

---

导出报错了，按屏幕上的那句话查[出错了怎么办](troubleshooting.md)。
想写嵌套结构、多态字段、纵向表，看[表格式参考](table-format.md)。
