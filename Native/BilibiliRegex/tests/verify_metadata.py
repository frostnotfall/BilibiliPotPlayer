import re
import subprocess


def function(source, signature):
    start = source.index("\n" + signature) + 1
    return source[start:source.index("\n}", start) + 2]


def metadata_script(repo):
    parse = (repo / "Extension/Media/PlayParse/MediaPlayParse - Bilibili.as").read_text(encoding="utf-8-sig")
    stats = (repo / "Extension/Playback/Statistics/PlaybackStatistics - Bilibili.as").read_text(encoding="utf-8-sig")
    for name in ("GetWebAccountUrl", "GetWebAccountDomain"):
        a = re.search(r'return "([^"]+)";', function(parse, f"string {name}()")).group(1)
        b = re.search(r'return "([^"]+)";', function(stats, f"string {name}()")).group(1)
        assert a == b, name
    assert a.split(";")[0] == "www.bilibili.com"
    assert 'MetaData["vid"] = "bilibili.com|" + epid;' in function(parse, "string Bangumi(")
    assert 'MetaData["vid"] = "bilibili.com|" + cid;' in function(parse, "string Video(")
    for signature in ("string Bangumi(", "string Video("):
        body = function(parse, signature)
        assert 'MetaData["webUrl"] = webUrl;' in body
        assert 'int seek = GetStartSeconds(path, aid, cid' in body
        assert re.search(r'if \(seek > 0(?: && !MetaData\.exists\("seek"\))?\) MetaData\["seek"\] = seek;', body)
    assert '"https://www.bilibili.com/bangumi/play/ep" + epid' in parse
    assert '"https://www.bilibili.com/video/" + bvid' in parse
    assert '"seek"' not in function(parse, "string Live(")
    episodes = function(parse, "array<dictionary> BangumiEpisodes(")
    assert 'if (isCurrent && !query.empty()) videoUrl = makeWebUrl(videoUrl +' in episodes
    season = function(parse, "array<dictionary> UGCSeason(")
    assert season.count('isCurrent ? makeWebUrl(path) : makeWebUrl(') == 2
    playlist = function(parse, "array<dictionary> PlaylistParse(")
    assert 'return UGCSeason(path);' in playlist
    for prefix, kind in (("MD", "media"), ("EP", "ep"), ("SS", "season")):
        assert f'return BangumiEpisodes(parse{prefix}Id(path), "{kind}_id", path);' in playlist
    assert 'HostGetCookie' not in function(stats, "void OnInitialize()")
    assert stats.count('HostGetCookie()') == 1
    for source in (parse, stats):
        assert 'BilibiliPotPlayer.BiliJct()' not in source
        assert 'GetBiliJct()' not in source
    assert 'post(url, postData, headers, false)' in function(stats, "void liveHeartBeatThread(")
    assert 'BilibiliPotPlayer.HeartBeat()' in function(stats, "void PlaybackStart(")
    for source in (parse, stats):
        assert 'Cookie:' not in source and 'HostSetUrlCookieHTTP(' not in source
        for call in re.findall(r'HostUrlGetString\([^;]+;', source):
            assert not re.search(r',\s*true\s*\);$', call)
    for js in ("Bilibili - ChatScriptLive.js", "Bilibili - ChatScriptVod.js"):
        text = (repo / "Extension/Media/PlayParse" / js).read_text(encoding="utf-8-sig")
        assert "MutationObserver" in text and ".destroy()" in text
    pieces = [function(parse, signature) for signature in (
        'string parse(string url,', 'int parseTime(string s)', 'int GetStartSeconds(',
        'string makeWebUrl(',
        'string ReadWebScript(')]
    pieces.append(function(stats, 'string GetCookieValue('))
    pieces.extend(function(stats, signature) for signature in (
        'void liveHeartBeatThread(', 'void liveHeartBeat()', 'void PlaybackStart(',
        'void PlaybackTime(', 'void PlaybackPause(', 'void PlaybackResume(',
        'void PlaybackComplete(', 'void PlaybackClose('))
    # Run the production heartbeat with a controllable clock; no real waiting or
    # HTTP requests are needed to check interval and playback state transitions.
    pieces.append(stats[stats.index('class VodHeartbeat {'):stats.index('\nvoid liveHeartBeatThread(')]
                  .replace('HostGetTickCount()', 'HeartbeatTickCount()'))
    pieces.append(r'''
VodHeartbeat heartbeat;
bool heartbeatEnabled = true, validJson = true;
int responseCode = 0, cookieReads = 0, requests = 0, alerts = 0, vodStarts = 0;
string cookieFixture, requestUrl, requestHeaders, requestBody;
string fallbackJct;
uint heartbeatTick = 100;
string heartbeatInterval = "15", idsFixture = "ids";
string episodeId = "0", seasonId = "0";
uint HeartbeatTickCount() { return heartbeatTick; }
string GetUnixTime() { return "1792512000"; }
string GetIds() { vodStarts++; return idsFixture; }
string GetDanmujiServer() { return "fixture"; }
class DanmujiManager {
    DanmujiManager(const string &in server) {}
    void Stop() {}
}
int fallbackReads = 0;
bool requestDebug = true;
const string Host = "https://api.bilibili.com";
string historyCid = "62131", responseFixture = "fixture";
double historyMilliseconds = 90500;
bool historyObject = true;
class JsonValue {
    string key;
    bool isObject() { return key != "data" || historyObject; }
    bool isInt() { return key == "code"; }
    JsonValue opIndex(const string &in name) const { JsonValue item; item.key = name; return item; }
    int asInt() { return key == "id" ? 42 : responseCode; }
    string asString() {
        if (key == "aid") return "123";
        if (key == "bvid") return "BVtest";
        if (key == "cid") return "62131";
        if (key == "mid") return "456";
        if (key == "epid") return episodeId;
        if (key == "ssid") return seasonId;
        return key == "last_play_cid" ? historyCid : "fixture response";
    }
    int64 asInt64() { return parseInt(asString()); }
    double asDouble() { return historyMilliseconds; }
}
class JsonReader {
    bool parse(const string &in input, JsonValue &out root) { return validJson && !input.empty(); }
}
string HostGetCookie() { cookieReads++; return cookieFixture; }
string HostLoadString(const string &in key) {
    if (key == "BilibiliPotPlayer.HeartBeatInterval()") return heartbeatInterval;
    fallbackReads++; return fallbackJct;
}
string HostUrlEncode(const string &in input) { return input; }
string HostGetPlayingFileName() { return "42"; }
int HostLoadInteger(const string &in key) { return heartbeatEnabled ? 1 : 0; }
void HostMessageBox(const string &in text, const string &in title, int icon, int buttons) { alerts++; }
string post(string url, string data, string headers, bool debug = true) {
    requests++; requestUrl = url; requestHeaders = headers; requestDebug = debug; requestBody = data;
    return responseFixture;
}
int HostCreateThread(ThreadFunction@ callback, const string &in task) {
    any args(task); callback(args); return 1;
}
void log(string item, string info) { log(item + ": " + info); }
void CheckHeartbeat() {
    heartbeatEnabled = false; cookieFixture = "bili_jct=unused";
    PlaybackStart("/live-bvc/fixture", 0);
    PlaybackStart("/upgcxcode/fixture", 0);
    Assert(cookieReads == 0 && requests == 0 && vodStarts == 0, "disabled heartbeat launches no work");
    heartbeatEnabled = true; cookieFixture = "";
    PlaybackStart("/live-bvc/fixture", 0);
    Assert(cookieReads == 1 && requests == 0 && alerts == 0, "empty CSRF skips action without login verdict");
    cookieFixture = "other=ignored; bili_jct=first";
    PlaybackStart("/live-bvc/fixture", 0);
    Assert(cookieReads == 2 && requests == 1 && !requestDebug, "one cookie read per actual request, no sensitive URL logging");
    Assert(requestUrl.find("csrf=first") >= 0 && requestHeaders.find("Cookie:") < 0, "extract only CSRF, preserve native HTTP cookies");
    cookieFixture = "bili_jct=fresh"; responseCode = -101;
    PlaybackStart("/live-bvc/fixture", 0);
    Assert(cookieReads == 3 && requests == 2 && alerts == 1 && requestUrl.find("csrf=fresh") >= 0, "fresh cookie and expired login response");
    PlaybackStart("/upgcxcode/fixture", 0);
    Assert(vodStarts == 1 && cookieReads == 3, "VOD heartbeat needs no cookie getter");
    validJson = false; PlaybackStart("/live-bvc/fixture", 0);
    Assert(cookieReads == 3 && requests == 3, "invalid task stops before cookie/request");
    validJson = true;
    responseCode = 0; fallbackJct = "manual"; fallbackReads = 0;
    cookieFixture = "bili_jct=native";
    PlaybackStart("/live-bvc/fixture", 0);
    Assert(fallbackReads == 0 && requestUrl.find("csrf=native") >= 0, "native CSRF is used without reading legacy config");
    cookieFixture = "other=ignored";
    int before = requests;
    PlaybackStart("/live-bvc/fixture", 0);
    Assert(fallbackReads == 0 && requests == before, "missing cookie field skips heartbeat even with a legacy token");
    cookieFixture = "bili_jct=";
    PlaybackStart("/live-bvc/fixture", 0);
    Assert(fallbackReads == 0 && requests == before, "empty native CSRF skips heartbeat without legacy fallback");
    cookieFixture = "bili_jct=renewed";
    PlaybackStart("/live-bvc/fixture", 0);
    Assert(fallbackReads == 0 && requests == before + 1 && requestUrl.find("csrf=renewed") >= 0 && !requestDebug,
        "renewed native cookie resumes heartbeat without logging credentials");
    heartbeat.Stop();
}
void CheckVodProgress() {
    validJson = true; responseCode = 0; heartbeatEnabled = true;
    requests = 0; vodStarts = 0; heartbeatTick = 100; heartbeatInterval = "15";
    PlaybackStart("/upgcxcode/fixture", 300000);
    Assert(requests == 1 && requestBody.find("played_time=0") >= 0 &&
        requestBody.find("cid=62131") >= 0 && requestBody.find("aid=123") >= 0 &&
        requestBody.find("bvid=BVtest") >= 0, "start reports video identifiers and zero progress");
    heartbeatTick += 14999; PlaybackTime("fixture", 90500, 300000);
    Assert(requests == 1, "no report before interval");
    heartbeatTick++; PlaybackTime("fixture", 90500, 300000);
    Assert(requests == 2 && requestBody.find("played_time=90") >= 0,
        "periodic progress converts milliseconds to seconds");
    PlaybackPause("fixture"); heartbeatTick += 60000; PlaybackTime("fixture", 90500, 300000);
    Assert(requests == 2, "pause suppresses progress reports");
    PlaybackResume("fixture"); PlaybackTime("fixture", 90500, 300000);
    Assert(requests == 2, "resume starts a fresh interval");
    heartbeatTick += 15000; PlaybackTime("fixture", 120000, 300000);
    Assert(requests == 3 && requestBody.find("played_time=120") >= 0, "resume reports current position");
    heartbeatInterval = "30"; heartbeatTick += 15000; PlaybackTime("fixture", 135000, 300000);
    Assert(requests == 3, "custom interval is respected");
    heartbeatTick += 15000; PlaybackTime("fixture", 150000, 300000);
    Assert(requests == 4, "custom interval sends at boundary");
    heartbeatInterval = "1"; heartbeatTick += 14999; PlaybackTime("fixture", 160000, 300000);
    Assert(requests == 4, "minimum interval enforced");
    heartbeatTick++; PlaybackTime("fixture", 165000, 300000);
    Assert(requests == 5, "minimum interval sends at 15 seconds");
    heartbeatEnabled = false; heartbeatTick += 15000; PlaybackTime("fixture", 180000, 300000);
    Assert(requests == 5, "heartBeat switch disables periodic uploads");
    heartbeatEnabled = true;
    string previousBody = requestBody;
    PlaybackComplete("/upgcxcode/fixture");
    PlaybackComplete("/upgcxcode/fixture");
    Assert(requests == 5 && requestBody == previousBody && requestBody.find("played_time=-1") < 0,
        "issue 34: completion callback preserves last reported progress without marking finished");
    PlaybackClose("/upgcxcode/fixture");
    heartbeatTick += 60000; PlaybackResume("fixture"); PlaybackTime("fixture", 300000, 300000);
    Assert(requests == 5, "close clears state and resume cannot upload stale progress");
    episodeId = "1234"; seasonId = "5678";
    PlaybackStart("/upgcxcode/fixture", 300000);
    Assert(requestBody.find("epid=1234") >= 0 && requestBody.find("sid=5678") >= 0 &&
        requestHeaders.find("/bangumi/play/ep1234") >= 0, "PGC episode and season identifiers");
    heartbeat.Stop(); heartbeatTick += 60000; PlaybackTime("fixture", 200000, 300000);
    Assert(requests == 6, "stop suppresses stale uploads");
    episodeId = "0"; seasonId = "0"; idsFixture = "";
    PlaybackStart("/upgcxcode/fixture", 300000);
    Assert(requests == 6, "missing identifiers cannot start heartbeat");
    idsFixture = "ids"; heartbeatInterval = "15";
    heartbeatTick = 0xFFFFFF00; PlaybackStart("/upgcxcode/fixture", 300000);
    heartbeatTick += 15000; PlaybackTime("fixture", 15000, 300000);
    Assert(requests == 8 && requestBody.find("played_time=15") >= 0, "tick count wraparound");
    heartbeat.Stop();
    HostPrintUTF8("[heartbeat] PASS: switch, interval, progress, pause/resume, completion, stop, PGC and tick wraparound");
}
bool fixtureExists = true, fixtureOpen = true;
int fixtureClosed = 0;
string fixtureJS = "window.executions = (window.executions || 0) + 1;";
bool HostFileExist(const string &in path) { return fixtureExists; }
uintptr HostFileOpen(const string &in path) { return fixtureOpen ? 1 : 0; }
int HostFileLength(uintptr fp) { return fixtureJS.length(); }
string HostFileRead(uintptr fp, int length) { return fixtureJS; }
void HostFileClose(uintptr fp) { fixtureClosed++; }
void CheckMetadata() {
    CheckHeartbeat();
    CheckVodProgress();
    responseCode = 0; alerts = 0; requests = 0;
    array<string> input = {"90", "90.9", "0.9", "0", "-90", "", "bogus", "1m30s",
        "1h2m3.5s", "01:02:03.500", "02:03", "1%3A30.9", "90#comments", "90junk",
        "NaN", "Infinity", "1:60", "1:2:3:4", "1s2m", "2147483648", "999999999999999h",
        "2147483647", "596:59:59", "1.5m", "1.5h", "1e3", "90%26p=2"};
    array<int> expected = {90, 90, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90, 0,
        0, 0, 0, 0, 0, 0, 0, 2147483647, 0, 0, 0, 0, 0};
    for (uint i = 0; i < input.length(); i++)
        Assert(GetStartSeconds("https://www.bilibili.com/video/BVtest/?p=2&t=" + input[i], "2", "62131") == expected[i], "URL time: " + input[i]);
    Assert(requests == 0, "present t never queries history, including empty/invalid/zero values");
    ConfigData.queryPlayPosition = false;
    Assert(GetStartSeconds("https://www.bilibili.com/video/BVtest", "2", "62131") == 0 && requests == 0, "disabled history query leaves native resume available");
    Assert(GetStartSeconds("https://www.bilibili.com/bangumi/play/ep123", "2", "62131", "123") == 0 && requests == 0, "disabled query also applies to PGC");
    Assert(GetStartSeconds("https://www.bilibili.com/video/BVtest?t=90.9", "2", "62131") == 90 && requests == 0, "explicit t works with history query disabled");
    ConfigData.queryPlayPosition = true;
    Assert(GetStartSeconds("https://www.bilibili.com/video/BVtest", "2", "62131") == 90, "missing t reads history milliseconds as integer seconds");
    Assert(requests == 1 && !requestDebug && requestUrl.find("/x/player/wbi/v2?aid=2&cid=62131") >= 0, "fresh native HTTP request to current webpage endpoint");
    Assert(GetStartSeconds("https://www.bilibili.com/video/BVtest/?foo=t=90", "2", "62131") == 90, "text inside another parameter is not t");
    Assert(GetStartSeconds("https://www.bilibili.com/video/BVtest/#?t=120", "2", "62131") == 90, "fragment is not an explicit t");
    Assert(GetStartSeconds("https://www.bilibili.com/bangumi/play/ep123", "2", "62131", "123") == 90 && requestUrl.find("&ep_id=123") >= 0, "PGC queries history with episode id");
    historyCid = "other-part";
    Assert(GetStartSeconds("https://www.bilibili.com/video/BVtest", "2", "62131") == 0, "different cid cannot supply progress");
    historyCid = "62131"; historyMilliseconds = -1;
    Assert(GetStartSeconds("https://www.bilibili.com/video/BVtest", "2", "62131") == 0, "negative/completed progress is ignored");
    historyMilliseconds = 0;
    Assert(GetStartSeconds("https://www.bilibili.com/video/BVtest", "2", "62131") == 0, "no history progress");
    historyMilliseconds = 2147483648000.0;
    Assert(GetStartSeconds("https://www.bilibili.com/video/BVtest", "2", "62131") == 0, "history overflow is ignored");
    historyMilliseconds = 90500; responseCode = -101;
    Assert(GetStartSeconds("https://www.bilibili.com/video/BVtest", "2", "62131") == 0 && alerts == 0, "expired login does not interrupt playback");
    responseCode = 0; validJson = false;
    Assert(GetStartSeconds("https://www.bilibili.com/video/BVtest", "2", "62131") == 0, "malformed response");
    validJson = true; responseFixture = "";
    Assert(GetStartSeconds("https://www.bilibili.com/video/BVtest", "2", "62131") == 0, "empty response");
    responseFixture = "fixture"; historyObject = false;
    Assert(GetStartSeconds("https://www.bilibili.com/video/BVtest", "2", "62131") == 0, "missing history data");
    historyObject = true;
    Assert(parseTime("01:02:03") == 3723000, "playlist duration stays milliseconds");
    Assert(parseTime("2:03") == 123000, "playlist duration stays milliseconds");
    string query = HostRegExpParse("https://www.bilibili.com/video/BVtest?p=2&t=90.5&spm=x#comments", "^[^?#]*\\?([^#]*)");
    Assert(query == "p=2&t=90.5&spm=x", "carry original query without converting time");
    Assert(makeWebUrl("https://www.bilibili.com/bangumi/play/ep1?" + query) ==
        "https://www.bilibili.com/bangumi/play/ep1?t=90.5&p=2", "normalize redirected URL with original query");
    Assert(makeWebUrl("https://www.bilibili.com/bangumi/play/ep1?from=redirect&" + query) ==
        "https://www.bilibili.com/bangumi/play/ep1?t=90.5&p=2", "carry query when redirect already has parameters");
    Assert(makeWebUrl("https://www.bilibili.com/video/BVtest?foo=x&p=2&t=90.5") ==
        "https://www.bilibili.com/video/BVtest?t=90.5&p=2", "default retains existing t and p");
    Assert(makeWebUrl("https://www.bilibili.com/video/BVtest?p=1") ==
        "https://www.bilibili.com/video/BVtest", "default omits first-part parameter");
    Assert(makeWebUrl("https://www.bilibili.com/video/BVtest#comments") ==
        "https://www.bilibili.com/video/BVtest#comments", "default URL without query is unchanged");
    Assert(GetCookieValue("", "bili_jct") == "", "empty cookie");
    Assert(GetCookieValue("other=1; bili_jct=token; foo=2", "bili_jct") == "token", "CSRF only");
    Assert(GetCookieValue("not_bili_jct=wrong; bili_jct_extra=wrong", "bili_jct") == "", "exact cookie name");
    Assert(GetCookieValue(" ; malformed;\tbili_jct=a=b=c; other=x", "bili_jct") == "a=b=c", "first equals, whitespace, malformed field");
    Assert(GetCookieValue("bili_jct=", "bili_jct") == "", "empty field");
    Assert(GetCookieValue("bili_jct=fresh", "bili_jct") == "fresh", "no cached token");
    fixtureExists = false;
    Assert(ReadWebScript("fixture") == "", "missing JS is optional");
    fixtureExists = true; fixtureOpen = false;
    Assert(ReadWebScript("fixture") == "", "unreadable JS is optional");
    fixtureOpen = true;
    Assert(ReadWebScript("fixture") == fixtureJS && fixtureClosed == 1, "return JS unchanged and close file");
    fixtureJS = "\xEF\xBB\xBF" + fixtureJS;
    Assert(ReadWebScript("fixture").find("window.executions") == 0, "strip UTF-8 BOM");
    fixtureJS = "";
    Assert(ReadWebScript("fixture") == "", "empty JS file");
}
''')
    return "\n".join(pieces)


def verify_chat_scripts(repo):
    for name in ("Bilibili - ChatScriptVod.js", "Bilibili - ChatScriptLive.js"):
        target = repo / "Extension/Media/PlayParse" / name
        subprocess.run(["node", "--check", str(target)], check=True)
    print('PASS: original chat JS syntax (no AngelScript lifecycle wrapper)')
