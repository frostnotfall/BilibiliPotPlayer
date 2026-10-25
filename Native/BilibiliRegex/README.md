# BilibiliRegex.dll

供 PotPlayer AngelScript 调用的弹幕处理 DLL，包含 QuickJS-NG 的 `libregexp`、
Unicode 支持代码、pakku 相似合并/字号调整、空间优选及字体度量，不加载完整 JS 运行时。

## 成品

- `Extension/Lib/BilibiliRegex.dll`：x64，适用于 64 位 PotPlayer。
- DLL 静态链接 C/C++ 运行库，仅动态依赖 Windows 的 `KERNEL32.dll`、`GDI32.dll`。
- 要求 Windows 8 或更新版本及 64 位 PotPlayer。
- 使用 Windows x64 标准调用约定。

将 DLL 放到播放器的 `Extension\Lib` 目录，同时更新
`Extension\Media\PlayParse\MediaPlayParse - Bilibili.as`。播放脚本已接入本 DLL，
使用 `HostGetExtensionFolder() + "Lib\\BilibiliRegex.dll"` 定位文件。内置弹幕有数据时会加载 DLL，
用于字体度量与自动优选；配置了正则规则时，还会先加载 DLL 执行正则过滤。
需要同时替换 DLL 和脚本；旧 DLL 缺少新接口时会明确报错。
规则集、归并排序及分段收集优化已由用户在 64 位 PotPlayer 中验证。

每批弹幕只编译一次规则，创建只读规则集，每个过滤线程缓存短文本的正则结果，
最多 4096 条、每条最多 384 字节；命中后直接复用，不跨用户复用哈希屏蔽结果。
错误不进入缓存，长文本仍逐条检查。缓存未命中时，每条弹幕仅调用一次 DLL 并转换一次文本；
DLL 按原顺序逐条匹配，命中即停止。线程结束后释放规则集、编译句柄并卸载 DLL。匹配超时不会停用整条规则，
本批弹幕会明确生成失败，避免将未完成的过滤当成成功。无效语法按网页行为跳过并记录规则。
正式版统一使用脚本现有的 `log()`，由配置文件的 `debug` 开关控制。
开启 debug 时，成功生成弹幕只输出一条摘要：

```text
[时间] - [Danmaku] aid=... cid=... comments=... rendered=... total_ms=... render_ms=... fetch_ms=... cloud_wait_ms=... sort_ms=... filter_ms=... merge_ms=... prepare_ms=... layout_ms=... refine_ms=... ass_ms=...
```

`comments` 是解析后的条目数，`rendered` 是最终写入 ASS 的弹幕数；
`total_ms` 是整个 BuildDanmakuAss 的墙钟毫秒，不包含外部的播放地址解析；
`render_ms` 包含字号/文本/测宽准备、布局、顶部补位和 ASS 拼接；对应细分字段为
`prepare_ms`、`layout_ms`、`refine_ms`、`ass_ms`。`fetch_ms` 包含初始化、并发下载、
Protobuf 解析和分段汇总；`cloud_wait_ms` 是随后等待及处理云规则的额外耗时；
`sort_ms`、`filter_ms`、`merge_ms` 分别记录时间排序、规则过滤和用户去重/相似合并。
错误日志保留 `[DanmakuRegexDllError]`、失败阶段、规则编号及原因，也通过 `log()` 输出。
关闭 debug 时不输出这些日志；生成失败仍通过调用方的提示框告知，并提示开启 debug 查看原因。
所有计时仍集中在一条摘要中，不输出逐条弹幕或逐段成功日志。

排序先用 O(n) 扫描检查已有序输入，直接返回且不分配缓冲区；否则使用迭代归并排序，
最坏 O(n log n)，额外缓冲区约为条目数 × 8 字节。
完整比较原来的 `时间毫秒 << 32 | 原始索引`，保留相同时间下的条目次序。
本机核对的官方 AngelScript 2.38 SDK 对基础类型的 `sortAsc` 使用插入排序；PotPlayer
内部实现未确认；用户的诊断版实测中，73,249 条弹幕排序用时 94 ms。

分段下载最多五个线程，任一线程完成即可启动下一段，避免被较早的慢分段阻塞。
结果暂存后按原段号汇总，保留原始分段、条目及相同时间下的优先次序。
解码线程的六个数组显式按倍数预留容量，总数组也按需倍增容量后 `resize` 并按索引写入；
四个候选数组按输入条数一次预留。在官方 SDK 中，容量不足时只按本次需求重新分配，
这些预留避免逐条 `insertLast` 反复搬运已有元素。原 Protobuf 字段处理和并发上限保持一致。
原生相似特征还会预留容器容量，并缓存二元词频向量的模长，匹配规则保持一致。

本地官方 SDK 模拟宿主对照：73,250 条弹幕的解析及汇总从 656 ms 降至 344 ms；
候选构建至 ASS 返回的三次中位数从 2016 ms 降至 1141 ms，生成的 3,537,078 字节
ASS 完全一致。11 条正则处理重复文本时，73,250 条只需 8 次原生匹配（每线程一次）。
这些结果不包含网络，不代表 PotPlayer 的实际耗时，下载调度收益需在播放器中确认。
保存优化前的播放脚本后可重现字段检查、ASS 字节对照及基准：

```powershell
python Native/BilibiliRegex/tests/verify_integration.py --sdk D:/src/angelscript --benchmark --baseline-script PATH_TO_PREVIOUS_SCRIPT --render-baseline PATH_TO_PREVIOUS_SCRIPT
```

回归额外覆盖较早分段延迟时继续启动后续下载、完成乱序时仍按段号汇总、定时等待成功、
正则缓存的命中/淘汰/长文本旁路，以及相同文本来自不同用户时的哈希屏蔽。

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

此命令还通过 `tests/verify_metadata.py` 提取生产脚本的历史标识、起播时间、
Cookie 字段提取、JS 文件读取及直播心跳控制流程，在同一 AngelScript 运行时中回归。
Cookie/JSON/HTTP 使用测试替身，Node 检查原聊天 JS 的语法。
完整范围和 PotPlayer 内的人工验收见仓库 `docs/PotPlayer-1.7.23156.md`。

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

在引入 pakku 之前，使用 `--render-baseline C:\path\to\previous-playback.as` 可提取旧版和当前版的实际 ASS
渲染代码，进行逐字节对照和计时。覆盖四种弹幕模式、五种字体效果、单轨道及多轨道、
轨道拥挤回退、字体大小、长文本与缓存边界、中文/英文/表情、换行和特殊字符、NUL、
空文本、合并数量后缀和时间溢出边界；另对照 63,286 条非空合成弹幕生成的全部 ASS 字节。
计时不包含过滤、合并或测试数据初始化。此基准仍使用官方 SDK 模拟宿主，实际收益需在
PotPlayer 内验证。本机基准：750 ms → 453 ms，约减少 40%，ASS 均为 11,288,177 字节且逐字节相同。
正式脚本只在单行摘要中附带 `render_ms`，不会重新输出分段或逐阶段日志。
引入 pakku 后布局和优选结果已按需求变化，此参数仅接受同样包含新原生处理接口的基线；
当前以几何布局回归为准，不能再要求与引入 pakku 之前逐字节一致。

## 来源和许可证

### 弹幕合并、字号与优选

`Danmaku.cpp` 在同一 DLL 中提供原生弹幕处理接口，播放脚本不新增独立函数，
仅为现有 DLL 包装类补充接口方法。内置弹幕现在需要同步更新该 DLL；加载失败或接口
过旧会终止生成并记录诊断，不会悄悄退回旧的完全相同合并算法。

参考 [pakku.js](https://github.com/xmcp/pakku.js) 提交
`2cb6f52aba70d6b685aaff9a1c03aabec7f299b2`：

- 30 秒窗口，以组首条计时；忽略尾部标点、规范全半角与空格、233/666 刷屏归一化。
- 字符频次 L1 差、拼音频次 L1 差（阈值 5，短文本收紧）和循环二元词频余弦平方（45%）。
- 跨普通弹幕模式合并，固定弹幕优先级为底部、顶部、滚动；选取频次最高文本，平局取中位长度。
- 合并不超过 5 条不放大，超过后乘 `ln(count)/ln(5)`；输出整数向上取整。
- 5 秒密度窗口，密度值为 `sqrt(等效字数) * clamp(字号/25, 0.7, 2.5)^1.5`，
  仅供自动缩小字号使用，不根据密度或概率删除弹幕。
- 开启自动缩小时，按 `min((密度/75)^0.35, 1.732)` 缩小，最终不低于 16 号。

自动弹幕优选由 `danmaku.autoSelectDanmaku` 控制，默认开启，缺少该配置项时保持开启。
关闭后按时间顺序使用普通轨道，轨道满时复用最早可用轨道，允许重叠，保留全部经过
过滤和合并的候选；相似合并、合并后放大和自动缩小字号仍独立生效。
开启时执行顺序为：规则过滤/用户去重 → 相似合并 →
放大及自动缩小字号 → 文本与宽度处理 → **按实际布局空间优选** → 写入 ASS。
先按时间顺序完成全部候选的字号调整，再按合并数量从多到少安排空间，数量相同按
权重和原始顺序；普通弹幕使用剩余空位。发送时间和显示时长保持不变，只有找不到
安全位置才舍弃，不会强行覆盖已占用轨道。输出仍按原时间排序。
原生 `Prepare`/`Commit` 仅完成字号与密度计算，空间优选由 `LayoutInit`/`Place` 执行，
随后 `RefineTop` 根据全部已接受的布局调整顶部补位坐标。
即使较晚发送的合并弹幕与较早的普通弹幕竞争空间，也能优先保留合并弹幕。

布局采用全局时间索引，查询完整显示区间内的冲突，包括后续已预留的合并弹幕。
顶部与滚动弹幕独立计算容量，彼此可以重叠，不会因为另一种弹幕占用而下移或丢弃。
顶部优先从上往下填满常规居中位置；常规位置满后，补位空位按离画面水平中央的距离
由近到远选择，同等距离先左后右，同一横坐标从上往下填充，尽量避免贴向屏幕边缘。
整批容量优选完成后，按优先级调整补位坐标，优先选择整个显示期间都不会与其他
弹幕相交的空白矩形，包括较低的左右空位；只有无空白时才保留允许的滚动重叠。
多个空白矩形仍优先选择更靠近水平中央的位置，即使它比边缘空位更低。
这一步只调整已保留弹幕的位置，不重新删除、放大或缩小弹幕，也不改变显示时间。
顶部固定弹幕彼此始终不重叠。滚动方向共享空间，检查入场与追尾/迎面相交。
顶部无空位结果可复用到下一次进入/离开事件，避免密集重复尝试。

精确文本散列表先行；仅比较当前时间窗口的组，过期时释放特征与别名；每组特征只
生成一次。拼音表为编译期数组，免去 DLL 加载时创建数千个散列表节点。
ASS 生成使用实际字号计算占用轨道，运动宽度通过 GDI 字体度量并按 ASS 行高归一化，
避免“字数 × 字号”高估宽度；字体与最多 4096 条短文本宽度在批次内复用，
运动坐标按像素宽度/纵坐标分配缓存。所有模式均沿用原始行距规则：
最终字号加 4 像素；按像素搜索空位，避免缩小后仍占用原字号或取整后的轨道高度。
水平安全间隔为 2 像素。找不到可用位置则跳过，不强制覆盖未到期的顶部弹幕；
时间碰撞判断与 ASS 厘秒输出对齐。

新增回归包含原生相似判断、拼音、合并窗口、代表文本、密度清空、放大/缩小和 16 号下限；
并提取生产脚本生成 ASS，检查顶部矩形不重叠、左右补位、溢出、到期复用、
滚动间距及混合字号轨道占用；另覆盖顶部与滚动容量独立、常规顶部区域满后左右补位、优先选择下方空白而非上方滚动占用区域、
高密度但空间足够时全部保留，以及滚动/顶部/底部空间冲突时优先保留稍晚发送的合并弹幕：

```powershell
python Native/BilibiliRegex/tests/verify_integration.py --sdk D:/src/angelscript --benchmark
```

生成的 ASS 在 `build/integration/layout-*.ass`。耗时来自官方 SDK 模拟宿主，不包含网络，
也不等同于 PotPlayer 实际播放耗时。

顶部补位优化：每条相关弹幕的共同显示区间只计算一次运动覆盖范围，按纵坐标排序一次，
各候选横坐标直接复用顺序扫描空位，避免逐横坐标重复计算轨迹、分配数组和排序。
对所有横坐标都构成阻挡的弹幕先计算空位下界；若已占满可用高度则直接保留合法的
顶部补位坐标。碰撞边界、
容量优选和无空白时允许与滚动弹幕重叠的规则均保持不变。

保存优化前 DLL 后，可对随机宽度、混合字号、顶部密集、同一时间、狭小区域和
合并优先顺序逐条对比初始布局及最终补位坐标，并分别计时：

```powershell
python Native/BilibiliRegex/tests/verify_layout_optimization.py --reference PATH_TO_PREVIOUS_DLL
```

本地模拟宿主的 10000 条混合弹幕用例，总耗时由约 1016 ms 降至 187 ms；
独立原生随机混合用例的补位耗时由约 1089 ms 降至 14 ms，逐条坐标与优化前一致。
这些数字用于对照算法开销，不代表播放器实际耗时。

相似合并进一步增加保守预筛：字符和拼音使用 256 位存在位图，其异或位数是词频 L1
距离的下界；二元词频使用公共桶数和最大桶计数给出点积上界。不可能达到阈值时才
跳过精确比较。散列碰撞只会放宽筛选，不会遗漏匹配；短文本阈值、无公共字符时的
余弦限制、窗口到期和最早匹配组规则均保持不变。仍按活跃窗口原顺序遍历，最坏复杂度
不变，但大量不同文本无需反复扫描完整词频向量。位数统计不依赖 CPU 的 POPCNT 指令。

顶部补位将运动覆盖范围转换为整数候选 X 的精确阻挡区间，对相同纵向范围取区间并集，
减少各候选位置重复扫描同一轨道。候选 X 按离画面水平中央的距离排序，原有边界相等时可
贴边、无空白时保留合法顶部位置的规则不变。统一行高的密集场景收益较大；混合字号
基准可能略慢，不能把单项补位加速比例当作全部布局或播放器打开速度的加速比例。

保存优化前 DLL 后，可逐条比较组号、代表文本以及布局坐标，并取三次计时中位数：

```powershell
python Native/BilibiliRegex/tests/verify_merge_optimization.py --reference PATH_TO_PREVIOUS_DLL --rounds 3
python Native/BilibiliRegex/tests/verify_layout_optimization.py --reference PATH_TO_PREVIOUS_DLL --rounds 3
```

合并测试还可添加 `--segments PATH_TO_FIXTURE_FOLDER`，读取按段号保存的 `segment-*.bin`
Protobuf 数据；普通运行不联网。测试覆盖完全重复、大量不同文本、混合窗口、Unicode、
长短文本、归一化、组首计时以及 modulo-1007 二元词频碰撞。布局对照增加固定行高
密集场景和 200 组随机边界/优先级用例。

靠中央补位只检查居中点、屏幕边界和碰撞边界，不逐像素扫描；候选像素用位图去重，
最多 1921 个。常规居中行仍有空位时，不生成或排序补位候选；初始布局复用纵向区间
排序结果，避免逐横坐标重复排序和轨迹计算；最终补位继续复用运动覆盖区间并集及
全宽阻挡下界，找到最近的合法空位即停止。
顶部无空位缓存和没有全局空白时保留原合法位置的规则保持不变。

切换补位策略会改变部分坐标及后续可容纳数量，不能再要求与旧策略逐条坐标相等。
以下测试用独立的逐像素穷举验证最近空位、奇偶宽度、不同高度、乱序时间、滚动避让及
无空白回退，并可与切换前的 DLL 对比三次耗时中位数：

```powershell
python Native/BilibiliRegex/tests/verify_center_priority.py --reference PATH_TO_PREVIOUS_DLL --rounds 3
```

`verify_layout_optimization.py` 的严格坐标对照适用于相同补位策略下的性能优化。

本机原生对照中，73,250 条混合弹幕的合并中位数由 3563 ms 降至 348 ms，8000 条
不同文本同刻发送由 5154 ms 降至 437 ms；同一视频接口返回的 6870 条公开样本由
77 ms 降至 21 ms。10000 条固定行高密集弹幕的补位由 394 ms 降至 77 ms。
组号、代表文本和最终坐标逐条一致；另在模拟宿主中使用两个 DLL 分别生成 26 份 ASS，
包括 73,250 条大样本及公开视频样本，输出逐字节一致。公开样本与登录态的弹幕数量
可能不同，这些数字不代表实机日志中 70,773 条弹幕的实际耗时。

`Danmaku.cpp` 的算法改编和 `vendor/pakku/pinyin_dict.txt` 采用 GPLv3，来源记录在
`vendor/pakku/UPSTREAM.json`，许可证在 `vendor/pakku/LICENSE`。包含该模块的 DLL 按
GPLv3 分发，完整许可说明随成品放在 `Extension/Lib/BilibiliRegex.LICENSE.txt`；
下述 MIT 许可仅指原来的正则包装源码，不表示整个链接后的 DLL 仍采用 MIT 许可。

QuickJS-NG **v0.17.0**，提交 `6d46d07d04041b40f4f49eaa7fdebe44c314c699`。
仅复制所需源码，未修改 vendor 文件；校验值记录于 `vendor/quickjs-ng/UPSTREAM.json`。

封装、构建和测试代码采用本目录 LICENSE 中的 MIT 许可证；上游许可证在
`vendor/quickjs-ng/LICENSE`。分发 DLL 时保留 `Extension/Lib/BilibiliRegex.LICENSE.txt`。
