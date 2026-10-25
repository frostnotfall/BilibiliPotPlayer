"""Pakku/native regression and geometric checks of ASS emitted by actual AS code."""
import ctypes as C
from pathlib import Path
import math
import random
import re
import time

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]


def layout_script(source, render):
    header = source[source.index('    string ass =\n'):source.index('    uint totalSegments =')]
    fixture = r'''
string LayoutCase(uint count, uint scenario, bool automaticSelection=true) {
    string aid="TEST", cid="LAYOUT", regexContext="layout", hex="0123456789ABCDEF";
    uint totalStart=HostGetTickCount(), heartbeat=totalStart;
    uint fetchMs=0,cloudMs=0,sortMs=0,filterStart=totalStart;
    bool processExtra=true, processRepeatedUser=false, processMerge=scenario==3||(scenario>=19&&scenario<=22);
    int fontSize=scenario==4?16:(scenario==23?24:32);
    ConfigData.danmakuAutoShrink=scenario==4||scenario==16||scenario==23||scenario==24;
    ConfigData.danmakuEnlarge=scenario==3;
    ConfigData.danmakuAutoSelect=automaticSelection;
    ConfigData.danmakuFontEffect=scenario>=10&&scenario<=14?int(scenario-10):0;
    double area=scenario==0||scenario==6||scenario==16||(scenario>=19&&scenario<=22)?0.034:0.8, stay=15;
    uint laneHeight=1;
    uint lanes=uint(1080*area)/laneHeight;if(lanes==0)lanes=1;
    string font="微软雅黑 Light",boldEffect="",alphaHex="00";
    array<uint> times(count,1000),modes(count,1),colors(count,0xFFFFFF),weights(count,1);
    array<string> contents(count,"测试弹幕"),midHashes(count,"ok");
    array<uint64> order(count);
    for(uint i=0;i<count;i++){
        order[i]=i;
        if(scenario==0){modes[i]=5;contents[i]="顶部固定测试"+i;}
        if(scenario==1){modes[i]=i==0?5:1;contents[i]="允许与滚动交叠";}
        if(scenario==2){contents[i]="abcd";times[i]=i*600;}
        if(scenario==3){contents[i]=i<8?"热门弹幕":"不同内容";}
        if(scenario==4||scenario==5){contents[i]="密集测试弹幕内容内容内容内容";times[i]=i*2;}
        if(scenario==6){modes[i]=5;contents[i]="这是一条占据整行空间而且只能容纳一条的顶部固定测试弹幕内容内容内容内容内容内容内容内容内容内容";times[i]=i==0?1000:(i==1?15994:16000);}
        if(scenario==7){contents[i]="中文测试";times[i]=i*600;}
        if(scenario==8||scenario==27){contents[i]="这段剧情接下来会怎样呢"+i;times[i]=i*25;if(scenario==27&&i%3==0)modes[i]=5;}
        if(scenario==9){modes[i]=5;contents[i]="居中测试";}
        if(scenario>=10&&scenario<=14){
            modes[i]=i==0?6:1;colors[i]=0x123456;
            if(i==1)contents[i]="";
            if(i==2)contents[i]="中文 English 😀{x}\\y\r\nnext";
            if(i==3){contents[i]="";for(uint j=0;j<150;j++)contents[i]+="中";}
            if(i==4)contents[i]="\x00text";
        }
        if(scenario==16){
            modes[i]=i+1<count?5:1;
            contents[i]=i+1<count?"这是一条占据整行空间而且只能容纳一条的顶部固定测试弹幕内容内容内容内容内容内容内容内容内容内容":"最后的滚动弹幕";
        }
        if(scenario==18){contents[i]="a";times[i]=i*20;}
        if(scenario>=19&&scenario<=21){
            times[i]=1000+i*100;contents[i]=i==0?"abcd":"热门";
            if(scenario==20){modes[i]=5;contents[i]="";for(uint j=0;j<64;j++)contents[i]+=i==0?"abcd":"热";}
            if(scenario==21)modes[i]=4;
        }
        if(scenario==22){times[i]=1000+i*100;contents[i]=i<2?"ABCD":"热门";}
        if(scenario==23){contents[i]="像素行距测试弹幕";times[i]=1000;}
        if(scenario==24){modes[i]=i%4==0?5:1;contents[i]="空位优先测试"+i;times[i]=1000;}
        if(scenario==25||scenario==26){modes[i]=i<28?5:1;contents[i]=(i<28?"顶部补位测试":"滚动占位测试")+i;times[i]=1000;}
        if(scenario==28||scenario==29){modes[i]=scenario==28?6:4;contents[i]="空间不足保留全部弹幕";}
    }
    array<uint8> blockedFlags(count,0);
    array<uint> renderIndices,mergeCounts,mergeWeights,mergeModes;
    array<string> mergeTexts;
    dictionary seenUser;
    DanmakuRegexDll regexDll;
    array<uint> scrollStart(lanes,0),reverseStart(lanes,0),bottomReady(lanes,0);
    array<double> scrollEntryDelay(lanes,0),reverseEntryDelay(lanes,0);
    array<bool> scrollUsed(lanes,false),reverseUsed(lanes,false);
'''
    checks = r'''
void CheckLayout() {
    SetHostFault(0);
    Assert(LayoutCase(0,0).findFirst("[Events]")>=0,"empty layout requires no native layout calls");
    for(uint scenario=0;scenario<=14;scenario++){
        if(scenario==8)continue;
        SetHostFault(0);
        uint count=scenario>=10?5:(scenario==9?3:(scenario==0?12:(scenario==3?9:(scenario==4||scenario==5?200:(scenario==6?3:2)))));
        string ass=LayoutCase(count,scenario);
        Assert(!ass.empty(),"layout generated");
        WriteTestAss("layout-"+scenario+".ass",ass);
        Assert(ActiveLibraries()==0&&ActiveHandles()==0,"layout releases native state");
    }
    SetHostFault(0);
    WriteTestAss("layout-16.ass",LayoutCase(201,16));
    for(uint scenario=18;scenario<=22;scenario++){
        WriteTestAss("layout-"+scenario+".ass",LayoutCase(scenario==18?200:(scenario==22?9:3),scenario));
    }
    WriteTestAss("layout-23.ass",LayoutCase(200,23));
    WriteTestAss("layout-24.ass",LayoutCase(24,24));
    WriteTestAss("layout-25.ass",LayoutCase(46,25));
    WriteTestAss("layout-26.ass",LayoutCase(52,26));
    Assert(LayoutCase(0,0,false).findFirst("[Events]")>=0,"empty layout with selection disabled");
    WriteTestAss("selection-off-top.ass",LayoutCase(12,0,false));
    WriteTestAss("selection-off-scroll.ass",LayoutCase(200,5,false));
    WriteTestAss("selection-off-reverse.ass",LayoutCase(200,28,false));
    WriteTestAss("selection-off-bottom.ass",LayoutCase(200,29,false));
    WriteTestAss("selection-off-shrink.ass",LayoutCase(200,4,false));
    WriteTestAss("selection-off-merge.ass",LayoutCase(9,3,false));
    Assert(ActiveLibraries()==0&&ActiveHandles()==0,"final selection releases native state");
    ConfigData.danmakuAutoShrink=false;ConfigData.danmakuEnlarge=false;ConfigData.danmakuAutoSelect=true;SetHostFault(0);
}
void BenchmarkLayout() {
    SetHostFault(0);uint start=HostGetTickCount();
    string ass=LayoutCase(73250,8);
    Assert(!ass.empty(),"large ASS generated");
    HostPrintUTF8("[benchmark] layout_comments=73250 layout_ms="+(HostGetTickCount()-start)+" bytes="+ass.length());
    start=HostGetTickCount();ass=LayoutCase(10000,27);
    Assert(!ass.empty(),"mixed overflow benchmark generated");
    HostPrintUTF8("[benchmark] mixed_layout_comments=10000 layout_ms="+(HostGetTickCount()-start)+" bytes="+ass.length());
}
'''
    # Instrument only the extracted fixture, keeping production logging unchanged.
    render=render.replace('    bool autoSelect = ConfigData.danmakuAutoSelect;', '    uint phaseReady=HostGetTickCount();\n    bool autoSelect = ConfigData.danmakuAutoSelect;')
    render=render.replace('    // 全部容量优选完成后再调整顶部补位坐标', '    uint phasePlaced=HostGetTickCount();\n    // 全部容量优选完成后再调整顶部补位坐标')
    render=render.replace('    string chunk;', '    uint phaseRefined=HostGetTickCount();\n    string chunk;')
    render=render.replace('    return ass;', '    if(scenario==8||scenario==27) HostPrintUTF8("[benchmark] phases scenario="+scenario+" prepare_ms="+(phaseReady-renderStart)+" place_ms="+(phasePlaced-phaseReady)+" refine_ms="+(phaseRefined-phasePlaced)+" ass_ms="+(finished-phaseRefined));\n    return ass;')
    return fixture + header + render + checks


def events(path):
    result = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("Dialogue: 1,"):
            continue
        fields = line.split(",", 9)
        tag, text = fields[9].split("}", 1)
        size = int(re.search(r"\\fs(\d+)", tag)[1])
        position = re.search(r"\\pos\((-?\d+),(-?\d+)\)", tag)
        move = re.search(r"\\move\((-?\d+),(-?\d+),(-?\d+),(-?\d+)\)", tag)
        result.append(dict(size=size, text=text, start=fields[1], end=fields[2], pos=tuple(map(int, position.groups())) if position else None,
                           move=tuple(map(int, move.groups())) if move else None))
    return result


def verify_ass():
    output = ROOT / "build/integration"
    cases = [events(output / f"layout-{i}.ass") for i in range(8)]
    assert 3 <= len(cases[0]) < 12, "top overflow packed into empty horizontal positions, then skipped"
    for i, a in enumerate(cases[0]):
        ax, ay = a["pos"]; aw = len(a["text"]) * a["size"] + 2
        for b in cases[0][i + 1:]:
            bx, by = b["pos"]; bw = len(b["text"]) * b["size"] + 2
            assert abs(ax - bx) >= (aw + bw) / 2 or abs(ay - by) >= a["size"] + 2, "top boxes do not overlap"
    assert cases[1][1]["move"][1]==cases[1][0]["pos"][1]==0, "top and scroll use independent capacity from the first row"
    assert cases[2][0]["move"][1] == cases[2][1]["move"][1], "short ASCII reuses a lane after 600 ms"
    assert cases[7][0]["move"][1] != cases[7][1]["move"][1], "wide text still checks entry/catch-up spacing"
    assert len(cases[3]) == 2 and cases[3][0]["size"] == math.ceil(32 * math.log(8, 5)), "pakku enlargement"
    assert cases[3][1]["move"][1] == cases[3][0]["size"]+4, "mixed sizes retain original four-pixel spacing at the final font size"
    assert cases[4] and all(e["size"] >= 16 for e in cases[4]), "16-point floor"
    assert 0 < len(cases[5]) < 200, "enabled automatic selection removes overflow"
    for name, count in [("top",12),("scroll",200),("reverse",200),("bottom",200),("shrink",200),("merge",2)]:
        retained=events(output / f"selection-off-{name}.ass")
        assert len(retained)==count, (name,"disabled automatic selection keeps all filtered/merged candidates")
        if name=="top":
            assert all(e["pos"]==(960,0) for e in retained), "disabled selection reuses centered top lane on overflow"
        if name=="reverse":
            assert all(e["move"][0]<e["move"][2] for e in retained), "disabled selection keeps reverse scrolling"
        if name=="shrink":
            assert all(e["size"]==16 for e in retained), "automatic shrinking remains independent of selection"
        if name=="merge":
            assert retained[0]["size"]==math.ceil(32*math.log(8,5)) and retained[0]["text"].endswith("(8)"), "merging and enlargement remain independent of selection"
    assert len(cases[6]) == 2 and cases[6][0]["pos"] == cases[6][1]["pos"], "top end time uses ASS centisecond rounding"
    center=events(output / "layout-9.ass")
    assert len(center)==3 and all(e["pos"][0]==960 for e in center)
    assert [e["pos"][1] for e in center]==[0,36,72], "top fills centered rows before searching horizontal gaps"
    for effect in range(5):
        path=output / f"layout-{10+effect}.ass"
        styled=events(path);assert len(styled)==4
        assert styled[0]["move"][0]<styled[0]["move"][2], "reverse scrolling remains supported"
        assert "｛x｝＼y  next" in styled[1]["text"], "ASS escape protection remains intact"
        raw=path.read_text(encoding="utf-8")
        assert "\\1c&H563412&" in raw, "BGR color preserved"
        assert raw.count("Dialogue: 0,")==(4 if effect>=3 else 0), "two-layer effects retained"
    final=events(output / "layout-16.ass")
    assert len(final)==2 and final[0]["pos"] and final[1]["move"], "layout rejects 199 unplaceable top comments before preference"
    assert final[1]["size"]>=16 and final[1]["move"][1]==0, "capacity selection preserves independent scrolling space after size preparation"
    spacious=events(output / "layout-18.ass")
    assert len(spacious)==200, "high density alone must not delete comments while space remains"
    for scenario in range(19,22):
        preferred=events(output / f"layout-{scenario}.ass")
        assert len(preferred)==1 and preferred[0]["text"].endswith("(2)"), "later merged comment wins occupied space over an earlier ordinary comment"
        assert preferred[0]["start"]=="0:00:01.10" and preferred[0]["end"]=="0:00:16.10", "priority never shifts original comment timing"
    most=events(output / "layout-22.ass")
    assert len(most)==1 and most[0]["text"]=="热门(7)", "higher merge count wins between merged groups"
    compact=sorted(events(output / "layout-23.ass"),key=lambda e:e["move"][1])
    assert len(compact)>25 and any(e["size"]<24 for e in compact), "final heights reclaim space lost to the old 34-pixel rounded rows"
    for a,b in zip(compact,compact[1:]):
        assert b["move"][1]==a["move"][1]+a["size"]+4, "shrunk rows retain original four-pixel spacing at their final font sizes"
    mixed=events(output / "layout-24.ass")
    assert len(mixed)==24, "use empty vertical space before dropping mixed comments"
    tops=[e for e in mixed if e["pos"]];moving=[e for e in mixed if e["move"]]
    assert [e["pos"][1] for e in tops]==list(range(0,len(tops)*36,36)), "moving comments never push top comments out of centered rows"
    assert moving[0]["move"][1]==0, "top comments never consume moving capacity"
    assert len({e["pos"] for e in tops})==len(tops), "top comments never overlap one another"
    for scenario,count in [(25,46),(26,52)]:
        refined=events(output / f"layout-{scenario}.ass")
        assert len(refined)==count, "refinement never discards comments already accepted by capacity selection"
        fixed=[e for e in refined if e["pos"]]
        assert [e["pos"][1] for e in fixed[:24]]==list(range(0,864,36)), "normal top region remains independent of moving comments"
        for index,extra in enumerate(fixed[24:]):
            assert extra["pos"][1]==(648 if scenario==25 else 0)+36*index, "center-first overflow stacks in lower clear space, retaining allowed overlap only when no clear space exists"
        assert len({e["pos"][0] for e in fixed[24:]})==1, "overflow uses closer central gaps before spreading toward screen edges"
        for i,a in enumerate(fixed):
            ax,ay=a["pos"];aw=len(a["text"])*a["size"]+2
            for b in fixed[i+1:]:
                bx,by=b["pos"];bw=len(b["text"])*b["size"]+2
                assert abs(ax-bx)>=(aw+bw)/2 or abs(ay-by)>=36, "refinement never overlaps fixed top rectangles"
    print("PASS: actual ASS top packing/overflow/release, scroll gap, mixed font sizes, 16-point floor, automatic selection")


def verify_native():
    dll = C.CDLL(str(REPO / "Extension/Lib/BilibiliRegex.dll"))
    create = dll.BiliDanmakuCreate; create.argtypes = [C.c_uint32]; create.restype = C.c_size_t
    feed = dll.BiliDanmakuFeed; feed.argtypes = [C.c_size_t, C.c_char_p, C.c_uint32, C.c_uint32]; feed.restype = C.c_int
    free = dll.BiliDanmakuFree; free.argtypes = [C.c_size_t]
    text = dll.BiliDanmakuText; text.argtypes = [C.c_size_t, C.c_uint32]; text.restype = C.c_char_p
    select = dll.BiliDanmakuSelect
    select.argtypes = [C.c_size_t, C.c_char_p, C.c_uint32, C.c_uint32, C.c_uint32, C.c_uint32]; select.restype = C.c_int
    prepare=dll.BiliDanmakuPrepare;prepare.argtypes=select.argtypes;prepare.restype=C.c_int
    commit=dll.BiliDanmakuCommit;commit.argtypes=[C.c_size_t];commit.restype=C.c_int
    h=create(30000)
    try:
        raw="布局检查尚未通过的弹幕".encode();packed=32|(1<<12)|(1<<17)
        assert commit(h)==-1
        for _ in range(200):
            assert prepare(h,raw,len(raw),1000,packed,1)==32, "prepare never filters or counts uncommitted layout candidates"
        assert commit(h)==1 and commit(h)==-1, "commit consumes a prepared candidate once"
        assert prepare(h,raw,len(raw),1000,packed,1)>0
        assert prepare(h,b"",0,1000,packed,1)==-1 and commit(h)==-1, "failed prepare clears pending candidate"
        for i in range(300):
            size=prepare(h,raw,len(raw),1000+i,packed,1)
            assert size>=16, "size preparation must complete before final selection"
            decision=commit(h)
            assert decision==1, "density only changes size; it never deletes comments"
    finally:free(h)
    set_weight=dll.BiliDanmakuWeight;set_weight.argtypes=[C.c_size_t,C.c_uint32,C.c_uint32]
    font=dll.BiliDanmakuFont;font.argtypes=[C.c_size_t,C.c_char_p,C.c_uint32,C.c_uint32]
    measure=dll.BiliDanmakuMeasure;measure.argtypes=[C.c_size_t,C.c_char_p,C.c_uint32,C.c_uint32]
    h=create(30000)
    try:
        face="微软雅黑 Light".encode();assert font(h,face,len(face),0)==0
        raw="中文测试".encode();w=measure(h,raw,len(raw),32)
        assert 0<w<4*32 and measure(h,raw,len(raw),32)==w, "ASS font advance and cached reuse"
        assert measure(h,raw,len(raw),48)>w
        assert measure(h,b"\xff",1,32)==-1
    finally:free(h)
    def pair(a, b, expected, gap=1):
        h = create(30000)
        try:
            a, b = a.encode(), b.encode()
            assert feed(h, a, len(a), 0) == 0
            assert feed(h, b, len(b), gap) == expected, (a, b)
        finally: free(h)
    for a,b in [("测试！！", "测试"), ("中文　　弹幕", "中文弹幕"), ("Ｈｅｌｌｏ１２３", "Hello123"),
                ("你好世界", "你号世界"), ("这是一些测试文字", "这是另些测试文字"),
                ("23333333333", "233"), ("666666666", "666"), ("😀😀", "😀😀")]:
        pair(a,b,0)
    pair("你", "他", 1); pair("完全不同", "abcdef", 1)
    pair("测试", "测试", 0, 30000); pair("测试", "测试", 1, 30001)
    oracle=C.CDLL(str(ROOT / "build/x64/pakku_oracle.dll")).PakkuCompare
    oracle.argtypes=[C.c_wchar_p,C.c_wchar_p];oracle.restype=C.c_int
    rng=random.Random(1743)
    alphabet="ABCDEFGabcdefg天地玄黄宇宙洪荒你好世界中文测试弹幕😀😂"
    for _ in range(2000):
        a=''.join(rng.choices(alphabet,k=rng.randint(1,40)))
        b=list(a)
        for _ in range(rng.randint(0,8)): b[rng.randrange(len(b))]=rng.choice(alphabet)
        if rng.randrange(3)==0: rng.shuffle(b)
        if rng.randrange(3)==0: b+=list(''.join(rng.choices(alphabet,k=rng.randint(1,15))))
        b=''.join(b)
        pair(a,b,0 if oracle(a,b) else 1)
    # Largest-frequency representative and ties at median length.
    h = create(30000)
    try:
        for a in ["测试！！", "测试", "测试", "测式"]:
            raw=a.encode(); assert feed(h,raw,len(raw),0)==0
        assert text(h,0).decode()=="测试"
    finally: free(h)
    # Native malformed arguments do not escape across the C ABI.
    assert feed(0,b"x",1,0)==-1
    h=create(30000)
    try:
        assert feed(h,b"\xff",1,0)==-1
        assert select(h,b"x",1,0,0,1)==-1
    finally: free(h)
    def selection(peers, weight, size=32, shrink=False):
        h=create(30000)
        try:
            assert set_weight(h,1,100)==0 and set_weight(h,11,100)==0
            raw="密集弹幕测试内容测试内容".encode(); sizes=[]
            for i in range(250):
                packed=size|(weight<<12)|(131072 if shrink else 0)
                sizes.append(select(h,raw,len(raw),i,packed,peers))
            # Quiet section drains the five-second queue.
            assert select(h,b"quiet",5,6000,size|(weight<<12),1)==size
            return sizes
        finally: free(h)
    assert all(x==32 for x in selection(1,1)), "density has no preference/drop threshold"
    shrunk=selection(1,1,24,True)
    assert min(x for x in shrunk if x)>15 and any(0<x<24 for x in shrunk), "density shrink with floor"
    assert min(x for x in selection(1,1,8,True) if x)==16
    init=dll.BiliDanmakuLayoutInit;init.argtypes=[C.c_size_t,C.c_uint32,C.c_uint32,C.c_uint32]
    place=dll.BiliDanmakuPlace;place.argtypes=[C.c_size_t]+[C.c_uint32]*4;place.restype=C.c_size_t
    refine=dll.BiliDanmakuRefineTop;refine.argtypes=[C.c_size_t,C.c_uint32,C.c_uint32,C.c_uint32];refine.restype=C.c_size_t
    h=create(30000)
    try:
        assert refine(0,1000,960,0)==C.c_size_t(-1).value
        assert init(h,33,33,15000)==0
        assert place(h,1000,1,100,33)>0
        assert place(h,1100,1,100,33)==0, "full scroll lane rejects overflow"
        assert place(h,1800,1,100,33)>0, "scroll lane admits safely spaced comments before prior exit"
        assert place(h,1000,6,100,33)==0, "opposite directions share screen capacity"
        assert place(h,1000,5,1900,33)>0, "top may overlap scrolling"
        assert place(h,1100,5,1900,33)==0
        assert place(h,16000,5,1900,33)>0, "fixed capacity expires at exact end time"
        assert init(h,33,33,15000)==0
        assert place(h,1100,1,100,33)>0
        assert place(h,1000,1,100,33)==0, "priority reservation handles earlier timestamps"
        assert place(h,0,1,100,33)>0, "priority reservation fills safe earlier gaps"
        assert init(h,100,1,15000)==0
        for height,y in [(25,0),(25,25),(17,50),(33,67)]:
            assert place(h,1000,1,500,height)==1+y, "exact heights reclaim pixels lost by a 17-pixel grid"
        assert place(h,1000,1,500,1)==0
        assert init(h,100,1,15000)==0
        fixed=place(h,1000,5,500,25)
        assert (fixed-1)&0xffffffff==0
        assert place(h,1000,1,500,25)==1, "top does not consume moving capacity even when there is other free space"
        assert init(h,100,1,15000)==0
        assert place(h,1000,1,500,25)==1
        assert (place(h,1000,5,500,25)-1)&0xffffffff==0, "moving comment does not push top comment downward"
        for y in [25,50,75]:
            code=place(h,1000,5,500,25)-1
            assert code>>32==960 and code&0xffffffff==y, "top fills centered rows first"
        code=place(h,1000,5,500,25)-1
        assert code>>32!=960 and code&0xffffffff==0, "full centered region searches horizontal gaps"
        assert init(h,100,1,15000)==0
        for y in [0,25,50,75]:
            assert place(h,1000,1,1920,25)==1+y
        for y in [0,25,50,75]:
            assert (place(h,1000,5,1920,25)-1)&0xffffffff==y, "full moving region leaves all top rows available"
        assert place(h,1000,5,1920,25)==0, "top overflow never overlaps another top comment"
        assert place(h,16000,5,1920,25)>0, "cached top overflow expires at the real end time"
        for scroll_first in [False,True]:
            assert init(h,100,1,15000)==0
            if scroll_first:
                for _ in range(2):assert place(h,1000,1,500,25)>0
            for _ in range(4):assert place(h,1000,5,500,25)>0
            code=place(h,1000,5,500,25)-1
            assert code&0xffffffff==0
            if not scroll_first:
                for _ in range(2):assert place(h,1000,1,500,25)>0
            updated=refine(h,1000,code>>32,code&0xffffffff)-1
            assert updated&0xffffffff==50, "overflow chooses lower blank side region even if moving comments were placed later"
            assert updated>>32!=960
        assert init(h,100,1,15000)==0
        for _ in range(4):assert place(h,1000,5,500,25)>0
        code=place(h,1000,5,500,25)-1
        for _ in range(4):assert place(h,1000,1,500,25)>0
        assert refine(h,1000,code>>32,code&0xffffffff)==code+1, "no global blank space retains allowed top/scroll overlap"
    finally:free(h)
    # Unique-window workload plus identical flood: both exercise the real DLL.
    rng=random.Random(1743); h=create(30000); started=time.perf_counter()
    try:
        for i in range(73250):
            s=("相同弹幕" if i%2 else ''.join(chr(0x4e00+rng.randrange(1000)) for _ in range(12))).encode()
            assert feed(h,s,len(s),i*25)>=0
    finally: free(h)
    print(f"PASS: native similarity/normalization/pinyin/window/representative/selection/shrink; 73250 merge calls in {(time.perf_counter()-started)*1000:.0f} ms")


if __name__ == "__main__":
    verify_native()
    verify_ass()
