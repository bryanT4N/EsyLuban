# 表格式参考

**给谁看**：要写复杂表的人 —— 嵌套结构、多态、校验规则、纵表，或者维护
`__beans__.xlsx` 这类结构定义文件的策划与程序员。

**读完你能做什么**：查到每一种表头写法、类型写法、标签写法的准确形式，
以及写错时会得到哪句报错。

**不该在这里找什么**：第一次填表的入门顺序在[写一张表](writing-tables.md)；
输出目录与 target 怎么配在[目标与输出](targets-and-output.md)；报错查询在
[出错了怎么办](troubleshooting.md)。

本文的写法大多能在 `esyluban/examples/dev/DataTables/` 里找到对应的真实表。

---

## 表头行

一张 sheet 的开头是若干**行标签行**：A 列以 `##` 开头的行。第一个不以 `##`
开头的行起就是数据。

| 行标签 | 作用 |
|---|---|
| `##export` / `##export=false` | 只能出现在 A1 单元格，声明这张 sheet 导不导出。大小写不敏感 |
| `##var`（别名 `##field`） | 字段名行。可以出现多次，第二次起是子字段名 |
| `##type` | 类型行 |
| `##+` | 子字段名行，等价于再写一行 `##var` |
| `##group` | 字段级分组 |
| `##desc` / `##comment` | 字段注释 |
| `##column` / `##vertical` | 这张表是纵表 |
| `##` | 无名标签行，通常当注释行用 |

几条准确的规则：

- **行标签用 `#` 分隔、可以叠加。** `##var#column` 与 `##column#var` 等价，
  顺序无所谓。用 `&` 分隔会报 `excel标题头不再使用'&'作为分割符，请改为'#'`。
- **`##export` 的下一行必须是能被识别的 meta 行。** 那一行只接受
  `var` / `+` / `type` / `comment` / `column` / `vertical` 这几个标签，
  其它的报 `非法单元薄 meta 属性定义`。`##group`、`##desc` 要放在它后面。
- **顶层标题行是第一个含 `var` / `field` / `+` 的行。** 例外：`##export`
  之后的第一行如果没有任何标签（写作 `##`）或只有 `column`，也算标题行 ——
  示例工程里不少老表就是这么写的。
- **标签拼错会有一条专门的报错**：`行标签:'##xxx' 包含未知tag:'xxx'，是否有拼写错误?`。
  拼错的若正好是 `##var`，紧接着还会报 `没有定义任何有效 标题行`。
- **注释行的选取顺序**是 `##desc` → `##comment` → `##type` 之后的第一个 `##` 行。
- **数据中间的空行会被跳过。** 连续 300 行空行会有一条性能告警。

`##type` 行只在 B1 单元格带 `read_schema_from_file="true"` 时才被读取 ——
否则结构来自 schema 文件，`##type` 行只是给人看的。

---

## `##var` 行：字段名与它的标签

格式是 `字段名#标签=值#标签=值`。**`##var` 行只接受五个标签**，其余的一律报
`excel标题列:'X' 不支持tag:'Y',请移到##type行`：

| 标签 | 作用 | 写法 |
|---|---|---|
| `sep` | 把一个单元格按分隔符拆成多个值 | `nums#sep=,` |
| `multi_rows` | 这条记录的该字段跨多行 | `frames#multi_rows=1`，简写 `*frames` |
| `non_empty` | 单元格不许为空 | `name#non_empty=1`，简写 `!name` |
| `default` | 空单元格时用的值 | `level#default=1` |
| `format` | 该单元格用哪种解析器 | `pos#format=lite` |

`format` 的取值只有四个，写别的报 `Unsupported data parser type`：

| 值 | 单元格里长什么样（`list,int` / 一个 Vec3 bean） |
|---|---|
| `stream` | 缺省。按 `#sep=` 拆开的扁平流：`1,2,3` |
| `json` | `[1,2,3]` / `{"x":1, "y":2, "z":3}` |
| `lua` | `{1,2,3}` / `{x=1,y=2,z=3}` |
| `lite` | `{1,2,3}` / `{1.0,2.0,3.0}`，嵌套写作 `{{1,2},{3,4}}` |

两条不写在标签里、但同样属于 `##var` 行的规则：

- **字段名以 `#` 开头的列被整列忽略**，可以用来临时停用一列（`#count`）。
- **第一个正常字段自动获得 `non_empty`**，避免把空单元格误当成 `id=0` 的记录。

---

## `##type` 行：类型

整个单元格先按 `&` 拆开。`&` 之前是类型串（所有 `#` 标签、校验器都写在这里），
`&` 之后只接受三个属性：`group=`、`comment=`、`tags=`。
把 `index` / `ref` / `path` / `range` / `sep` / `regex` 写成 `&ref=...`
会得到一句明确的报错：`属于type的属性，必须用#分割，尝试 '<类型>#ref=...'`。

同一字段既有 `##group` 行又有 `&group=` 时，`##group` 行胜出。

### 基础类型

| 写法 | 别名 | 说明 |
|---|---|---|
| `bool` | | `true` / `false` / `0` / `1` |
| `byte` | `uint8` | |
| `short` | `int16` | |
| `int` | `int32` | |
| `long` | `int64` | |
| `bigint` | | 生成代码里用大整数表示 |
| `float` | `float32` | |
| `double` | `float64` | |
| `string` | | 空单元格 = 空字符串 |
| `text` | | 等价于 `string#text=1`，见下面的 `text` 校验器 |
| `datetime` | `time` | `yyyy-M-d HH:mm:ss` / `yyyy-M-d HH:mm` / `yyyy-M-d HH` / `yyyy-M-d` |

`vec2` / `vec3` / `vec4` **不是内置类型**，它们是示例工程在
`DataTables/Defines/builtin.xml` 里定义的 bean。要用得自己定义。

### `?` 可空、`!` 非默认

后缀写在类型名末尾，可以叠加（`int?!`）：

- `int?` / `MyBean?` —— 允许为空。**容器的元素类型不能可空**，
  写了报 `container element type can't be nullable`。
- `int!` —— 挂上 `not-default` 校验器，值不许是该类型的默认值。

Excel 里可空 bean 的 `$type` 列写 `null` 表示空，写 `{}` 或该 bean 自己的名字
表示非空但用缺省内容；写别的报 `可空标识:'X' 不合法`。

### 容器

| 写法 | 说明 |
|---|---|
| `array,<T>` | |
| `list,<T>` | |
| `set,<T>` | 元素不能是容器，否则报 `set的元素不支持容器类型` |
| `map,<K>,<V>` | 键必须是非容器类型 |

一个单元格里填多个值时要挂 `#sep=`。map 在单元格里是**键值交替**排列的：

```
##var   nums#sep=,   props#sep=,          innerList#sep=,
##type  list,int     map,int,string       list,matrix.InnerBean
数据    1,2,3        1,apple,2,banana     1:Alpha,2:Beta
```

最后一列里 `:` 是 `InnerBean` 自己的分隔符（在 `__beans__.xlsx` 的 `sep` 列上定义），
外层 `,` 才是这个 list 的分隔符。多层容器逐层写分隔符：

```
(list#sep=|),(list#sep=,),int        数据：1,2|3,4,5
(map#sep=-|),int,(list#sep=,),int    数据：1-1,2,3|2-2,4,6
```

分隔符本身要转义时前面加 `\`：`(list#sep=\#),int`。

### 枚举与 flags

枚举字段接受枚举名、别名、数值三种写法。`flags` 枚举可以写组合值，
**缺省的组合分隔符是 `|`**（`READ|WRITE`），要换用 `#sep=` 指定。

### bean 与多态

字段类型直接写 bean 的全名（`matrix.InnerBean`）或同模块内的短名。
多态 bean 需要一列 `$type` 说明实际子类型，见下面「一个字段占多列」。

---

## 标签写在容器上还是元素上

这是最容易写反的一处，而且写反了症状不一样：有时是另一个字段被校验，
有时是一句看不懂的解析错误。

规则只有一条：**类型串在第一个「顶层逗号」处切开，逗号左边的标签属于容器，
右边的属于元素。** 括号内的逗号、分号、`#` 都不算顶层。

于是要把标签挂在容器上，就得把「容器名 + 它的标签」整体用括号裹起来：

```
(list#sep=;#(size=[2,3])),int
 └──────── 容器 ────────┘ └元素┘
```

这一串解析成：容器是 `list`，带 `sep=";"` 和 `size="[2,3]"`；元素是 `int`，无标签。
`size` 落在 list 上，校验的是列表长度。

三种写法的实际归属：

| 写法 | 标签挂在 |
|---|---|
| `(list#sep=;#(size=[2,3])),int` | `size` 在 **list** 上 |
| `list,int#(range=[1,10])` | `range` 在 **int** 元素上，逐个元素校验 |
| `(list#sep=\|),(int#ref=test.TbTestBeRef)` | `sep` 在 list 上，`ref` 在元素上 |

把外层括号漏掉是硬错误，不是「挂错地方」：`list#sep=;#(size=[2,3]),int`
会在那个顶层 `;` 处切开，容器变成 `sep` 为空的 `list`、元素串变成
`#(size=[2,3]),int`，最后报 `invalid type. module:'x' type:''`。

反过来，把只能挂容器的校验器写到元素上会在编译期被抓住：
`(list),(int#size=2)` 报 `type:int field:X not support size validator`。

map 更严格一点：键值分隔用的是第一个顶层 `,` 或 `;`，没有容器名白名单兜底，
所以键或值的标签里含逗号时必须加括号 —— `(map#sep=,),int#ref=A,int#ref=B`。

`group` 和 `seq` 是类型串里的保留词，写了分别报
`group为保留属性,只能用于table或var定义` 与 `字段切割应该用'sep'，而不是'seq'`。

---

## 一个字段占多列

### 多级标题头

父字段名写在上面一行 `##var`，子字段名写在后面一行 `##var`（或 `##+`）：

```
##var   id    rewards
##type  int   Reward
##var         itemId    count
```

子字段行是从**父字段所在列**开始逐列排开的。`##type` 只需要写父字段那一格，
放在两个 `##var` 行之间或之后都可以。

### 列范围：合并单元格，或方括号

Luban 要知道父字段占几列。两种表达方式。

**合并父标题格**，覆盖全部子字段列。示例工程里绝大多数多列字段都这么写，
下一节「一条记录跨多行」的表就是一个完整例子。

**或者用 `[字段` … `字段]` 一对方括号标出范围**，不用合并单元格：

|  | A | B | C | D | E | F |
|---|---|---|---|---|---|---|
| **2** | `##` | `id` | `[b` | | | `b]` |
| **3** | `##+` | | `y1` | `y2` | `y3` | |
| **4** | | 1 | 21 | 221 | 23 | |

方括号的闭合格**自己占一列**（上例 F 列），子字段排在开括号那一列起。
闭合格里的名字必须与开括号完全一致，否则报
`列:'[b' 后第一个有效列必须为匹配 'b]'`。

**列范围没标出来就是单列。** 忘了合并的症状是
`bean:'X' 缺失 列:'某个子字段'` —— 因为父字段只被认作一列，后面的子字段无处安放。
同名字段出现两次但不构成范围，则报 `列:'X' 重复`。

### 一条记录跨多行

元素本身是结构、或者数量多到塞不进一个单元格时，用多行嵌套：父列只在第一行填，
子元素每行一个。

|  | A | B | C | D | E | F |
|---|---|---|---|---|---|---|
| **1** | `##export` | `full_name="role.TbLevelBonus" & read_schema_from_file="true"` | | | | |
| **2** | `##var` | `id` | `*bonus_infos` ←─ 合并 C2:F2 ─→ | | | |
| **3** | `##type` | `int` | `list,role.BonusInfo` | | | |
| **4** | `##var` | | `level` | `kind` | `name` | `value` |
| **5** | | 1001 | 1 | 攻击 | atk | 1 |
| **6** | | | 10 | 攻击 | atk | 2 |
| **7** | | | 20 | 防御 | def | 3 |

四条规则缺一不可：

| 规则 | 说明 |
|---|---|
| 父字段名前加 `*` | 写在 `##var` 行。`*frames` 与 `frames#multi_rows=1` 完全等价 |
| `##type` 写 `list,<bean>` | 类型格写在父字段那一列 |
| 子字段名写在下一个 `##var` 行 | 从父字段那一列起逐列排开 |
| 标出列范围 | 合并父标题格，或用 `[*frames` … `*frames]` |

元素 bean 必须是已定义的类型 —— 一行标题描述不了嵌套结构，所以
`read_schema_from_file="true"` 只能推导出主表结构。把元素类型声明在同文件的
`__beans__` sheet 里就行，见下面「内联 schema」。

`__beans__` / `__enums__` 自己就是用这套语法写的（`*fields` / `*items`），
是最好的范例。

### `$key` / `$value` / `$type`

多列展开时用来占位的特殊列名：

| 列名 | 用在 |
|---|---|
| `$key` | map 字段的键列，与值列成对 |
| `$value` | 多态 bean 的值列（限定列写法） |
| `$type` | 多态 bean 的实际子类型列；也接受 `__type__`，两种示例工程里都在用 |

---

## 纵表

首个标题行带 `column` 或 `vertical`（`##column`、`##var#column`、`##column#var`
都可以），表就转 90 度：字段名在第一列纵向排列，每一列是一条记录。

|  | A | B | C | D |
|---|---|---|---|---|
| **1** | `##export` | `full_name="common.TbConst" & mode="one" & read_schema_from_file="true"` | | |
| **2** | `##var#column` | `##type` | `##` | |
| **3** | `x1` | `int` | 常量1 | 1101 |
| **4** | `x2` | `string` | 常量2 | abc |

A 列是字段名，B 列是类型，C 列是注释，**D 列起每一列是一条记录** ——
上例是单例表，所以只有 D 一列。D2 那格是记录标签，留空。

纵表同样支持多行嵌套，只是合并方向变成纵向：字段名在标题列纵向合并 N 行。
参考 `examples/dev/DataTables/matrix/vertical_merged.xlsx`。

---

## 校验器

校验器写在 `##type` 的类型串里，以 `#名字=值` 的形式挂在某一层类型上。
值里含 `,` `;` `#` 时用括号包起来：`string#(set=AA,BB)`。

| 校验器 | 写法 | 适用类型 | 值不合格时 |
|---|---|---|---|
| `not-default` | `int!` 或 `#not-default` | 任意类型 | `是一个默认值` |
| `range` | `int#range=[1,100]`、`int#(range=(1, 10])`、`float#(range=[1.1, 2.2])` | byte / short / int / long / float / double | `不在范围:X内` |
| `size` | `(array#size=2),int`、`(list#(size=[1, 3])),int`、`(set#(size=[1,])),int` | array / list / set / map | `size:N,但要求为 X` |
| `set` | `string#(set=AA,BB)`、`list,int#set=1,2,3` | byte / short / int / long / enum / string | `值不在set:X中` |
| `regex` | `string#(regex=^[A-Z]{3}$)` | string | `不符合正则表达式：'X'` |
| `path` | `string#(path=unity)` | string | `找不到对应文件` |
| `ref` | `int#ref=item.TbItem` | 与被引用的键类型一致 | `在引用表:'X' 中不存在` |
| `index` | `(list#index=id),Foo` | array / list / set，元素须是 bean | `index:X value:Y 重复` |
| `text` | 类型直接写 `text` | string | `不是一个有效的文本key` |

以下都是各校验器独有、写的时候会绊一下的细节。

**`range` 和 `size` 用同一套区间语法。** 光写一个整数表示精确值（`size=4`）；
写区间时首字符必须是 `[` 或 `(`、末字符必须是 `]` 或 `)`，两端可以混用
（`[1, 10)`）；留空一边表示开区间（`[1,]`、`(,100)`）。不合法时统一报
`range定义不合法`。`range` 的浮点区间会把非整数端点各放宽 `1e-6` 以吸收浮点误差。

**`set` 只用逗号分隔，不能用分号。** `int#(set=1;2;3)` 会在 `long.Parse` 上抛异常。
字符串集合不做 trim，`set=ab, cd` 里的第二项是 `" cd"`（带前导空格）。

**`regex` 的模式串原样使用，不做任何括号剥离与 trim。** 而 `\` 在标签解析阶段
就是转义符并会被吃掉 —— 正则里的字面反斜杠要写两个。

**`path` 的写法是 `path=<模式>[?][;<模板>]`**：

| 值 | 含义 |
|---|---|
| `path=unity` | 相对 `pathValidator.rootDir` 直接找文件 |
| `path=ue` | `/Game/...` 形式，找对应的 `.uasset` / `.umap` |
| `path=godot` | `res://` 开头，去掉前缀后找文件 |
| `path=normal;<前缀>*<后缀>` | 自定义替换模板，第二段必须含 `*` |

模式名后加 `?` 表示允许空值（`path=unity?`）。
**没配 `-x pathValidator.rootDir=<目录>` 时整个 path 校验被跳过**，
只在日志里留一句 `path validation is disabled`。

**`ref` 的完整写法是 `ref=[<索引字段>@]<表名或引用组>[?]`**，多个用逗号并列：

| 目标 | 写法 |
|---|---|
| `map` 表 | `int#ref=item.TbItem`，不能再指定子字段 |
| `list` 表 | `int#ref=id1@test.TbMultiIndexList`，**必须**显式指定索引字段 |
| 引用组 | `int#ref=test_ref_group`，索引字段必须为空 |
| 允许空值 | 末尾加 `?`：`string#ref=ai.TbBlackboard?` |
| 容器元素 | `(list#sep=\|),(int#ref=test.TbTestBeRef)` |

单例表（`mode="one"`）不支持被 `ref`。被引用的表必须在同一次导出的 target
里真的被导出，否则报 `ref 引用的表:'X' 没有导出`。

**`index` 只对 array / list 生成额外的索引映射代码**；挂在 `set` 上能通过校验，
但不产生任何生成代码。

**`text` 是唯一一个依赖外部配置的校验器。** 没配文本表时它静默跳过，
`l10n.convertTextKeyToValue=1` 时也不走这条路径 —— 见[本地化](localization.md)。

以上校验器的类型限制都在**编译期**（读 schema 时）就报出来，不用等到有数据。

---

## B1 单元格：每个字段的真实影响

`full_name` 是唯一必填项，其余都有缺省值。基础用法见[写一张表](writing-tables.md)，
这里只写会咬人的部分。

| 字段 | 真实影响 |
|---|---|
| `full_name` | 表的唯一身份。决定默认输出文件名、生成代码里的访问名。**表名在整个工程内唯一**，不同模块下同名也不行 |
| `value_type` | 记录的结构类型。缺省由表名推导（`TbItem` → `Item`）；`read_schema_from_file="true"` 且没写命名空间时，自动补上表所在的命名空间 |
| `index` | 见下 |
| `mode` | `map` / `list` / `one`，其它值报 `Invalid mode: X. Expected: map, list, or one` |
| `read_schema_from_file` | `true` 表示结构来自本表的 `##var`/`##type` 行。缺省 `false` |
| `input` | 数据源，见下一节。逗号分隔可以并列多个 |
| `output` | 覆盖默认输出文件名，见下面「`output` 这一格能写什么」 |
| `group` | 逗号或分号分隔。留空时，是否导出取决于当前 target 的 group 里有没有被标记为默认的组 |
| `comment` | 注释，进生成代码 |
| `tags` | `#` 分隔的自定义键值对，如 `tags="priority=high#category=core"` |

**`index` 的语义随 `mode` 变，这一点很容易踩：**

| mode | `index` 的解释 |
|---|---|
| `map` | **只能是单个字段名。** 留空取值类型的第一个字段。写 `a+b` 会直接报 `index:'a+b' 字段不存在` |
| `list` | 支持 `a,b,c`（多个各自独立的索引）与 `a+b+c`（一个联合索引）；也可以整个留空 |
| `one` | 完全忽略 `index`，写了也没有作用 |

索引字段还有两条硬约束：不能是可空类型（报 `index:'x' 不能为 nullable类型`），
类型不能是 datetime、bean 或任何容器（报 `的类型:'X' 不能作为index`）。

表级的 `group` 与字段级的 `##group` 行判定规则相同：留空即属于所有默认组，
哪些是默认组由 `luban.conf` 决定，见[配置参考 · groups](configuration.md#groups)。

---

## `input` 的定位语法

不写 `input` 时它指向声明它的那个 sheet 自己，**大多数表用不到它**。
一个 Excel 里放多张表也不需要写 —— 每个 sheet 各写各的 A1 / B1，逐个被识别。

只有一种情况需要写：**数据不在声明它的这个 sheet 里**。

| 写法 | 含义 |
|---|---|
| `input="test/item.xlsx"` | 读该文件的**全部** sheet，合并成一张表 |
| `input="ai/behaviortrees"` | 读整个目录下的所有数据文件 |
| `input="a.csv,b.csv,c.csv"` | 逗号分隔多个数据源，合成一张表 |
| `input="table3@test/composite_tables.json"` | 该 json 里名为 `table3` 的那一段，**当作一条记录**读 |
| `input="*table1@test/composite_tables.json"` | 同上，但该段是一个**记录数组** |
| `input="*@test/composite_tables2.json"` | 整个 json 根就是记录数组 |

**注意 `@` 左边是 sheet / 字段名，右边才是文件路径**，与常见的「文件#锚点」相反。
读法是「逻辑上是这张表，物理上躺在那个文件里」，所以逻辑位置占据路径的一段，
写在左边。这是上游的既有约定（`FileUtil.SplitFileAndSheetName`），
`luban.conf` 的 `schemaFiles` 与 l10n 配置用的是同一套写法。

第一种最容易与缺省混淆：**只写文件路径（不带 `@sheet`）表示读该文件的所有
sheet**，而缺省只读声明它的那一个。多态表常用它把 `item` / `equipment` /
`decorator` 几个 sheet 合成一张表，这种 `input` 不能省。

**读一条还是读一组，由 `*` 前缀决定，不由表的 `mode` 决定。** Excel 文件永远
按「一组」读；非 Excel 文件带 `*` 前缀才是一组，不带就是单独一条 ——
所以 `mode="one"` 的表配 json 数据源时，`input` 写不带 `*` 的那一种。
`*` 只管这件事，不参与定位：字段路径支持 `.` 逐级下钻（`*a.b.c@file.json`）。

---

## `output` 这一格能写什么

不写时，输出文件名由 `full_name` 推导：`.` 换成 `_` 再全部转小写
（`item.TbItem` → `item_tbitem`）。

写了的话，**值被当作路径用**，因此可以带目录分隔符，层级不限，而且
**大小写原样保留**（缺省推导会强制转小写）：

```
full_name="matrix.TbMatrixList" & output="matrix/nested/TbMatrixList"
```

生成代码会自动跟着改，清理也会跟进子目录 —— 完整后果见
[目标与输出 · 输出文件名](targets-and-output.md#输出文件名)。

---

## Schema 定义文件

结构不写在数据表标题行里时，就写在这里。它们由 `luban.conf` 的 `schemaFiles`
指定加载。

### `__beans__.xlsx`

主字段列与子字段列都必须齐全，值可以为空。少一列报
`bean:'__intern__.__BeanInfo__' 缺失 列:'parent'` 这类错。

| 主列 | 含义 |
|---|---|
| `full_name` | bean 全名 |
| `parent` | 父类全名，用于多态 |
| `valueType` | 是否值类型（bool） |
| `sep` | 该 bean 在单元格里展开时的默认分隔符 |
| `alias` | 别名 |
| `comment` | 注释 |
| `tags` | `#` 分隔的自定义键值对 |
| `group` | 分组 |
| `*fields` | 字段列表，跨多行 |

`*fields` 的子列：`name`、`alias`、`type`、`group`、`comment`、`tags`、`variants`。

### `__enums__.xlsx`

| 主列 | 含义 |
|---|---|
| `full_name` | 枚举全名 |
| `flags` | 是否位枚举（bool） |
| `unique` | 枚举值是否要求唯一（bool） |
| `group` | 分组 |
| `comment` | 注释 |
| `tags` | 自定义键值对 |
| `*items` | 枚举项，跨多行 |

`*items` 的子列：`name`、`alias`、`value`、`comment`、`tags`。
`flags` 枚举的 `value` 可以写成组合：`WRITE|READ`。

### XML 定义

放在 `luban.conf` 的 `schemaFiles` 指定的目录下（示例工程是
`DataTables/Defines`）。顶层元素：`<module>`、`<enum>`、`<bean>`、`<table>`、
`<refgroup>`、`<constalias>`；`<bean>` 内是 `<var>` 与 `<mapper>`。

```xml
<module name="item">
  <bean name="Item">
    <var name="id" type="int" />
    <var name="name" type="string" variants="zh,en" />
  </bean>
</module>
```

`<module>` 可以嵌套（形成 `test.login` 这样的命名空间），`<bean>` 嵌套在
`<bean>` 里表示继承关系，也可以用 `parent="其它模块.某类"` 跨模块继承。

### 内联 schema

数据表 Excel 里加一个名为 `__beans__` 或 `__enums__` 的 sheet，
它就是**这个文件专用**的类型定义，格式与上面完全一样。
作用域是 file-wide：同一文件内的多张表可以共用，跨文件不行。

用它可以把「一张表 + 它专用的嵌套元素类型」放在同一个 Excel 里交付，
不必回到集中的 `__beans__.xlsx` 登记。跨文件共享的类型仍然要放全局定义文件。

加载顺序上 `__enums__` 先于 `__beans__`，所以 bean 的字段可以引用同文件里的枚举。

---

## 字段变体

同一字段为不同地区 / 版本提供不同值。

**定义**：在 `__beans__.xlsx` 的 `variants` 列或 XML 的 `variants` 属性里
列出可选变体名：

```xml
<var name="name" type="string" variants="zh,en" />
```

**填写**：数据表里除了 `name` 列，再加 `name@zh`、`name@en` 列。
基准列必须排在变体列**前面** —— 变体列是挂到已声明的同名字段上的，
找不到基准字段会报 `field:X not found for variant field:'name@en'`。

**选择**：导出时用命令行参数指定。变体键是**bean 全名 + 字段名**：

```
--variant test.TestFieldVariant.name=en
--variant default=en
```

`default=` 是所有未单独指定的变体字段的兜底。一个变体字段既没被单独指定、
又没有 `default` 时只是一条 WARN，字段退回基准列的值。
指定了一个不在 `variants` 列表里的名字则直接报错中止。

非 Excel 数据源里，json / yaml / lua 用 `"name@en"` 作键名，xml 用属性：
`<name variant="zh">zh</name>`。

---

## 记录标签与导出过滤

每条记录可以带若干标签：Excel 里写在**数据行的 A 列**，其它格式里写在
`__tag__` 字段。多个标签用逗号分隔，**统一转小写**。

| 标签 | 效果 |
|---|---|
| `##` | 该条记录永不导出 |
| `unchecked` | 该条记录跳过所有校验器 |
| 其它任意名字 | 供 `--includeTag` / `--excludeTag` 过滤用 |

- `--includeTag t` —— 只导出带 `t` 标签的记录。
- `--excludeTag t` —— 导出所有不带 `t` 标签的记录。
- **两者不能同时使用**，同时给会报
  `option '--includeTag <tag>' and '--excludeTag <tag>' can not be set at the same time`。

---

## 非 Excel 数据源

用哪个 loader 由文件扩展名决定。内置的有 `xlsx` / `xls` / `xlsm` / `xlm` /
`csv`（都走 Excel 那一套）、`json`、`lua`、`xml`、`yml`、`lit`、
Unity 的 `asset`。

多态子类型的标记名每种格式不同，另外**所有格式都额外接受 `__type__` 作为后备**：

| 格式 | 多态标记 |
|---|---|
| json / yaml | `"$type": "DemoD2"` |
| lua | `_type_ = "DemoD2"` |
| xml | 写成属性：`<x14 type="DemoD2">` |
| Excel | 一列 `$type` |

其余容器与空值的表示：

| | json | lua | xml |
|---|---|---|---|
| list | `[1,2,3]` | `{1,2,3}` | `<k><item>1</item><item>2</item></k>` |
| map | `[[2,10],[3,12]]` | `{[2]=10,[3]=12}` | `<k><item><key>2</key><value>10</value></item></k>` |
| 空值 | `null` | `nil` | 整个元素省略 |

`.lit` 是无键的紧凑格式，字段完全按声明顺序位置排列，没有任何字段名。

---

写错的症状对照表在[出错了怎么办](troubleshooting.md)。
