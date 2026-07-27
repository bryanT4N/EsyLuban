# 常见需求怎么配

**给谁看**：程序员。要把配置流水线搭成项目实际需要的样子。

这里的每一条都从头走到尾：改哪个文件、加哪几行、导出命令长什么样、产物落在哪。
只给一种推荐做法。

---

## 一、客户端和服务端要不同的字段

同一张道具表，客户端要图标路径，服务端要掉落权重，两边都不想拿到对方那份。

### 1. 声明有哪些分组

`luban.conf`：

```json
"groups": [
  {"names":["c"], "default":true},
  {"names":["s"], "default":true}
]
```

`default:true` 的含义是：**不标分组的字段属于它**。所以上面这份配置下，
一个普通字段客户端服务端都能拿到 —— 这正是你想要的缺省行为，
**绝大多数字段都不该标分组**。

### 2. 只给需要区分的字段标上

在表里加一行 `##group`，只填要区分的那几列：

|  | A | B | C | D |
|---|---|---|---|---|
| **2** | `##var` | `id` | `icon` | `drop_weight` |
| **3** | `##type` | `int` | `string` | `int` |
| **4** | `##group` | | `c` | `s` |
| **5** | | 1001 | `Icons/1001.png` | 50 |

`id` 不标，两边都有；`icon` 只给客户端；`drop_weight` 只给服务端。

多个分组写 `c,s`。整张表只给一边时，标在 B1 上：
`full_name="item.TbDropRule" & group="s"`。

### 3. 建两个 target

```json
"targets": [
  {"name":"client", "manager":"Tables", "groups":["c"], "topModule":"cfg"},
  {"name":"server", "manager":"Tables", "groups":["s"], "topModule":"cfg"}
]
```

### 4. 分别导出

```bat
gen.bat -t client -d json -c cs-simple-json ^
  -x outputDataDir=..\..\Client\Assets\GameConf ^
  -x outputCodeDir=..\..\Client\Assets\Scripts\Config

gen.bat -t server -d json -c cs-dotnet-json ^
  -x outputDataDir=..\..\Server\GameConf ^
  -x outputCodeDir=..\..\Server\Config
```

### 分组会影响的东西

不只是数据里少几个字段 —— **生成的代码也会跟着变**：客户端的 `Item` 类里根本
没有 `DropWeight` 这个成员，整张只给服务端的表连类都不生成。误用会编译不过，
而不是运行时拿到空值。

嵌套结构里的字段同样会被过滤。

### 一个会让人困惑的报错

某个 target 导出时报 **`ref 引用的表:'X' 没有导出`**，通常是分组配漏了：
A 表引用 B 表，但 B 表的分组不在这个 target 里。要么给 B 表加上对应分组，
要么把这条引用也标成同样的分组。

---

## 二、按模块把产物分到不同目录

产物默认全平铺在 `outputDataDir` 下（`item_tbitem.json`、`skill_tbskill.json`）。
表多了想按模块分开。

**推荐在表自己的 B1 上写 `output`**，值当作路径用，可以带目录：

```
full_name="item.TbItem" & output="item/TbItem"
```

产物落在 `outputDataDir/item/TbItem.json`，生成的代码自动跟着改。

**决定权留在表上，加一张表不用动 `luban.conf`** —— 和自包含表定义是同一个思路。

有两个坑值得先知道，细节见[目标与输出](targets-and-output.md)：

- **`-x client.outputDataDir=...` 永远不生效。** `-x` 的前缀只认 dataTarget /
  codeTarget 的名字，不认 `-t` 那个 target。要按 `-t` 分目录就分几次调用
  （像上一节那样）。EsyLuban 会对这种写法给 `[dead xargs]` 告警。
- **输出目录导出前会被清空。** 绝不要指向 `Assets/Scripts` 这类混着手写代码的
  目录。

---

## 三、不让测试数据进正式包

策划想把测试道具和正式道具填在同一张表里，发布时不带上。

**在数据行的 A 列填一个标签**（A 列不是行号，就是干这个用的）：

|  | A | B | C |
|---|---|---|---|
| **4** | | 1001 | 铁剑 |
| **5** | `test` | 9999 | 测试用无敌剑 |

导出时排掉：

```bat
gen.bat -t client -d json -e test
```

`-e` / `--excludeTag` 排除带该标签的行，`-i` / `--includeTag` 反过来只要带标签的。

两个特殊标签：

| 标签 | 含义 |
|---|---|
| `##` | 永不导出。用来临时停用一行 |
| `unchecked` | 校验器跳过这一行。批量造的数据引用还没配好时，先压住误报 |

---

## 四、把校验接进提交流程

校验器只有在导表时才跑。想让坏数据进不了仓库，在提交前跑一次**只校验不产出**：

```bat
gen.bat -t all -f
```

`-f` / `--forceLoadTableDatas` 强制加载并校验全部数据；不给 `-c` 和 `-d`，
就不会生成任何东西。

**校验失败默认不算失败** —— Luban 记 ERROR 日志但退出码仍是 0。
要让它拦住提交，必须加：

```bat
gen.bat -t all -f --validationFailAsError
```

这一条很容易漏。CI 里没加它，等于校验白跑。

---

## 五、让配置里的类型直接用引擎既有的类

配置里定义一个 `vector3`，Luban 会生成一个 `vector3` 类。但项目里已经有
`UnityEngine.Vector3` 了 —— 你不想每次用都转换一次。

在类型定义上挂一个 `<mapper>`：

```xml
<bean name="vector3" valueType="1" sep=",">
    <var name="x" type="float" />
    <var name="y" type="float" />
    <var name="z" type="float" />
    <mapper target="client" codeTarget="cs-bin,cs-simple-json">
        <option name="type" value="UnityEngine.Vector3" />
        <option name="constructor" value="ExternalTypeUtil.NewVector3" />
    </mapper>
</bean>
```

生成的代码里这个字段的类型就直接是 `UnityEngine.Vector3`，**策划那边填法完全不变**。

| option | 什么时候要写 |
|---|---|
| `type` | 总是。目标类型的全名 |
| `constructor` | **结构体要写，枚举不用**。枚举能直接强转，结构体不行，得给一个转换函数 |

### 两个条件都匹配才生效

`target` 和 `codeTarget` 是**与**的关系，任一不匹配就当没写。示例语料里
`AudioType` 的映射实测如下：

```
-t all    -c cs-simple-json  →  (AudioType)                  没映射
-t client -c cs-simple-json  →  (UnityEngine.AudioType)      映射生效
-t server -c cs-simple-json  →  (AudioType)                  没映射
```

`server` 那条 mapper 其实存在，但它写的是 `codeTarget="cs-bin,cs-dotnet-json"`，
与命令行给的 `cs-simple-json` 对不上。**映射没生效不会报错**，只是安静地用回
自己生成的类型 —— 编译期才会发现类型不对。

所以：**一个类型要在几个 target / codeTarget 下都映射，就写几条 `<mapper>`**，
或者在一条里用逗号列全。

> 目前只有 C# 支持类型映射。

---

## 六、多语言，按语言分目录出包

整条链路（文本表、`text` 类型、导出时替换还是运行时替换、每种语言导一次）
在 → **[本地化](localization.md)**。

---

## 相关

- `luban.conf` 每一项的完整说明 → [配置参考](configuration.md)
- target 是三个不同的东西、格式怎么配套 → [目标与输出](targets-and-output.md)
