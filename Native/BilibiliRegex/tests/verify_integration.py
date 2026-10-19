"""Run the actual playback integration in the official AngelScript runtime.

Requires Visual Studio, Python, and an extracted AngelScript SDK (not vendored).
python tests/verify_integration.py --sdk C:/path/to/sdk [--log diagnostic-log.txt]
Host* functions are test stand-ins calling the real DLL; this is not PotPlayer.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
from verify_metadata import metadata_script, verify_chat_scripts

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]

PREFIX = r'''
class TestConfig {
    bool debug = true;
    bool queryPlayPosition = false;
    bool danmakuBlockRepeatedUser = false; bool danmakuMergeSame = false;
    int danmakuFontEffect = 0;
    bool danmakuBlockTop = true, danmakuBlockBottom = false, danmakuBlockColor = false;
    string danmakuShadowDepth = "1", danmakuOutlineWidth = "1", danmakuBlurRadius = "1";
}
TestConfig ConfigData;
funcdef void ThreadFunction(any@);
int failAfter = -1, launches = 0;
int HostCreateThread(ThreadFunction@ callback, dictionary@ task) {
    if (failAfter >= 0 && launches >= failAfter) return -1;
    launches++;
    any args(@task);
    callback(args);
    return launches;
}
bool HostWaitThread(int id, int ms) { return true; }
string segmentPayload;
string apiPost(const string &in path, bool auth, bool cache) { return segmentPayload; }
string encWbi(const string &in param) { return param; }
'''

FILTER_SIGNATURE = r'''
array<uint8> Filter(const array<string> &in input, const array<string> &in hashes,
                   const array<int> &in types, const array<string> &in filters) {
    string aid = "TEST_AID", cid = "TEST_CID";
    array<uint> times(input.length(), 360001);
    array<uint64> order(input.length());
    for (uint i = 0; i < order.length(); i++) order[i] = i;
    array<string> contents = input, midHashes = hashes;
    array<int> blockRuleTypes = types;
    array<string> blockRuleFilters = filters;
'''

TESTS = r'''
    return blockedFlags;
}
void CheckFilter(uint count, int launchFailure) {
    SetHostFault(0); failAfter = launchFailure; launches = 0;
    array<string> text(count), hashes(count, "ok");
    for (uint i = 0; i < count; i++) {
        if (i % 4 == 0) text[i] = "hello";
        if (i % 4 == 1) text[i] = "拜年";
        if (i % 4 == 2) text[i] = "关键词";
        if (i % 4 == 3) { text[i] = "ignored"; hashes[i] = "banned"; }
    }
    array<int> types = {1, 0, 1, 2};
    array<string> rules = {".*拜年.*", "关键词", "[", "banned"};
    array<uint8> flags = Filter(text, hashes, types, rules);
    Assert(flags.length() == count, "filter completed");
    for (uint i = 0; i < count; i++) Assert(flags[i] == (i % 4 == 0 ? 0 : 1), "filter result");
    Assert(ActiveLibraries() == 0 && ActiveHandles() == 0, "all resources released after tasks");
    Assert(CompilationCount() == 2 && ReleaseCount() == 1, "rules compiled once, valid handle freed once");
    Assert(rules[0] == ".*拜年.*" && rules[2] == "[", "original rules preserved");
    Assert(LogContains("phase=compile regex_index=2 code=-2"), "invalid rule diagnostic uses log");
    Assert(!LogContains("[DanmakuRegexDll]") && !LogContains("filtering_complete"), "no temporary success logs");
}
void CheckFailure(int failure, int launchFailure) {
    SetHostFault(failure); failAfter = launchFailure; launches = 0;
    array<string> text = {"hello"}, hashes = {"ok"}, rules = {"foo"};
    array<int> types = {1};
    array<uint8> flags = Filter(text, hashes, types, rules);
    Assert(flags.empty(), "failure cannot produce an apparently valid filter result");
    Assert(LogContains("[DanmakuRegexDllError]"), "failure is reported");
    Assert(!LogContains("[Danmaku]"), "no false success diagnostic");
    Assert(ActiveLibraries() == 0 && ActiveHandles() == 0, "failure resources released");
}
void Run() {
    CheckFilter(8, -1);
    CheckFilter(8192, -1);
    CheckFilter(8, 0);
    CheckFilter(8192, 1);
    for (int i = 1; i <= 7; i++) CheckFailure(i, -1);
    CheckFailure(4, 0);
    CheckFailure(5, 0);
    SetHostFault(0); failAfter = -1; launches = 0;
    {
        array<string> text = {"FOO", "foo", "FOO", "foo"}, hashes(4, "ok");
        array<string> rules = {"/foo/ig"}; array<int> types = {1};
        array<uint8> flags = Filter(text, hashes, types, rules);
        for (uint i = 0; i < flags.length(); i++) Assert(flags[i] == 1, "official slash flags and fresh lastIndex");
    }
    SetHostFault(1); launches = 0;
    {
        array<string> text = {"关键词"}, hashes = {"ok"}, rules = {"关键词"};
        array<int> types = {0};
        Assert(Filter(text, hashes, types, rules)[0] == 1, "keyword-only filtering needs no DLL");
        Assert(!LogContains("[DanmakuRegexDllError]"), "no DLL loading for keyword-only filtering");
        array<string> empty;
        array<int> regexType = {1};
        Assert(Filter(empty, empty, regexType, rules).empty(), "empty danmaku needs no DLL");
    }
    SetHostFault(0);
    {
        array<string> text = {"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa!"};
        array<string> hashes = {"ok"}, rules = {"^z", "(a+)+$"}; array<int> types = {1, 1};
        Assert(Filter(text, hashes, types, rules).empty(), "real rule-set timeout aborts generation");
        Assert(LogContains("regex_index=2") && LogContains("pattern=(a+)+$"), "failing set slot reported in script");
        Assert(ActiveLibraries() == 0 && ActiveHandles() == 0, "real timeout resources released");
    }
    SetHostFault(0);
    CheckActualLogCases();
    CheckRender();
    CheckSort();
    CheckSegmentPipeline();
    SetHostFault(0); ConfigData.debug = false;
    {
        array<string> text = {"hello"}, hashes = {"ok"}, rules = {"foo"}; array<int> types = {1};
        Assert(Filter(text, hashes, types, rules).length() == 1, "debug off preserves filtering");
        Assert(Render().findFirst("hello(2)") >= 0, "debug off preserves ASS output");
        Assert(LogCount() == 0, "debug off emits no danmaku logs");
        SetHostFault(1);
        Assert(Filter(text, hashes, types, rules).empty(), "debug off still reports failure to caller");
        Assert(LogCount() == 0, "error logs also respect debug setting");
    }
    ConfigData.debug = true; SetHostFault(0);
    Assert(ActiveLibraries() == 0 && ActiveHandles() == 0, "final resources released");
}
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sdk", type=Path, required=True)
    parser.add_argument("--log", type=Path)
    parser.add_argument("--benchmark", action="store_true")
    parser.add_argument("--baseline-script", type=Path, help="Benchmark the segment pipeline against a compatible saved script")
    parser.add_argument("--render-baseline", type=Path, help="Byte-compare and benchmark ASS rendering against a saved script")
    args = parser.parse_args()
    sdk = args.sdk.resolve()
    assert (sdk / "angelscript/include/angelscript.h").exists()
    source = (REPO / "Extension/Media/PlayParse/MediaPlayParse - Bilibili.as").read_text(encoding="utf-8-sig")
    logger = source[source.index('void log(string item) {'):source.index('void log(string item, string info) {')]
    engine_class = source[source.index("class DanmakuRegexDll {"):source.index("string BuildDanmakuAss(")]
    stage = source[source.index('    string regexContext = "aid="'):source.index("    uint mergeWindowMs =")]
    stage = stage.replace('return "";', 'return array<uint8>();')
    actual = ["void CheckActualLogCases() {"]
    entries = []
    if args.log:
        entries = re.findall(r"pattern_begin\n(.*?)\npattern_end\ncontent_begin\n(.*?)\ncontent_end",
                             args.log.read_text(encoding="utf-8-sig"), re.S)
        assert entries
    for pattern, text in entries:
        actual.append('{ array<string> text = {' + json.dumps(text, ensure_ascii=False) +
                      '}, hashes = {"ok"}, rules = {' + json.dumps(pattern, ensure_ascii=False) +
                      '}; array<int> types={1}; Assert(Filter(text, hashes, types, rules)[0]==0,"actual failing comment is safely not matched"); }')
    actual.append("}")
    # AngelScript resolves functions independent of source order.
    # Compile and execute the actual merge/ASS code and final summary log too.
    render = source[source.index("    uint mergeWindowMs ="):source.index("string getFixedURL(")]
    render_fixture = r'''
string Render() {
    string aid = "TEST_AID", cid = "TEST_CID", hex = "0123456789ABCDEF";
    uint totalStart = HostGetTickCount(), heartbeat = totalStart;
    bool processExtra = true, processRepeatedUser = false, processMerge = true;
    uint lanes = 3, laneHeight = 28; int fontSize = 24;
    double stay = 15;
    string font = "TestFont", boldEffect = "", alphaHex = "00", ass = "[Events]\r\n";
    array<uint> times = {1000, 1100, 1200, 1300}, modes = {1, 1, 5, 4}, colors(4, 0xFFFFFF);
    array<uint64> order = {0, 1, 2, 3};
    array<string> contents = {"hello", "hello", "top", "bottom"}, midHashes(4, "ok");
    array<uint8> blockedFlags(4, 0);
    array<uint> renderIndices, mergeCounts;
    dictionary seenUser, mergeGroup;
    array<uint> scrollStart(lanes, 0), reverseStart(lanes, 0), topReady(lanes, 0), bottomReady(lanes, 0);
    array<double> scrollEntryDelay(lanes, 0), reverseEntryDelay(lanes, 0);
    array<bool> scrollUsed(lanes, false), reverseUsed(lanes, false);
'''
    render_checks = r'''
void CheckRender() {
    SetHostFault(0);
    string ass = Render();
    Assert(ass.findFirst("hello(2)") >= 0 && ass.findFirst("top") >= 0 && ass.findFirst("bottom") >= 0,
           "actual merge and render pipeline");
    Assert(LogCount() == 1 && LogContains("[Danmaku]") && LogContains("rendered=3") &&
           LogContains("total_ms=") && LogContains("render_ms="),
           "one summary line through the actual log helper");
}
'''
    sort_checks = r'''
void CheckSort() {
    uint state = 1743;
    for (uint n = 0; n <= 513; n++) {
        array<uint64> input(n);
        for (uint i = 0; i < n; i++) {
            state = state * 1664525 + 1013904223;
            input[i] = (uint64(state % 31) << 32) | uint64(i);
        }
        if (n > 1) { input[0] = uint64(0xFFFFFFFF) << 32; input[1] = uint64(1) << 63; }
        if (n > 3) input[3] = input[2];
        array<uint64> expected = input;
        expected.sortAsc();
        SortDanmakuOrder(input);
        Assert(input == expected, "merge sort equals original uint64 order, odd/even passes, duplicate timestamps and keys");
        SortDanmakuOrder(input);
        Assert(input == expected, "already sorted array");
        input.reverse();
        SortDanmakuOrder(input);
        Assert(input == expected, "reverse sorted array");
    }
}
void BenchmarkSort() {
    const uint count = 73252;
    array<uint64> original(count);
    uint state = 1743;
    for (uint i = 0; i < count; i++) {
        state = state * 1664525 + 1013904223;
        uint progress = (i / 14651) * 360000 + state % 360000;
        original[i] = (uint64(progress) << 32) | uint64(i);
    }
    array<uint64> expected = original, actual = original;
    uint started = HostGetTickCount();
    expected.sortAsc();
    uint oldMs = HostGetTickCount() - started;
    started = HostGetTickCount();
    SortDanmakuOrder(actual);
    uint newMs = HostGetTickCount() - started;
    Assert(actual == expected, "large segmented sort preserves all keys and tie order");
    HostPrintUTF8("[benchmark] sort_comments=" + count + " old_sort_ms=" + oldMs + " merge_sort_ms=" + newMs);
}
'''
    # Execute the actual segment download/decode/collect loop with an in-memory
    # protobuf response; no network or PotPlayer runtime is involved.
    def varint(value):
        result = bytearray()
        while value >= 128:
            result.append((value & 127) | 128)
            value >>= 7
        result.append(value)
        return bytes(result)

    def message(progress, mode, content):
        text = content.encode()
        body = (b'\x08' + varint(987654321012345) + b'\x10' + varint(progress) + b'\x18' + varint(mode) +
                b'\x20\x19\x28' + varint(0xFFFFFF) + b'\x32\x02ok\x3a' + varint(len(text)) + text +
                b'\x40' + varint(1743000000) + b'\x48\x0a\x52\x04flag\x58\x03')
        return b'\x0a' + varint(len(body)) + body

    payload = message(3000, 4, "bottom") + message(1000, 1, "hello😀") + message(2000, 5, "blocked top")
    pipeline = source[source.index("    uint totalSegments = (duration - 1)"):source.index("    if (cloudThread >= 0) {")]
    pipeline = pipeline.replace('return "";', '{ Assert(false, "segment pipeline aborted"); return; }')
    sorting = source[source.index("    if (order.length() > 10000) HostIncTimeOut(10000);"):source.index('    string regexContext = "aid="')]
    pipeline_check = r'''
void CheckSegmentPipeline() {
    SetHostFault(0); failAfter = -1; launches = 0;
    string aid = "TEST_AID", cid = "TEST_CID";
    uint totalStart = HostGetTickCount(), duration = 1800000;
    array<uint> times, modes, colors;
    array<string> contents, midHashes;
    array<uint64> order;
'''
    pipeline_check += '    segmentPayload = "' + ''.join(f'\\x{b:02x}' for b in payload) + '";\n'
    pipeline_check += pipeline + sorting + r'''
    Assert(times.length() == 10 && order.length() == 10, "all five decoded segments collected");
    for (uint i = 0; i < order.length(); i++) {
        uint index = uint(order[i] & 0xFFFFFFFF);
        Assert(times[index] == (i < 5 ? 1000 : 3000), "sort decoded timestamps and preserve fields");
        Assert(contents[index] == (i < 5 ? "hello😀" : "bottom"), "UTF-8 text preserved through collection");
        Assert(modes[index] == (i < 5 ? 1 : 4) && colors[index] == 0xFFFFFF && midHashes[index] == "ok",
               "parallel arrays remain aligned through collection");
        if (i > 0) Assert(order[i - 1] < order[i], "full time/index key order");
    }
    Assert(LogCount() == 0, "segment loop emits no temporary diagnostic logs");
}
'''
    script = (PREFIX + logger + engine_class + FILTER_SIGNATURE + stage + TESTS + "\n".join(actual) +
              render_fixture + render + render_checks + sort_checks + pipeline_check)
    if args.render_baseline:
        original = args.render_baseline.read_text(encoding="utf-8-sig")
        render_case = r'''
string RenderCaseLABEL(uint count, uint scenario, int effect, bool measure) {
    ConfigData.danmakuFontEffect = effect;
    bool processExtra = (scenario & 1) == 0, processMerge = (scenario & 2) == 0;
    uint lanes = scenario == 3 ? 1 : (scenario == 4 ? 216 : (scenario == 1 ? 10 : 30));
    uint laneHeight = scenario == 4 ? 5 : (scenario == 1 ? 79 : 28);
    int fontSize = scenario == 4 ? 1 : (scenario == 1 ? 75 : 24);
    double stay = scenario == 5 ? 0.001 : 15.0;
    string hex = "0123456789ABCDEF", font = "微软雅黑 Light", boldEffect = "\\b1", alphaHex = "1A";
    string ass = "[Events]\r\n";
    array<uint> times(count), modes(count), colors(count), renderIndices(count), mergeCounts(count, 1);
    array<uint64> order(count);
    array<string> contents(count);
    array<string> samples = {"这段剧情接下来会怎样呢", "中文 English 😀", "abc{def}\\ghi\r\njkl", "", "hello", "\x00text"};
    string longText, cacheBoundary;
    for (uint i = 0; i < 300; i++) longText += "中";
    for (uint i = 0; i < 128; i++) cacheBoundary += "中";
    for (uint i = 0; i < count; i++) {
        times[i] = 1000 + (i / 3) * 53 + i % 3;
        if (scenario == 2 && i % 7 == 0) times[i] = 0xFFFFFFFA + i % 6;
        modes[i] = i % 31 == 0 ? 6 : (i % 37 == 0 ? 5 : (i % 41 == 0 ? 4 : 1));
        colors[i] = i % 5 == 0 ? (i * 7919) & 0xFFFFFF : 0xFFFFFF;
        contents[i] = samples[i % samples.length()];
        if (scenario == 0 && contents[i].empty()) contents[i] = "弹幕内容";
        if (scenario > 0 && i % 17 == 0) contents[i] = longText;
        if (scenario > 0 && i % 19 == 0) contents[i] = cacheBoundary;
        if (scenario > 0 && i % 23 == 0) contents[i] = cacheBoundary + "中";
        if (i % 13 == 0) mergeCounts[i] = i % 999 + 2;
        renderIndices[i] = scenario == 2 ? count - i - 1 : i;
        order[i] = (uint64(times[i]) << 32) | uint64(i);
    }
    array<uint> scrollStart(lanes, 0), reverseStart(lanes, 0), topReady(lanes, 0), bottomReady(lanes, 0);
    array<double> scrollEntryDelay(lanes, 0), reverseEntryDelay(lanes, 0);
    array<bool> scrollUsed(lanes, false), reverseUsed(lanes, false);
    uint heartbeat = HostGetTickCount(), started = heartbeat;
'''
        for label, text in [('Old', original), ('New', source)]:
            start = text.index('    uint renderLength = processExtra ?')
            end = text.index('    ass += chunk;', start) + len('    ass += chunk;')
            block = text[start:end] + '\n'
            script += render_case.replace('LABEL', label) + block
            script += '    if (measure) HostPrintUTF8("[benchmark] render=' + label + ' comments=" + count + " render_ms=" + (HostGetTickCount() - started) + " ass_bytes=" + ass.length());\n'
            script += '    return ass;\n}\n'
        script += r'''
void CheckRenderBaseline() {
    ConfigData.debug = false;
    for (uint scenario = 0; scenario < 6; scenario++) {
        for (int effect = 0; effect <= 4; effect++) {
            uint count = scenario == 0 ? 0 : 513;
            Assert(RenderCaseOld(count, scenario, effect, false) == RenderCaseNew(count, scenario, effect, false),
                   "ASS bytes equal: all modes/effects, density, UTF-8, escapes, NUL, long/empty text, merge suffix, time wrap");
        }
    }
    Assert(RenderCaseOld(1, 0, 2, false) == RenderCaseNew(1, 0, 2, false), "single comment ASS bytes equal");
    string expected = RenderCaseOld(63286, 0, 2, true);
    string actual = RenderCaseNew(63286, 0, 2, true);
    Assert(actual == expected, "63286 comments ASS output is byte-identical");
    HostPrintUTF8("[benchmark] ASS byte comparison PASS");
    ConfigData.danmakuFontEffect = 0; ConfigData.debug = true;
}
'''
        script = script.replace('    CheckRender();', '    CheckRender();\n    CheckRenderBaseline();')
    if args.baseline_script:
        old_source = args.baseline_script.read_text(encoding="utf-8-sig")
        if '    uint totalSegments = (duration - 1)' not in old_source or '    if (cloudThread >= 0) {' not in old_source:
            parser.error("--baseline-script requires a compatible playback script with the segment pipeline")
        # A complete 14,650-comment segment includes fields normally discarded
        # by the renderer. Both pipelines process identical bytes synchronously.
        benchmark_message = (b'\x08' + varint(987654321012345) + b'\x10' + varint(300001) +
                             b'\x18\x01\x20\x19\x28' + varint(0xFFFFFF) + b'\x32\x08deadbeef' +
                             b'\x3a' + varint(len('这段剧情接下来会怎样呢'.encode())) + '这段剧情接下来会怎样呢'.encode() +
                             b'\x40' + varint(1743000000) + b'\x48\x0a\x52\x0f987654321012345\x58\x03')
        benchmark_bytes = (b'\x0a' + varint(len(benchmark_message)) + benchmark_message) * 14650
        fixture = ROOT / 'build/integration/decode-fixture.bin'
        fixture.parent.mkdir(parents=True, exist_ok=True)
        fixture.write_bytes(benchmark_bytes)
        for label, text in [('Old', old_source), ('New', source)]:
            loop = text[text.index('    uint totalSegments = (duration - 1)'):text.index('    if (cloudThread >= 0) {')]
            loop = loop.replace('return "";', '{ Assert(false, "benchmark segment aborted"); return; }')
            script += '\nvoid BenchmarkPipeline' + label + '() {\n'
            script += '    SetHostFault(0); failAfter = -1; launches = 0;\n'
            script += '    segmentPayload = ReadTestFile(' + json.dumps(str(fixture), ensure_ascii=False) + ');\n'
            script += '''    string aid="TEST_AID", cid="TEST_CID"; uint duration=1800000;
    array<uint> times, modes, colors; array<string> contents, midHashes; array<uint64> order;
    uint started = HostGetTickCount();
'''
            script += loop
            script += '    uint elapsed = HostGetTickCount() - started;\n'
            script += '''    Assert(order.length() == 73250 && contents.length() == 73250, "benchmark segment count");
    for (uint i = 0; i < order.length(); i++) Assert(times[i] == 300001 && modes[i] == 1 &&
        colors[i] == 0xFFFFFF && midHashes[i] == "deadbeef" && contents[i] == "这段剧情接下来会怎样呢" &&
        order[i] == ((uint64(300001) << 32) | uint64(i)), "benchmark all decoded/collected fields");
'''
            script += '    HostPrintUTF8("[benchmark] pipeline=' + label + ' comments=73250 total_ms=" + elapsed);\n}\n'
    if args.benchmark:
        script = script.replace("void Run() {", "void RunRegression() {") + r'''
void Run() {
    BenchmarkSort();
    SetHostFault(0); failAfter = -1; launches = 0;
    const uint count = 73250;
    array<string> text(count, "这段剧情接下来会怎样呢"), hashes(count, "ok");
    array<string> rules = {".*拜年.*", ".*新年.*", ".*元旦.*", ".*2017.*", ".*鬼看条.*",
        ".*进度条.*", ".*大学.*", ".*下雪.*", ".*分钟前", "关上.*的大门", "前[0-9]*$"};
    array<int> types(rules.length(), 1);
    uint started = HostGetTickCount();
    array<uint8> flags = Filter(text, hashes, types, rules);
    uint elapsed = HostGetTickCount() - started;
    Assert(flags.length() == count, "benchmark completed");
    for (uint i = 0; i < flags.length(); i++) Assert(flags[i] == 0, "benchmark results preserved");
    Assert(ActiveLibraries() == 0 && ActiveHandles() == 0, "benchmark resources released");
    HostPrintUTF8("[benchmark] comments=" + count + " rules=" + rules.length() +
        " filter_ms=" + elapsed + " native_test_calls=" + TestCallCount());
}
'''
        if args.baseline_script:
            script = script.replace('    BenchmarkSort();', '    BenchmarkPipelineOld();\n    BenchmarkPipelineNew();\n    BenchmarkSort();')
        if args.render_baseline:
            script = script.replace('    BenchmarkSort();', '    CheckRenderBaseline();\n    BenchmarkSort();')
    output = ROOT / "build/integration"
    output.mkdir(parents=True, exist_ok=True)
    script += metadata_script(REPO)
    script = script.replace("void Run() {", "void Run() { CheckMetadata();", 1)
    script_path = output / "playback-extract.as"
    script_path.write_text(script, encoding="utf-8")
    vswhere = Path(os.environ["ProgramFiles(x86)"]) / "Microsoft Visual Studio/Installer/vswhere.exe"
    install = subprocess.check_output([str(vswhere), "-latest", "-products", "*", "-requires",
                                      "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "-property", "installationPath"], text=True).strip()
    include_paths = [sdk / "angelscript/include"] + [sdk / "add_on" / x for x in
                    ["scriptstdstring", "scriptarray", "scriptdictionary", "scriptany"]]
    includes = " ".join('/I "' + str(x) + '"' for x in include_paths)
    sources = [str(sdk / "angelscript/source/*.cpp")] + [str(sdk / "add_on" / x / (x + ".cpp")) for x in
               ["scriptstdstring", "scriptarray", "scriptdictionary", "scriptany"]]
    sources.append(str(ROOT / "tests/integration_runner.cpp"))
    sources.append(str(sdk / "add_on/scriptstdstring/scriptstdstring_utils.cpp"))
    executable = output / "integration.exe"
    command = ('@echo off\ncall "' + str(Path(install) / "VC/Auxiliary/Build/vcvars64.bat") + '" >nul\n'
               'cl /nologo /MP /EHsc /std:c++17 /O2 /utf-8 /DAS_MAX_PORTABILITY /DAS_USE_STLNAMES=1 ' +
               includes + " " + " ".join('"' + x + '"' for x in sources) + ' /Fe:"' + str(executable) + '"\n'
               'exit /b %errorlevel%\n')
    build = output / "build.cmd"
    build.write_text(command, encoding="utf-8")
    built = subprocess.run([str(build)], cwd=output, capture_output=True, text=True, errors="replace")
    (output / "build.log").write_text(built.stdout + built.stderr, encoding="utf-8")
    if built.returncode:
        print(built.stdout, built.stderr)
        raise SystemExit(built.returncode)
    tested = subprocess.run([str(executable), str(script_path), str(REPO)], capture_output=True, text=True, encoding="utf-8", timeout=90)
    print(tested.stdout, end="")
    if tested.returncode:
        print(tested.stderr)
        raise SystemExit(tested.returncode)
    print(f"Actual log cases: {len(entries)}; PotPlayer Host* implementations still need manual verification.")
    verify_chat_scripts(REPO)


if __name__ == "__main__":
    main()
