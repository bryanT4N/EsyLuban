# 目标与输出

**给谁看**：程序员。要决定这个项目导出什么格式、生成哪种语言的代码、产物落在哪里。

**读完你能做什么**：选对 codeTarget 与 dataTarget 的组合，让每个 target 的产物落进各自的目录，并且不被下一次导出删掉。

**不该在这里找什么**：`luban.conf` 每个字段怎么填、命令行有哪些参数 —— 那些在[配置参考](configuration.md)。表怎么写在[写一张表](writing-tables.md)。

---

## 「target」是三个不同的东西

Luban 里有三样东西都叫 target，名字相同、管的事毫不相干。绝大多数配置踩坑都源于把它们弄混。

混淆感的来源很具体：命令行帮助里 `-c` 叫 "code target name"、`-d` 叫 "data target name"，而 `-t` 只叫 "target name" —— 只有它没有限定词，看起来像个总称，实际只是三者之一。

| | 名称 | 命令行 | 值举例 | 管什么 | 这些值从哪来 |
|---|---|---|---|---|---|
| ① | **表 target** | `-t` | `client` `server` `all` | 导出**哪些表**（按 group 过滤）、生成代码的命名空间与管理类名 | 你在 `luban.conf` 的 `targets` 里**自己起的名字** |
| ② | **dataTarget** | `-d` | `json` `bin` `xml` `lua` … | 数据导成**什么格式** | Luban 内置的 16 种，名字固定 |
| ③ | **codeTarget** | `-c` | `cs-simple-json` `cpp-rawptr-bin` … | 代码生成成**什么语言** | Luban 内置的 29 种，名字固定 |

一条完整命令同时含三者：

```
gen.bat  -t client    -d json      -c cs-simple-json
         ↑① 导哪些表  ↑② 数据格式   ↑③ 代码语言
```

三个概念、`targets` 这个字段名、以及 `-t` / `-d` / `-c`，都是上游 Luban 的既有设计。上表最后一列说的是**值**从哪来：`client` 这个名字是你起的，`json` 这个名字是 Luban 定的。

**最本质的区别**：① 是你自己起的名字，②③ 是 Luban 的固定名单。

### 每个位置该填哪一种

```jsonc
luban.conf
  "targets": [{"name":"client", ...}]              // ① 你定义的表 target
  "xargs": [
    "json.outputDataDir=...",                      // ② dataTarget 前缀
    "cs-simple-json.outputCodeDir=..."             // ③ codeTarget 前缀
  ]
  "contextMenu": {
    "data": {
      "targets":   ["client","server"],            // ① 复数：表 target 列表
      "dataTarget": "json"                         // ② 单数：一种数据格式
    },
    "code": {
      "targets":     ["client"],                   // ①
      "codeTargets": ["cs-simple-json"]            // ③ 复数：可多种语言
    }
  }
```

记忆钥匙：`targets`（不带前缀）永远指表 target；带 `data` / `code` 前缀的才是格式与语言。

---

## xargs 的前缀只认 dataTarget 与 codeTarget

这一条单独拎出来讲，因为它是**写错了既不报错也不生效**的那一类，而且它想解决的需求（双端同语言、目录要分开）极其常见。

```
✅ json.outputDataDir=...               dataTarget 前缀，生效
✅ cs-simple-json.outputCodeDir=...     codeTarget 前缀，生效
✅ outputSaver.json.cleanUpOutputDir=0  同样是 dataTarget
❌ client.outputDataDir=...             表 target 前缀，无效
```

### 为什么

输出目录由 `OutputSaverBase.GetOutputDir` 决定，它拿 `manifest.TargetName` 当命名空间：

```csharp
// src/Luban.Core/OutputSaver/OutputSaverBase.cs
return EnvManager.Current.GetOption($"{manifest.TargetName}", optionName, true);
```

而 `TargetName` 里装的从来不是 `-t` 的值 —— `DefaultPipeline` 填进去的是 `-d` / `-c`：

```csharp
ProcessDataTarget(name, ...)  → new OutputFileManifest(name, OutputType.Data)  // name 来自 -d
ProcessCodeTarget(name, ...)  → new OutputFileManifest(name, OutputType.Code)  // name 来自 -c
```

**`TargetName` 这个字段名本身就是误导。** 日志里出现 `输出目标 'json'` 时，别去 `targets` 里找 `json`，那里没有。

### 后果

`client.outputDataDir=...` 这一行不生效，意味着 `client` 与 `server` 实际写进**同一个**全局 `outputDataDir`。而全量导出默认带清理，于是先跑的那个 target 的产物会被第二次导出删掉，最终只剩最后一个 target 的数据 —— 日志里一切正常。

EsyLuban 会拦这个：xargs 的键如果以 `targets` 里某个 target 名为前缀，而那个名字又没被注册成 dataTarget 或 codeTarget，日志里会出现

```
[dead xargs] client.outputDataDir 不会生效：client 是 conf 里 targets 的名字（-t 的那个 target），
而 xargs 的命名空间只认 dataTarget（json、bin…）与 codeTarget（cs-simple-json…）。
要按 target 分目录，请在每次调用时用 -x outputDataDir=... 传入。
```

它只警告确定无效的那一类，不会误伤本次运行碰巧没读到的键。

### 那怎么按表 target 分目录

给各 target 单独调用一次，用**不带前缀**的 `-x outputDataDir=`：

```
gen.bat -t client -d json -x outputDataDir=../../Run/Data/client
gen.bat -t server -d json -x outputDataDir=../../Run/Data/server
```

右键菜单的 `contextMenu.data.outputDataDir` 映射表就是这么翻译的 —— 它读到的 target→目录对应关系，逐个转成上面这种调用。见[右键菜单](context-menu.md)。

---

## 输出目录的解析规则

只有两层，代码与数据各一套：

| 找的是 | 先查 | 再回落到 |
|---|---|---|
| 数据输出目录 | `{dataTarget}.outputDataDir` | `outputDataDir` |
| 代码输出目录 | `{codeTarget}.outputCodeDir` | `outputCodeDir` |

没有第三层，也没有 `{表 target}.` 这一层。

多个 dataTarget / codeTarget 并行导出时，一个格式给一个目录：

```
-x cs-bin.outputCodeDir=Gen/Cs
-x java-bin.outputCodeDir=Gen/Java
-x json.outputDataDir=Gen/Data/Json
-x bin.outputDataDir=Gen/Data/Bin
```

共用目录的后果和上一节相同：并行的清理器互删对方的产物。

---

## 输出目录会被清空

导出前，Luban 会删掉输出目录里**所有不属于本次产物的文件**（`cleanUpOutputDir`，默认开启）。它不判断文件是不是 Luban 生成的。

| 场景 | 清理是好是坏 |
|---|---|
| 全量导出（`gen.bat`） | 好。清掉已删除的表遗留的旧产物，避免游戏加载到幽灵数据 |
| 局部导出（右键菜单 / `-o` 限定） | 灾难。只导一张表，其余所有表的产物都会被当成「不属于本次产物」删光 |

右键脚本因此固定传 `-x cleanUpOutputDir=0`，`gen.bat` 的全量导出则保留清理。手动关闭：

```
gen.bat -t client -d json -o your.TbFoo -x cleanUpOutputDir=0
```

**`outputDataDir` 要指向 Luban 专用目录。** 指到混放美术资源或手写配置的目录，全量导出会把它们一并删掉。用 `.../Run/Data/Generated/` 这类一眼看得出是生成物的路径。

### EsyLuban 的安全闸

上游的清理有四条互不相干的路径通向「静默批量删除」，且全部退出码 0：group 全是 `default:false` 导致一张表都没导出、多个 target 共用输出目录、`-o` 局部导出没关清理、输出目录混放了别的东西。

EsyLuban 用「本次产物数」与「将删除数」的关系识别这些异常，两种情况下拒绝清理并告警：

- 本次一个文件都没产出，却要删已有文件
- 要删的比本次产出的还多

```
[skip cleanup] 输出目标 'json' 将删除 53 个文件，多于本次产出的 3 个，已跳过清理。
```

正常的全量导出不受影响 —— 那里要删的只是废弃表的残留，数量远小于产物数。`.meta` / `.uid` 伴生文件从不参与清理。确需强行清理用 `-x forceCleanUpOutputDir=1`。

---

## codeTarget 与 dataTarget 必须配套

生成代码里写死了它按什么形状去读数据。**配错了不报错，只在运行时炸**，所以选语言之前先确认这一对能凑齐。

规律很简单：**codeTarget 名字的后缀，就是它要求的 dataTarget**。

| 语言 | codeTarget | 必须配的 dataTarget |
|---|---|---|
| C# | `cs-bin` | `bin` |
| | `cs-simple-json` / `cs-dotnet-json` / `cs-newtonsoft-json` / `cs-editor-json` | `json` |
| | `cs-protobuf2` / `cs-protobuf3` | `protobuf2-bin` / `protobuf3-bin` |
| **C++** | `cpp-rawptr-bin` / `cpp-sharedptr-bin` | **只有 `bin`** |
| Java | `java-bin` / `java-json` | `bin` / `json` |
| Go | `go-bin` / `go-json` | `bin` / `json` |
| Rust | `rust-bin` / `rust-json` | `bin` / `json` |
| TypeScript | `typescript-bin` / `typescript-json` / `typescript-protobuf` | `bin` / `json` / pb |
| JavaScript | `javascript-bin` / `javascript-json` | `bin` / `json` |
| Lua | `lua-bin` / `lua-lua` | `bin` / `lua` |
| Python | `python-json` | 只有 `json` |
| Dart | `dart-json` | 只有 `json` |
| PHP | `php-json` | 只有 `json` |
| GDScript | `gdscript-json` | 只有 `json` |
| 跨语言 schema | `flatbuffers` / `protobuf2` / `protobuf3` | 只生成 `.fbs` / `.proto` 定义，不生成加载代码 |

一共 29 个 codeTarget。dataTarget 有 16 个，除上表出现的以外还有 `bin-offset`、`bson`、`msgpack`、`yaml`、`xml`、`json2`、`json-convert`、`text-list`、`flatbuffers-json`、`protobuf2-json`、`protobuf3-json` —— 这些没有对应的生成代码，是给手写加载器用的。

### C++ 没有 json 版的生成代码

用 Luban 的 C++ 生成代码，等于同时接受 `bin` 数据格式、它自己的容器层（`::luban::HashMap` / `Vector` / `ByteBuf`）、它的内存模型（裸指针 + `LUBAN_FREE`，或 `shared_ptr`），以及一个额外的 C++ 运行时（生成的 `schema.h` 里 `#include "CfgBean.h"`，那个文件不在产物里）。表少、字段简单时，这个承诺往往比自己写个加载器还重 —— 那种情况下直接用 `json2` 手写加载器更划算。

---

## `json` 与 `json2`

Luban 有两个 JSON 数据目标，不是新旧关系，是两种取舍。

| | `json`（缺省） | `json2` |
|---|---|---|
| `map` 字段 | `[[1,"apple"],[2,"banana"]]` | `{"1":"apple","2":"banana"}` |
| `mode="map"` 的表 | `[{...},{...}]` | `{"cr_badge":{...}}` |
| `mode="one"` 的表 | `[{...}]`（要先取 `[0]`） | `{...}` |
| `mode="list"` 的表 | `[{...}]` | 相同 |

### 为什么缺省是 `json` 而不是更好看的 `json2`

因为 `json2` 表达不了全部合法 schema。JSON 的对象键只能是字符串，所以 `json2` 要把 map 的键转成属性名，而负责这件事的 `ToJsonPropertyNameVisitor` 对一半类型直接抛异常：

```
支持：byte short int long enum string
抛异常：bool float double datetime bean
```

而 schema 那边（`DefAssembly.CreateMapType`）用的是 `CreateNotContainerType` —— 任何非容器类型都能当 map 键，上面那些全都合法。一份含 `map,datetime,string` 的语料实测：

```
-d json    exit=0   成功
-d json2   exit=1   "Specified method is not supported."
```

缺省格式必须能导出所有合法配置。代价是所有人都得忍受 `[[k,v]]` 这个形状，哪怕自己表里全是 int 键。

### `json2` 没有任何 codeTarget 配它

所有 `-json` 结尾的模板都按【数组对】读 map：

```csharp
// cs-simple-json 生成的代码
if(!__json0.IsArray) { throw new SerializationException(); }
foreach(JSONNode __e0 in __json0.Children) { _k0 = __e0[0]; _v0 = __e0[1]; }
```

`cs-dotnet-json` 用 `GetArrayLength()`，`go-json` 用 `_buf[0]`，`python-json` / `typescript-json` / `rust-json` 同理。

⚠ **`json2` + 生成代码 = 定时炸弹。** 没有 map 字段的表，`json2` 也能被生成代码读进去（对象的 children 恰好可遍历），**直到有人加了第一个 map 字段**才抛 `SerializationException`。配错的当天不会发现。

`json2` 是给**手写加载器**的：不用 Luban 生成代码，只想要一份人能读、好解析的 JSON。`mode="map"` 的表直接就是 id → 记录的查找表，不必自己再建索引；`mode="one"` 的表也不用每次先剥掉外层数组。

### 选哪个

- 用 Luban 生成代码 → `json`（或 `bin`），别碰 `json2`
- 手写加载器，且 map 键都是整数 / 字符串 / 枚举 → `json2`
- 手写加载器，但用到了 datetime / bean / float 作 map 键 → 只能 `json`
- 只关心加载速度与包体 → `bin`（同一语料实测 13 KB vs json 107 KB）

---

## JSON 产物的结构

顶层是**裸数组**，没有外层包装：

```json
[
  {"id":1001,"name":"Sword","price":200},
  {"id":1002,"name":"Shield","price":150}
]
```

单例表（`mode="one"`）也是数组，只是只有一个元素。可以自己翻 `esyluban/baselines/coverage/` 下任意 json 确认 —— 顶层就是 `[`。

运行时通过生成代码访问：`Tables.TbItem.Get(1001)` 或 `Tables.TbItem[1001]`。

---

## XML 的类型信息比 JSON 还少

XML 里一切都是文本，没有任何类型标记。同一份数据，键类型不同，XML 输出逐字节相同：

```xml
<!-- map,int,string -->        <!-- map,string,string -->
<ele><key>1</key>              <ele><key>1</key>
  <value>apple</value></ele>     <value>apple</value></ele>
```

而 JSON 至少能用引号区分：

```json
map,int,string     [[1,   "apple"]]
map,string,string  [["1", "apple"]]
```

三种格式的取舍摊开是这样：

| | 形状是否自然 | 是否保留类型 |
|---|---|---|
| `json` | ✗ 数组对 | **✓** |
| `json2` | ✓ 原生对象 | ✗（键变字符串） |
| `xml` | ✗ `<ele><key/><value/>` | ✗ |

**XML 付了 `json` 那份难看的代价，却没换到类型保真。** 它摊成 `<ele><key/><value/></ele>` 不是为了保类型，纯粹是因为 XML 连「键值对」这个概念都没有 —— 同理，列表元素被迫叫 `<ele>`，是因为 XML 里每个值都必须待在一个具名元素中，而列表元素本来就没有名字。

XML 唯一携带 schema 信息的地方是多态判别符，而它是个属性：

```xml
<root type="Sequence">
  <decorators><ele type="UeLoop">...</ele></decorators>
```

这也解释了 Luban 的 XML 为什么不像配置文件。它不是给人读写的配置格式，是同一棵类型化数据树被硬塞进 XML 语法的产物 —— 是「JSON 形状的 XML」。在 Luban 的世界里，配置文件是那张 Excel，XML/JSON 只是运行时加载用的中间态。

---

## 输出文件名

缺省名由 `full_name` 推导：`.` 换成 `_`，全部转小写。

```
item.TbItem   →   item_tbitem.json
```

两处可以改：B1 的 `output=` 覆盖文件名，`{dataTarget}.fileExt` 覆盖后缀。

### `output` 可以带目录

代码输出本来就是分层的（`GenCode/client/ai/BehaviorTree.cs`），只有数据是平的。`output` 的值会被当作**路径**用，写上分隔符就能分目录，层级不限：

```
##export | full_name="matrix.TbMatrixList" & output="matrix/nested/TbMatrixList"
   →  <outputDataDir>/matrix/nested/TbMatrixList.json
```

三件配套的事都成立（回归里有这张表守着）：

1. **生成代码自动跟随**，接入方一行都不用改：

   ```csharp
   TbMatrixList = new matrix.TbMatrixList(loader("matrix/nested/TbMatrixList"));
   ```

   你的 loader 拿到的仍是「相对 `outputDataDir` 的路径」，拼上扩展名即可。

2. **清理跟进子目录**。把 `output` 改到别处后重跑，旧文件会被删掉，空目录也一并清理。

3. **大小写按你写的来**。`output` 原样使用，不像缺省推导那样强制小写。跨平台部署（Linux 区分大小写）时保持与 loader 里一致即可。

没有「一键全体分层」的开关。想让整个项目按模块分目录，就得逐表写 `output` —— 缺省推导规则不可配置，永远是 `模块_表名` 全小写平铺。表多时在建表模板里预置这一行。

`full_name` 与 `output` 都会进运行时引用链，上线后改它们等于改加载路径。
