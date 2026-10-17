# BilibiliRegex.dll

供 PotPlayer AngelScript 调用的 JavaScript 正则 DLL，仅包含 QuickJS-NG 的
`libregexp`、Unicode 支持代码及本项目的 C ABI 封装，不加载完整 JS 运行时。

## 成品

- `Extension/Lib/BilibiliRegex.dll`：x64，适用于 64 位 PotPlayer。
- DLL 静态链接 C 运行库，仅动态依赖 Windows 的 `KERNEL32.dll`。
- 要求 Windows 8 或更新版本及 64 位 PotPlayer。
- 使用 Windows x64 标准调用约定。

将 DLL 放到播放器的 `Extension\Lib` 目录，同时更新
`Extension\Media\PlayParse\MediaPlayParse - Bilibili.as`。播放脚本已接入本 DLL，
使用 `HostGetExtensionFolder() + "Lib\\BilibiliRegex.dll"` 定位文件；不含正则规则时不加载 DLL。
本次规则集优化需要同时替换 DLL 和脚本；旧 DLL 缺少新接口时会明确报错。
规则集、归并排序及分段收集优化已由用户在 64 位 PotPlayer 中验证。

每批弹幕只编译一次规则，创建只读规则集，每条弹幕仅调用一次 DLL 并转换一次文本；
DLL 按原顺序逐条匹配，命中即停止。线程结束后释放规则集、编译句柄并卸载 DLL。匹配超时不会停用整条规则，
本批弹幕会明确生成失败，避免将未完成的过滤当成成功。无效语法按网页行为跳过并记录规则。
正式版统一使用脚本现有的 `log()`，由配置文件的 `debug` 开关控制。
开启 debug 时，成功生成弹幕只输出一条摘要：

```text
[时间] - [Danmaku] aid=... cid=... comments=... rendered=... total_ms=... render_ms=...
```

`comments` 是解析后的条目数，`rendered` 是经过过滤、去重及合并后的待渲染条目数；
`total_ms` 是整个 BuildDanmakuAss 的墙钟毫秒，不包含外部的播放地址解析；
`render_ms` 是 ASS 轨道计算、格式化和拼接的耗时，用于核实渲染优化的实际效果。
错误日志保留 `[DanmakuRegexDllError]`、失败阶段、规则编号及原因，也通过 `log()` 输出。
关闭 debug 时不输出这些日志；生成失败仍通过调用方的提示框告知，并提示开启 debug 查看原因。
临时分段日志、DLL 加载成功日志及逐阶段性能日志和对应计时变量均已删除。

排序使用脚本中的迭代归并排序，最坏 O(n log n)，额外缓冲区约为条目数 × 8 字节。
完整比较原来的 `时间毫秒 << 32 | 原始索引`，保留相同时间下的条目次序。
本机核对的官方 AngelScript 2.38 SDK 对基础类型的 `sortAsc` 使用插入排序；PotPlayer
内部实现未确认；用户的诊断版实测中，73,249 条弹幕排序用时 94 ms。

分段结果收集按每段长度一次性 `resize` 六个总数组，然后按索引写入，保留原始分段、
条目及时间键顺序。这样避免总数组对每条弹幕逐次扩容。在本机 SDK 中，容量不足时只按
本次需求大小重新分配并复制旧元素，逐条 `insertLast` 会导致反复搬运整个数组。
本轮保留原 Protobuf 解码器及五线程下载方式，无需更新 DLL。

ASS 生成复用两位时间数字、颜色字节和轨道坐标，缓存 128 字符以内弹幕的位置标签；
更长的文本直接计算，缓存大小有固定上限。相同起始厘秒复用时间前缀，白色弹幕复用完整
样式标签。原文字符计数与 ASS 转义合并为一次扫描，正文按段追加，减少临时字符串。
轨道选择、碰撞判断、时间舍入、颜色、文本转义及两层特效的输出规则保持一致。
该优化只修改脚本，仍使用 `log()` 输出单行摘要，新增 `render_ms` 字段。

## 导出接口

函数声明见 `BilibiliRegex.h`。导出名称无名称修饰。

| 函数 | 返回类型 | HostCallProc 签名 | 参数 |
| --- | --- | --- | --- |
| `BiliRegexCompileRule` | `uintptr_t` | `PII` | 规则 UTF-8 指针、字节数、超时毫秒 |
| `BiliRegexCompile` | `uintptr_t` | `PIPI` | 模式 UTF-8 指针、字节数、以 NUL 结尾的标志字符串指针、超时毫秒 |
| `BiliRegexTest` | `int` | `PPII` | 编译句柄、文本 UTF-8 指针、字节数、超时毫秒 |
| `BiliRegexFree` | `int` | `P` | 编译句柄 |
| `BiliRegexCreateSet` | `uintptr_t` | `I` | 规则槽位数 |
| `BiliRegexSetRule` | `int` | `PIP` | 规则集句柄、从 0 开始的槽位、编译句柄（0 表示跳过） |
| `BiliRegexTestSet` | `int` | `PPII` | 规则集句柄、文本 UTF-8 指针、字节数、每条规则超时毫秒 |
| `BiliRegexFreeSet` | `int` | `P` | 规则集句柄，不释放借用的编译句柄 |
| `BiliRegexGetLastErrorRule` | `int` | 空字符串 | 失败规则的原始槽位，从 0 开始；未知为 -1 |
| `BiliRegexGetLastErrorCode` | `int` | 空字符串 | 无 |
| `BiliRegexGetLastError` | `const char *` | 空字符串 | 无 |
| `BiliRegexGetAbiVersion` | `uint32_t` | 空字符串 | 无，当前为 1 |
| `BiliRegexGetEngineVersion` | `const char *` | 空字符串 | 无 |

`Compile`/`CompileRule` 成功返回非零句柄，失败返回 0。`Test` 返回：

| 值 | 含义 |
| --- | --- |
| 1 | 匹配，应屏蔽 |
| 0 | 不匹配 |
| -1 | 参数无效 |
| -2 | 正则或标志无效（编译错误码） |
| -3 | 超时 |
| -4 | 内存不足或超过分配预算 |
| -5 | 输入不是合法 UTF-8 |
| -6 | 编译时正则嵌套超过当前线程可用栈 |
| -7 | 引擎内部执行错误 |

不能将负值当作“不匹配”，也不能将任意非零值都当作“匹配”。错误码和错误文本按线程保存，
在下一次编译、匹配、创建、设置或释放调用时重置；错误查询不重置。
`GetLastError` 返回的字符串由 DLL 持有，需及时复制，不能自行释放。

显式长度均为 UTF-8 **字节数**，支持字符串中的 NUL；模式和文本不要求调用方添加终止符。
`Compile` 的 flags 参数是标准 NUL 结尾字符串，支持 `dgimsuvy`，重复标志及 `uv` 同时出现会报错。

## Bilibili 网页端规则语义

`CompileRule` 对齐已核对的播放器 `core.9b2f4c3c.js`：

1. 用 `/表达式/img` 格式识别规则，主体非空，标志仅识别 0 至 3 个 `i/m/g` 字符。
2. 尝试用主体及标志编译；若不符合包装格式，或主体/标志有语法错误，将整条原规则按无标志正则编译。
3. 资源不足或超时会明确报错，不会伪装成语法错误并触发回退。

例如 `/foo/i` 匹配 `FOO`；`/foo/u` 按官方该版本的解析方式是无标志的完整模式 `/foo/u`，
不是带 `u` 的 `foo`。需要直接使用 `u/v` 时使用通用的 `Compile` 接口。

模式未启用 `u/v` 时，按 QuickJS 自身构造器的方式转换成 CESU-8；文本始终转换为 UTF-16。
因此无 `u` 的 `^.$` 不匹配单个表情 `😀`，有 `u` 时匹配。每次 Test 均从索引 0 开始，
没有共享 `lastIndex`，符合官方每次新建 RegExp 后调用一次 test 的效果。

编译句柄不可变，可跨线程并行 Test；每次匹配的捕获区、预算和错误状态独立。
须等待所有使用该句柄的线程完成后再 Free；句柄只能释放一次。所有句柄释放后才能卸载 DLL。
规则集只借用编译句柄，填充完毕后才能共享；并发匹配期间不可修改规则集。先释放规则集，
再释放它引用的编译句柄。规则集沿用单规则接口的语义，空槽跳过，出错停止并保留原始槽位编号。

这是 QuickJS-NG 的实现，**不是 V8 本体**。差分测试通过不等于覆盖 V8 所有版本的所有输入。
上游还有限制，例如捕获组数量、嵌套量词寄存器数量，Unicode 数据版本也可能与目标浏览器不同。

## 预算

超时参数 0 表示默认 250 毫秒，可显式指定更长时间。检查依赖引擎检查点，是协作式截止时间，
不保证精确到毫秒。每次编译或匹配的引擎分配预算为 64 MiB；额外大文本转换也会受此预算约束。
超时不会破坏或停用编译句柄，后续仍可正常使用。

## AngelScript 调用示例

`dllPath` 指向已安装的同位数 DLL 的绝对路径。此示例只演示一次调用；实际使用时应在一批弹幕
处理前加载并编译一次，在整批完成后释放，避免对每条弹幕重新编译。

```cpp
void TestBilibiliRegexDll(const string &in dllPath) {
    uintptr dll = HostLoadLibrary(dllPath);
    if (dll == 0) { HostPrintUTF8("BilibiliRegex.dll 加载失败"); return; }

    uintptr compile = HostGetProcAddress(dll, "BiliRegexCompileRule");
    uintptr test = HostGetProcAddress(dll, "BiliRegexTest");
    uintptr release = HostGetProcAddress(dll, "BiliRegexFree");
    uintptr getError = HostGetProcAddress(dll, "BiliRegexGetLastError");
    if (compile == 0 || test == 0 || release == 0 || getError == 0) {
        HostPrintUTF8("BilibiliRegex.dll 接口缺失");
        HostFreeLibrary(dll);
        return;
    }

    string rule = ".*拜年.*";
    string text = "新年拜年弹幕";
    uintptr handle = HostCallProcUIntPtr(compile, "PII",
        HostString2UIntPtr(rule), rule.length(), 250);
    if (handle == 0) {
        uintptr error = HostCallProcUIntPtr(getError, "");
        HostPrintUTF8(HostUIntPtr2String(error));
    } else {
        int result = HostCallProcInt(test, "PPII", handle,
            HostString2UIntPtr(text), text.length(), 250);
        if (result < 0) {
            uintptr error = HostCallProcUIntPtr(getError, "");
            HostPrintUTF8(HostUIntPtr2String(error));
        } else HostPrintUTF8(result == 1 ? "匹配，应屏蔽" : "不匹配");
        HostCallProcInt(release, "P", handle);
    }
    HostFreeLibrary(dll);
}
```

## 构建与验证

需要 Visual Studio 的 C++ x64 构建工具；用户运行成品不需要这些工具、Node 或 Python。

```powershell
.\Native\BilibiliRegex\build.ps1
python .\Native\BilibiliRegex\tests\verify.py
```

验证额外需要 Python 和 Node.js，Node/V8 只用作独立结果参照。可通过 `--log 文件路径` 加入
本次的 `[DanmakuRegexError]` 日志，不会将用户日志复制进源码仓库。

测试覆盖：网页包装规则回退、大小写与换行、Unicode 与表情、无 u/u/v、断言与反向引用、
嵌入 NUL、单规则与规则集结果一致、重复调用、八线程共享句柄及规则集、错误隔离、
非法 UTF-8、超时恢复与失败槽位、命中后停止、显式长度和深层嵌套保护。
最新本地报告在 `build/verification.json`。

播放脚本集成还可使用官方 AngelScript SDK 检查，直接提取实际脚本中的类和过滤代码，
通过模拟宿主 API 调用真实 DLL，验证加载、编译、资源回收、过滤回退及错误处理：

```powershell
python .\Native\BilibiliRegex\tests\verify_integration.py --sdk C:\path\to\sdk
```

集成测试里的线程启动使用同步模拟；DLL 的真实八线程调用由前述 native_test 覆盖。
PotPlayer 自身的 `Host*` 实现仍需在播放器内验证。

可加 `--benchmark` 运行 73,250 条短中文文本、11 条均未命中的实际规则的过滤基准。
同机首轮对比：逐规则调用版本 968 ms、805,750 次匹配调用；规则集版本 593 ms、73,250 次。
这些结果来自模拟宿主的过滤阶段，不能直接用作 PotPlayer 整个弹幕生成耗时的预测。
集成回归也提取并执行实际合并、ASS 渲染和现有 `log()` 代码，验证成功时单行摘要、
debug 关闭时静默以及错误处理。
同一基准还比较 73,252 个模拟分段乱序键的新旧排序：本机首轮旧排序 813 ms，
归并排序 109 ms，完整结果相同。这也不是 PotPlayer 实测值。
排序回归覆盖空数组、单条、已排序、倒序、重复键、相同时间戳和完整无符号 64 位比较；
分段循环使用内存 Protobuf 响应验证实际下载、解码、收集及排序代码。

可使用 `--benchmark --baseline-script C:\path\to\previous-playback.as` 对照保存的上一版脚本。
该基线须包含兼容的分段处理循环。测试向两版代码提供相同的五段
Protobuf 数据，共 73,250 条弹幕，包含 ID、时间、模式、字体大小、颜色、用户哈希、正文、
发送时间、权重等字段；网络调用和线程运行采用同步模拟，逐项检查收集后的全部字段和顺序。
本机对照：收集耗时 2,094 ms → 32 ms；不含网络的整个解码/收集循环 2,672 ms → 625 ms。
这些结果来自官方 SDK 的模拟宿主环境。用户在 PotPlayer 中的诊断版实测：收集 16 ms，
下载/解码/收集合计 2,063 ms，弹幕生成总计 4,063 ms。正式版保留一行总耗时及 ASS 耗时摘要；
基准中的分段循环也只输出整体耗时，不再输出逐阶段诊断值。

使用 `--render-baseline C:\path\to\previous-playback.as` 可提取旧版和当前版的实际 ASS
渲染代码，进行逐字节对照和计时。覆盖四种弹幕模式、五种字体效果、单轨道及多轨道、
轨道拥挤回退、字体大小、长文本与缓存边界、中文/英文/表情、换行和特殊字符、NUL、
空文本、合并数量后缀和时间溢出边界；另对照 63,286 条非空合成弹幕生成的全部 ASS 字节。
计时不包含过滤、合并或测试数据初始化。此基准仍使用官方 SDK 模拟宿主，实际收益需在
PotPlayer 内验证。本机基准：750 ms → 453 ms，约减少 40%，ASS 均为 11,288,177 字节且逐字节相同。
正式脚本只在单行摘要中附带 `render_ms`，不会重新输出分段或逐阶段日志。

## 来源和许可证

QuickJS-NG **v0.17.0**，提交 `6d46d07d04041b40f4f49eaa7fdebe44c314c699`。
仅复制所需源码，未修改 vendor 文件；校验值记录于 `vendor/quickjs-ng/UPSTREAM.json`。

封装、构建和测试代码采用本目录 LICENSE 中的 MIT 许可证；上游许可证在
`vendor/quickjs-ng/LICENSE`。分发 DLL 时保留 `Extension/Lib/BilibiliRegex.LICENSE.txt`。
