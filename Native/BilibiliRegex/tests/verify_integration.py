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
from verify_danmaku import layout_script, verify_ass, verify_native

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]

PREFIX = r'''
class TestConfig {
    bool debug = true;
    bool queryPlayPosition = false;
    bool danmakuBlockRepeatedUser = false; bool danmakuMergeSame = false;
    bool danmakuEnlarge = false, danmakuAutoShrink = false;
    bool danmakuAutoSelect = true;
    int danmakuFontEffect = 0;
    bool danmakuBlockTop = true, danmakuBlockBottom = false, danmakuBlockColor = false;
    float danmakuShadowDepth = 1, danmakuOutlineWidth = 1, danmakuBlurRadius = 1;
}
TestConfig ConfigData;
funcdef void ThreadFunction(any@);
int failAfter = -1, launches = 0;
bool delayFirstSegment = false, timedWaitOnly = false;
int HostCreateThread(ThreadFunction@ callback, dictionary@ task) {
    if (failAfter >= 0 && launches >= failAfter) return -1;
    launches++;
    any args(@task);
    callback(args);
    return launches;
}
bool HostWaitThread(int id, int ms) { return (!timedWaitOnly || ms > 0) && (!delayFirstSegment || id != 1 || launches > 5); }
string segmentPayload;
array<string> segmentPayloads;
string apiPost(const string &in path, bool auth, bool cache) {
    for (uint i = 0; i < segmentPayloads.length(); i++)
        if (path.findFirst("segment_index=" + formatUInt(i + 1) + "&") >= 0) return segmentPayloads[i];
    return segmentPayload;
}
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
    {
        array<string> text = {"foo", "foo", "bar", "bar", "foo"};
        array<string> hashes = {"ok", "banned", "ok", "ok", "ok"};
        array<int> types = {1, 2}; array<string> rules = {"^bar$", "banned"};
        array<uint8> flags = Filter(text, hashes, types, rules);
        Assert(flags.length() == 5 && flags[0] == 0 && flags[1] == 1 && flags[2] == 1 && flags[3] == 1 && flags[4] == 0,
               "cached matching remains independent of sender hashes");
        Assert(TestCallCount() == 2, "repeated positive and negative matches call native once per text");
    }
    SetHostFault(0);
    {
        array<string> text(4100), hashes(4100, "ok"), rules = {"^never$"}; array<int> types = {1};
        failAfter = 0; launches = 0;
        for (uint i = 0; i < 4097; i++) text[i] = "text-" + i;
        text[4097] = "text-0";
        string longText; for (uint i = 0; i < 385; i++) longText += "x";
        text[4098] = longText; text[4099] = longText;
        array<uint8> flags = Filter(text, hashes, types, rules);
        Assert(flags.length() == text.length() && TestCallCount() == 4100, "bounded fallback cache evicts and bypasses long text");
        for (uint i = 0; i < flags.length(); i++) Assert(flags[i] == 0, "cache eviction preserves nonmatches");
        failAfter = -1;
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
    uint fetchMs = 0, cloudMs = 0, sortMs = 0, filterStart = totalStart;
    bool processExtra = true, processRepeatedUser = false, processMerge = true;
    uint lanes = 3, laneHeight = 28; int fontSize = 24;
    double stay = 15;
    double area = 0.8;
    string font = "TestFont", boldEffect = "", alphaHex = "00", ass = "[Events]\r\n";
    array<uint> times = {1000, 1100, 1200, 1300}, modes = {1, 1, 5, 4}, colors(4, 0xFFFFFF);
    array<uint64> order = {0, 1, 2, 3};
    array<string> contents = {"hello", "hello", "top", "bottom"}, midHashes(4, "ok");
    array<uint8> blockedFlags(4, 0);
    array<uint> renderIndices, mergeCounts, mergeWeights, mergeModes;
    array<string> mergeTexts;
    array<uint> weights(4, 1);
    string regexContext = "test";
    DanmakuRegexDll regexDll;
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
           LogContains("total_ms=") && LogContains("render_ms=") && LogContains("prepare_ms=") &&
            LogContains("merge_ms=") && LogContains("layout_ms=") && LogContains("ass_ms="),
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
    sorting = source[source.index("    uint sortStart = HostGetTickCount();"):source.index('    string regexContext = "aid="')]
    pipeline_check = r'''
void CheckSegmentPipelineCase(bool delayed, bool timed = false) {
    timedWaitOnly = timed; delayFirstSegment = delayed; segmentPayloads.resize(0);
    SetHostFault(0); failAfter = -1; launches = 0;
    string aid = "TEST_AID", cid = "TEST_CID";
    uint totalStart = HostGetTickCount(), duration = delayed ? 2160000 : 1800000;
    array<uint> times, modes, colors, weights;
    array<string> contents, midHashes;
    array<uint64> order;
'''
    pipeline_check += '    segmentPayload = "' + ''.join(f'\\x{b:02x}' for b in payload) + '";\n'
    pipeline_check += '    if (delayed) { segmentPayloads.resize(6);\n'
    for segment in range(1, 7):
        staggered = message(1000, 1, f"segment-{segment}")
        pipeline_check += '        segmentPayloads[' + str(segment - 1) + '] = "' + ''.join(f'\\x{b:02x}' for b in staggered) + '";\n'
    pipeline_check += '    }\n'
    pipeline_check += pipeline + sorting + r'''
    if (delayed) {
        Assert(order.length() == 6 && launches == 6, "slow first segment does not block sixth launch");
        for (uint i = 0; i < 6; i++) {
            Assert(contents[i] == "segment-" + formatUInt(i + 1), "out-of-order completion preserves segment order");
            Assert(uint(order[i]) == i, "same-time keys retain original segment order");
        }
        delayFirstSegment = false; segmentPayloads.resize(0); return;
    }
    Assert(times.length() == 10 && order.length() == 10, "all five decoded segments collected");
    for (uint i = 0; i < order.length(); i++) {
        uint index = uint(order[i] & 0xFFFFFFFF);
        Assert(times[index] == (i < 5 ? 1000 : 3000), "sort decoded timestamps and preserve fields");
        Assert(contents[index] == (i < 5 ? "hello😀" : "bottom"), "UTF-8 text preserved through collection");
        Assert(modes[index] == (i < 5 ? 1 : 4) && colors[index] == 0xFFFFFF && midHashes[index] == "ok",
               "parallel arrays remain aligned through collection");
        Assert(weights[index] == 10, "protobuf weight survives segment collection for automatic preference");
        if (i > 0) Assert(order[i - 1] < order[i], "full time/index key order");
    }
    Assert(LogCount() == 0, "segment loop emits no temporary diagnostic logs");
    timedWaitOnly = false;
}
'''
    pipeline_check += "\nvoid CheckSegmentPipeline() { CheckSegmentPipelineCase(false); CheckSegmentPipelineCase(true); CheckSegmentPipelineCase(false, true); }\n"
    script = (PREFIX + logger + engine_class + FILTER_SIGNATURE + stage + TESTS + "\n".join(actual) +
              render_fixture + render + render_checks + sort_checks + pipeline_check + layout_script(source, render))
    script = script.replace('    CheckRender();', '    CheckRender();\n    CheckLayout();', 1)
    if args.render_baseline:
        original = args.render_baseline.read_text(encoding="utf-8-sig")
        if "BiliDanmakuPlace" not in original:
            parser.error("ASS selection intentionally differs; use geometric regression, or supply a capacity-layout baseline")
        previous_render = original[original.index("    uint mergeWindowMs ="):original.index("string getFixedURL(")]
        previous_sort = original[original.index("void SortDanmakuOrder("):original.index("string BuildDanmakuAss(")]
        previous_sort = previous_sort.replace("SortDanmakuOrder(", "SortDanmakuOrderBaseline(")
        previous = previous_sort + layout_script(original, previous_render).replace("SortDanmakuOrder(", "SortDanmakuOrderBaseline(")
        previous = previous.replace("LayoutCase(", "LayoutCaseBaseline(").replace("CheckLayout()", "CheckLayoutBaseline()").replace("BenchmarkLayout()", "BenchmarkLayoutBaseline()")
        script += previous + r'''
void CheckRenderBaseline() {
    for(uint scenario=0;scenario<=14;scenario++) {
        if(scenario==8)continue;
        uint count=scenario>=10?5:(scenario==9?3:(scenario==0?12:(scenario==3?9:(scenario==4||scenario==5?200:(scenario==6?3:2)))));
        SetHostFault(0);string expected=LayoutCaseBaseline(count,scenario);
        SetHostFault(0);string actual=LayoutCase(count,scenario);
        Assert(actual==expected,"post-pakku ASS bytes match saved baseline");
    }
    for(uint scenario=16;scenario<=26;scenario++) {
        if(scenario==17)continue;
        uint count=scenario==16?201:(scenario==18||scenario==23?200:(scenario==22?9:(scenario==24?24:(scenario==25?46:(scenario==26?52:3)))));
        SetHostFault(0);string expected=LayoutCaseBaseline(count,scenario);
        SetHostFault(0);string actual=LayoutCase(count,scenario);
        Assert(actual==expected,"overflow, priority and shrink ASS bytes match saved baseline");
    }
    ConfigData.danmakuFontEffect=0;ConfigData.danmakuAutoShrink=false;ConfigData.danmakuEnlarge=false;SetHostFault(0);
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
    array<uint> times, modes, colors, weights; array<string> contents, midHashes; array<uint64> order;
    uint started = HostGetTickCount(), totalStart = started;
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
    RunRegression();
    BenchmarkSort();
    BenchmarkLayout();
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
            script += r'''
void BenchmarkRenderComparison() {
    for(uint trial=0;trial<3;trial++) {
        SetHostFault(0);uint start=HostGetTickCount();string expected=LayoutCaseBaseline(73250,8);uint middle=HostGetTickCount();
        SetHostFault(0);string actual=LayoutCase(73250,8);uint finished=HostGetTickCount();
        Assert(actual==expected,"large ASS bytes match saved baseline");
        HostPrintUTF8("[benchmark] render_trial="+trial+" comments=73250 old_ms="+(middle-start)+" new_ms="+(finished-middle)+" bytes="+actual.length());
    }
}
'''
            script = script.replace('    BenchmarkSort();', '    BenchmarkRenderComparison();\n    BenchmarkSort();')
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
    verify_native()
    verify_ass()


if __name__ == "__main__":
    main()
