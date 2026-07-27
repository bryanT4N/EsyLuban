# 右键菜单

**给谁看**：接入项目的程序员。装菜单、配菜单，以及在改动它之前先弄明白它为什么是现在这个样子。

**读完你能做什么**：在一台机器上装好菜单，让同机的多个项目各用各的配置，并且以后升级 EsyLuban 不必再碰注册表。

**不该在这里找什么**：菜单不出现、导出报错、产物不对 → [出错了怎么办](troubleshooting.md)。工程怎么摆、`luban.conf` 从哪来 → [接入你的项目](setup.md)。

策划那边只需要一句话：**右键那张表（或它所在的文件夹）→ Luban Export (Data)**。

---

装好之后，在资源管理器里右键一个文件夹或一张表就是这样：

<img src="images/context-menu.png" alt="右键菜单中的 Luban Export (Data) 与 Luban Export (Code)" width="560">


## 装什么、装在哪

**以管理员身份**运行一次：

```
Tools\Luban\contextmenu\install_luban_context_menu.bat
```

它做两件事。

**一，把两个转发器复制到 `%ProgramData%\EsyLuban\`：**

```
%ProgramData%\EsyLuban\menu_entry_data.bat
%ProgramData%\EsyLuban\menu_entry_code.bat
```

注意被复制走的是 `menu_entry_*.bat`，**不是** `run_luban_context_menu_*.bat`。
两者的分工是这份文档后半段的主题，也是升级不用重装的原因。

**二，往 HKLM 注册三个位置**，每个菜单项各一份：

| 注册表位置 | 覆盖的右键场景 |
|---|---|
| `HKLM\Software\Classes\Directory\shell\<菜单名>` | 右键一个文件夹 |
| `HKLM\Software\Classes\Directory\Background\shell\<菜单名>` | 在文件夹空白处右键 |
| `HKLM\Software\Classes\*\shell\<菜单名>` | 右键单个文件（比如一个 xlsx） |

三个都要有。缺哪个就是哪种右键场景静默失效 —— 菜单在别处好好的，唯独在那种情形下不出现。
文件夹空白处那个用的是 `%V` 而不是 `%1`，因为此时被右键的是「当前目录」而非某个选中项。

装好后能看到两项：

- **Luban Export (Data)** —— 导出所选范围内那些表的数据
- **Luban Export (Code)** —— 为它们生成代码

写的是 HKLM，**一台机器装一次**，之后这台机器上的所有项目共用这套入口。
卸载用 `uninstall_luban_context_menu.bat`，同样要管理员。

---

## 它被点击之后做了什么

```
%ProgramData%\EsyLuban\menu_entry_data.bat        装一次就冻结在这
   │  1. 从右键的位置向上最多 5 层，找 <项目>\Tools\Luban\luban.conf
   │  2. 把「所选路径」和「找到的 Tools\Luban 目录」一并交给下面这个
   ▼
<项目>\Tools\Luban\contextmenu\run_luban_context_menu_data.bat    随项目升级
      runtime 寻址、conf 解析、--listTables、-o 拼装、
      cleanUpOutputDir、按 target 分目录、全部提示文案
```

向上查找 `luban.conf` 这一步，就是同一台机器上多个项目互不干扰的全部原因：
菜单是全局的，配置是就近的。

实现脚本随后按顺序做四件事。

**一，定位运行时。** 先看 `luban.conf` 旁边的 `runtime\Luban.exe`，找不到再向上搜。
前者是外部项目的正常情况，后者是本仓库示例工程共享一份运行时的特例。

**二，解析 `luban.conf`，读不了就拒绝运行。**

> `luban.conf` 里**不能写 `//` 注释，也不能留尾逗号**。
> Luban 自己的解析器两样都接受（`ReadCommentHandling.Skip` + `AllowTrailingCommas`），
> 但右键脚本读配置用的是 Windows 自带的 PowerShell 5.1，它的 `ConvertFrom-Json`
> 两样都不接受。也就是说同一份 conf，Luban 读得了、右键读不了。
>
> 所以脚本现在会先整体解析一次，失败就报错并 `exit 7`。这不是洁癖：以前解析失败时
> 每个查询各自返回空，脚本静静回落到硬编码默认值 —— 菜单照常执行、退出码 0、打印
> Done，却完全忽略了你写的整个 `contextMenu` 段。**悄悄用另一套设置比拒绝运行危险得多。**
>
> PowerShell 7（`pwsh`）两样都支持，所以这个问题在 pwsh 下复现不出来。

**三，问 Luban「所选范围内有哪些表」：**

```
runtime\Luban.exe --conf luban.conf -t <targets 里的第一个> --listTables <所选路径>
```

它只做 schema 收集，然后把表全名逐行打到 stdout（日志走 stderr），不生成任何东西。

**四，把拿到的每个表名拼成一个 `-o`，再逐个 target 正式导出一次：**

```
runtime\Luban.exe --conf luban.conf -t client -d json ^
  -x cleanUpOutputDir=0 -x outputSaver.json.cleanUpOutputDir=0 ^
  -o demo.TbItem -o demo.TbMonster
```

两个细节值得记住，它们各自挡住过一类事故：

**为什么是 `--listTables` + `-o`，而不是直接把扫描范围缩到所选路径。**
schema 是全局加载的。若只导入所选范围内的表，范围外那些被引用的表就会悬空，
Luban 直接中止。所以这条链路的形状是固定的：**全量加载 schema 保证跨表引用可解析，
`-o` 只限定实际输出哪几张表。** 右键脚本因此从不设置 `tableImporter.scanPath`。

**为什么必须 `cleanUpOutputDir=0`。** Luban 默认会删掉输出目录里所有不属于本次产物的
文件。和 `-o` 凑在一起就意味着：导一张表会删光其余所有表的产物，连同那个目录里的无关
文件。局部导表的意义就没了。`gen.bat` 的全量导出保留这个清理 —— 在那里它是对的，
删的是已经不存在的表留下的垃圾。

---

## 菜单读 `luban.conf` 的哪一段

```json
"contextMenu":
{
  "data":
  {
    "targets": ["client", "server", "editor"],
    "dataTarget": "json",
    "outputDataDir":
    {
      "client": "../../Projects/你的工程/Assets/GenData/client",
      "server": "../../Projects/你的工程/Assets/GenData/server"
    },
    "extraArgs": []
  },
  "code":
  {
    "targets": ["client"],
    "codeTargets": ["cs-simple-json"],
    "extraArgs": []
  }
}
```

| 键 | 作用 | 不写时 |
|---|---|---|
| `data.targets` | 数据菜单要导的 target，每个各调用一次 Luban | `client server editor` |
| `data.dataTarget` | 数据格式，即 `-d` | `json` |
| `data.outputDataDir` | target → 输出目录的映射，见下 | 全部落到 `xargs` 里的全局 `outputDataDir` |
| `code.targets` | 代码菜单要导的 target | `client` |
| `code.codeTargets` | 代码语言，即 `-c`，与 `targets` 做笛卡尔积 | `cs-simple-json` |
| `extraArgs` | 追加给命令行的参数，如 `--variant`、`--includeTag`、`-x key=val` | 空 |

相对路径一律以 `Tools/Luban/` 为基准 —— 脚本正是在那个目录里调用 Luban 的。

**`targets` 里只列真正含有这些表的 target。** 列出的每个 target 都会被导一遍；
如果某个 target 的 `groups` 把你选中的表过滤掉了，这次导出对它没有意义，而且往往不是
安静跳过，而是抛一句「`ref` 引用的表没有导出」后失败 —— 被过滤掉的表仍被别的表引用着。
「只给负例或测试用」的 target 应该只由 `gen.bat -t <名字>` 手动跑，不进右键菜单。

### 按 target 分目录要写在这里

`data.outputDataDir` 这个映射是必要的，不是锦上添花：右键会对每个 target 各调一次
Luban，**不给映射的话这几次调用全部写进同一个 `outputDataDir`，后一个覆盖前一个，
最后只剩最后一个 target 的结果。**

而且这件事没法在 `xargs` 里表达。Luban 的 xargs 命名空间绑定的是 **dataTarget /
codeTarget**（`json`、`cs-simple-json`…），不是 `targets` 里的那个 target，
所以 `client.outputDataDir=` 这种写法既不报错也不生效。右键脚本读到上面这份映射后，
会逐个翻译成 `-x outputDataDir=`，走的才是 Luban 真正支持的语义。
（写错了也不必靠眼睛发现，EsyLuban 启动时会对这类死键打 `WARN|[dead xargs]`。）

映射里没列到的 target 回落到全局 `outputDataDir`。命令行的全量导出怎么分目录，
见[目标与输出](targets-and-output.md)。

---

## 一台机器上装多套

同时维护两个用不同 Luban 版本的项目时，安装时给个套件名：

```
install_luban_context_menu.bat MyGame
uninstall_luban_context_menu.bat MyGame
```

菜单变成 `Luban Export (Data) - MyGame`，与默认安装并存。套件名同时作用于注册表键名、
菜单标题和 `%ProgramData%\EsyLuban\<套件名>\` 目录，三者一起隔离，所以两套装置互不覆盖。
卸载必须传入相同的套件名，否则删不到。

注意这跟「多个项目」不是一回事：**同一套菜单本来就能服务任意多个项目**，靠的是向上找
各自的 `luban.conf`。只有当你需要两套不同版本的实现同时在线时，才需要套件名。

---

## 升级：为什么不用重装

**换新版发布包替换掉 `Tools\Luban\` 就完成升级**，右键行为立刻跟着变，不需要管理员，
不需要碰注册表。

因为注册表指向的只是转发器，而转发器里刻意不含任何导表逻辑，只有两条目录契约：

- `luban.conf` 位于 `<项目>\Tools\Luban\`，从右键位置向上最多 5 层
- 真正的实现位于该目录下的 `contextmenu\`

只有这两条契约本身变了，才需要管理员重跑一次安装脚本。

**这个设计是被一次事故换来的。** 早期版本把完整脚本装进 `%ProgramData%`，逻辑就冻结在
安装那一刻 —— 升级工具**不会**升级右键行为，界面上还毫无迹象。这不是「新功能用不上」
那么温和：早期脚本缺 `cleanUpOutputDir=0`，右键导一张表会静默删光其余所有表的产物。
装了新版、以为修好了、其实还在跑旧脚本。安装器现在会主动删掉这些遗留副本。

> **`Tools\Luban\contextmenu\` 不能删。** 它是运行时依赖，不是「装完就没用的安装器」——
> 右键每次导表都要调用它。手工拷贝 `Tools\Luban\` 时最容易漏掉的就是它。
>
> 本仓库的示例工程是例外：它们的 `Tools\Luban\` 下没有 `contextmenu\`，
> 转发器会向上回退到共享的 `esyluban\scripts\contextmenu\`。
