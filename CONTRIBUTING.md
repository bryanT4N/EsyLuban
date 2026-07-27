# 参与开发

**给谁看**：想改 EsyLuban 本身的人。只是想用它的话，去 [文档索引](esyluban/docs/README.md)。

**读完你能做什么**：把仓库跑起来、知道改动会被哪些东西检查、知道怎么加一条检查。

---

## 环境

| 需要 | 说明 |
|---|---|
| Windows | 工具链是 `.bat` + Windows PowerShell 5.1。核心库跨平台，工具链不跨 |
| .NET 8 SDK | 不是运行时，是 SDK（要 `dotnet publish`） |
| git | 有几个守卫要调用它 |

```bat
git clone <你的 fork>
cd EsyLuban
esyluban\scripts\build.bat
```

构建产物落在 `esyluban/runtime/`，不进版本控制。

## 跑测试

三条命令，CI 里跑的也是这三条：

```bat
esyluban\scripts\test\run_unit_tests.bat            :: B1 元数据解析的单元测试
esyluban\scripts\test\run_full_tests_example.bat    :: 全回归，约 30 秒
esyluban\scripts\test\check_gitignore_traps.bat     :: 已含在全回归里，也可单跑
```

全回归通过时会报 `REGRESSION PASSED - N/N checks`。**N 是被断言的**：加了或删了
一项检查而没同步 `EXPECTED_CHECKS`，它会报 `INCONCLUSIVE` 并以非零退出。一个
没人知道自己有多大的测试套件，是可以悄悄丢掉检查的。

### 回归在检查什么

大致分四类，每一类都是从一次真实事故里长出来的：

- **基线比对**（5 套）—— 导出产物与已知good 结果逐文件比 SHA256。`core/` 是上游
  在未迁移语料上的输出，用来证明「换了定义方式，结果一字未变」，它不可再生。
- **负例** —— 语料里有故意写坏的记录。校验器对 SHA256 完全不可见（它们全部失效
  的话，输出字节一模一样），所以按来源分类计数：哪一族校验器不工作了，一眼看出。
  另有两类会中止整个导出的硬失败（重复主键、`mode="one"` 多行），单独放在
  `examples/negatives_hard/`，断言方向相反 —— 必须失败，且必须因为那条错误失败。
- **使用者入口** —— 回归走 `gen.bat` 和右键菜单，不直接调 `Luban.exe`。曾经有
  一次冒烟测试绕过 `gen.bat`，于是 `gen.bat` 自己根本跑不起来却一路绿灯。
- **守卫** —— 见下一节。

### 怎么新增一条断言

`run_full_tests_example.bat` 里，一项断言长这样：

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check_something.ps1"
if errorlevel 1 set /a FAILED+=1
set /a CHECKS+=1
```

然后把 `EXPECTED_CHECKS` 加一。三条约束：

1. **`.bat` 与 `.ps1` 都必须是纯 ASCII。** cmd 按系统 ANSI 代码页解析 `.bat`；
   Windows PowerShell 5.1 解析无 BOM 的 `.ps1` 也一样。写中文注释会变乱码，
   而且可能直接破坏解析 —— 有一次一行中文注释把下一行的 `#include` 吃掉了。
2. **`( )` 块里一律用 `!VAR!`，不要用百分号。** cmd 在**读取**整个块时就展开
   百分号，路径里带 `)` 会让块提前闭合，脚本在解析期就死。
3. **新断言必须反向验证过。** 也就是：故意把它该抓的东西弄坏一次，确认它真的
   报错、且报的是对的那一条。一个不会失败的断言比没有断言更糟 —— 它让人以为
   这块有覆盖。

### 怎么刷新基线

```bat
esyluban\scripts\test\refresh_coverage_baseline.bat
```

它用 `robocopy /MIR` 镜像同步，**刷错就永久覆盖**，之后的回归从此失去参照。
只在确认输出变化符合预期时才刷。

`core/` 没有刷新脚本，这是有意的 —— 它是历史证据，不可再生。
xml / code_cs / json_l10n 三套目前需要手工同步，这是已知缺口。

## 改动会被哪些守卫检查

| 守卫 | 它守住什么 |
|---|---|
| `check_upstream_boundary.ps1` | 对上游的改动面必须与 [`upstream_boundary.txt`](esyluban/upstream_boundary.txt) 完全一致 |
| `check_tool_copies.ps1` | 三份 `gen.bat`/`check.bat` 副本必须一致（发布给用户的是 `templates/` 那份） |
| `check_doc_facts.ps1` | 文档里可被源码证否的说法：target 数量、右键的实现机制、安装器行为、模板可用性、引用的路径是否存在 |
| `check_gitignore_traps.ps1` | 自有源文件不被 `.gitignore` 静默吞掉 |

**改了上游文件怎么办？** 允许，但要先在 `upstream_boundary.txt` 里写下它和「为什么
绕不开」，否则回归会拦下。这条约束以前只是 README 里的一句话，而它失效过：长期
写着「src/ 下有两处修改」，实际是三处 —— 且 README 就在上一行教读者跑命令验证。

## 代码风格

- C# 跟随上游的 `.editorconfig`，提交前可跑 `scripts/format.bat`
- `.bat` / `.ps1` 纯 ASCII，注释用英文
- `.md` / `.py` / C# 注释用中文
- 注释写**为什么**，尤其是「为什么不那样做」。这个仓库里最有价值的注释都是这类，
  比如某个实现方案被否决的原因、某个坑咬过几次

## 提交信息

```
<类型>: <一句话说清楚什么坏了 / 加了什么>

（正文：为什么这么改、怎么验证的）
```

类型用 `feat` / `fix` / `test` / `docs` / `refactor` / `chore` / `ci`。
标题写**修好了什么问题**，不是**改了什么文件**。

## 文档

文档有自己的规矩，写在 [文档索引](esyluban/docs/README.md) 末尾。核心一条：
**能被源码证否的说法，都要由回归守着**。

修复历史写进 [CHANGELOG](CHANGELOG.md)，不写进说明书。
