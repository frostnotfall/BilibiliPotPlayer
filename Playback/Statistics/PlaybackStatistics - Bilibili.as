// void OnInitialize()
// void OnFinalize()
// string GetTitle() 									-> get title for UI
// string GetVersion									-> get version for manage
// string GetDesc()										-> get detail information
//------------------------------------------------------------------------------------------------
// void PlaybackOpen(const string &in)
// void PlaybackStart(const string &in, int)
// void PlaybackTime(const string &in, int, int)
// void PlaybackPause(const string &in)
// void PlaybackResume(const string &in)
// void PlaybackComplete(const string &in)
// void PlaybackClose(const string &in)

const string DANMUJI_STATUS = "BilibiliPotPlayer.DanmujiStatus()";
const string DANMUJI_SERVER = "BilibiliPotPlayer.DanmujiServer()";

void OnInitialize() {
	// HostOpenConsole();
}

string GetTitle() {
	return "BiliBili";
}
string GetVersion() {
	return "1";
}

string GetDesc() {
	return "https://www.bilibili.com";
}

void log(string item) {
	HostPrintUTF8("[" + formatFloat(HostGetTickCount() / 1000.0, "", 3, 3) + "] - " + "PlaybackStatistics - Bilibili - " + item);
}

void log(string item, string info) {
	log(item + ": " + info);
}

void log(string item, int info) {
	log(item + ": " + info);
}

string post(string url, string data = "", string headers = "", bool debug = true) {
	uint start = HostGetTickCount();
	string res =  HostUrlGetString(url, "", headers, data);
	uint end = HostGetTickCount();
	HostIncTimeOut(end - start);
	if (debug) log("Request time: " + formatFloat((end - start) / 1000.0, "", 3, 3) + "s" + ", url: " + url);

	return res;
}

string FormatDateTime(datetime&in dt) {
	return formatInt(dt.get_year()) + "-" + (dt.get_month() < 10 ? "0" : "") +
		   formatInt(dt.get_month()) + "-" + (dt.get_day() < 10 ? "0" : "") +
		   formatInt(dt.get_day()) + " " + (dt.get_hour() < 10 ? "0" : "") +
		   formatInt(dt.get_hour()) + ":" + (dt.get_minute() < 10 ? "0" : "") +
		   formatInt(dt.get_minute()) + ":" + (dt.get_second() < 10 ? "0" : "") +
		   formatInt(dt.get_second());
}

int64 DateTimeToUnixTime(const string&in s) {
	int year = parseInt(s.substr(0, 4));
	int month = parseInt(s.substr(5, 2));
	int day = parseInt(s.substr(8, 2));
	int hour = parseInt(s.substr(11, 2));
	int minute = parseInt(s.substr(14, 2));
	int second = parseInt(s.substr(17, 2));

	int64 days = 0;

	for (int y = 1970; y < year; y++)
		days += ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0) ? 366 : 365;

	int[] daysInMonth = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

	for (int m = 1; m < month; m++)
		days += daysInMonth[m - 1] + (m == 2 && ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0) ? 1 : 0);

	days += day - 1;

	return days * 86400 + hour * 3600 + minute * 60 + second;
}

void SetDanmujiStatus(bool value) {
	HostSaveInteger(DANMUJI_STATUS, value ? 1 : 0);
}

bool GetDanmujiStatus() {
	return HostLoadInteger(DANMUJI_STATUS) != 0;
}

string GetDanmujiServer() {
	return HostLoadString(DANMUJI_SERVER);
}

string GetIds() {
	return HostLoadString("BilibiliPotPlayer.Ids()");
}

string GetBiliJct() {
	return HostLoadString("BilibiliPotPlayer.BiliJct()");
}


void vodHeartBeat() {
	string ids = GetIds();

	if (ids.isEmpty()) return;

	JsonReader reader;
	JsonValue root;

	if ( !reader.parse(ids, root) || !root.isObject() ) return;

	int64 aid = root["aid"].asInt64();
	string bvid = root["bvid"].asString();
	int64 cid = root["cid"].asInt64();
	int64 epid = root["epid"].asInt64();
	int64 ssid = root["ssid"].asInt64();
	int64 mid = root["mid"].asInt64();

	string unixTime = formatInt(DateTimeToUnixTime(FormatDateTime(datetime())));

	array<string> postDataArray;
	postDataArray.insertLast("start_ts=" + unixTime);
	if (aid != 0) postDataArray.insertLast("aid=" + formatInt(aid));
	if (bvid != "") postDataArray.insertLast("bvid=" + bvid);
	if (cid != 0) postDataArray.insertLast("cid=" + formatInt(cid));
	if (epid != 0) postDataArray.insertLast("epid=" + formatInt(epid));
	if (ssid != 0) postDataArray.insertLast("ssid=" + formatInt(ssid));
	if (mid != 0) postDataArray.insertLast("mid=" + formatInt(mid));

	string postData = join(postDataArray, "&");

	string headers =
		"Content-Type: application/x-www-form-urlencoded\r\n"
		"Referer: https://www.bilibili.com/video/" + bvid + "/\r\n"
		"Origin: https://www.bilibili.com\r\n";

	post("https://api.bilibili.com/x/click-interface/web/heartbeat?" + "w_start_ts=" + unixTime + "&w_mid=" + formatInt(mid) + "&w_aid=" + formatInt(aid),
		postData,
		headers
	);
}

void liveHeartBeat() {
	string biliJct = GetBiliJct();
	if (biliJct.isEmpty()) return;

	int id = parseInt(HostGetPlayingFileName());
	if (id <= 0) return;
	
	string url = 'https://api.live.bilibili.com/xlive/web-room/v1/index/roomEntryAction?csrf=' + biliJct;
	string postData = '{"room_id": ' + formatInt(id) + ',"platform":"pc"}';
	
	string headers =
		"Content-Type: application/json\r\n"
		"Referer: https://live.bilibili.com/" + formatInt(id) + "\r\n"
		"Origin: https://live.bilibili.com\r\n";

	string res = post(url, postData, headers);
	JsonReader Reader;
	JsonValue Root;
	if (!Reader.parse(res, Root) || !Root.isObject()) {
		log("Failed to parse live heartbeat response: " + res);
	}

	if (Root["code"].asInt() != 0) {
		HostMessageBox("直播心跳上报有误，可能需要更新 bili_jct, code: " + Root["code"].asInt() + ", message: " + Root["message"].asString(), "直播心跳上报有误", 2, 0);
	}

}

void PlaybackOpen(const string &in path) {
	// log("PlaybackOpen()", path);

	if (GetDanmujiServer().isEmpty()) return;
	if (path.find("/live-bvc/") < 0) return;

	int id = parseInt(HostGetPlayingFileName());
	if (id <= 0) return;

	string unixTime;
	int tickCount = HostGetTickCount();
	while (GetDanmujiStatus()) {
		if (HostGetTickCount() - tickCount > 5000) {
			unixTime = formatInt(DateTimeToUnixTime(FormatDateTime(datetime())));
			post(GetDanmujiServer() + "/disconnectRoom?_=" + unixTime);
			break;
		}
		HostSleep(100);
	}

	unixTime = formatInt(DateTimeToUnixTime(FormatDateTime(datetime())));
	string res = post(GetDanmujiServer() + "/connectRoom?roomid=" + id + "&_=" + unixTime);

	string message;
	JsonReader Reader;
	JsonValue Root;

	if (res.isEmpty()) {
		log("connectRoom failed, empty response");
		message = "弹幕姬建立房间连接失败, 服务未返回任何响应\n服务是否启动?";
	} else if (!Reader.parse(res, Root) || !Root.isObject()) {
		log('connectRoom failed', '!Reader.parse(res, Root) || !Root.isObject()');
		message = "弹幕姬建立房间连接失败, 无法解析服务器响应\n服务是否存在问题?";
	} else if (Root["code"].asString() != "200") {
		log("connectRoom failed, code: " + Root["code"].asString() + ", msg: " + Root["msg"].asString());
		message = "弹幕姬建立房间连接失败, 错误码: " + Root["code"].asString() + ", 错误信息: " + Root["msg"].asString() + "\n服务是否存在问题?";
	} else if (!Root["result"].asBool()) {
		log("connectRoom failed, result: false");
		message = "弹幕姬建立房间连接失败, 返回结果为 false, 重新打开试试";
	}

	if (!message.empty()) {
		HostMessageBox(message, "弹幕姬连接失败", 1, 0);
		SetDanmujiStatus(false);
	} else{
		SetDanmujiStatus(true);
	}
}

void PlaybackStart(const string &in path, int) {
	// log("PlaybackStart()", path);

	if ( path.find("/upgcxcode/") >= 0) {
		log("PlaybackStart() - vodHeartBeat()");
		vodHeartBeat();
	}

	if ( path.find("/live-bvc/") >= 0) {
		log("PlaybackStart() - liveHeartBeat()");
		liveHeartBeat();
	}
}

void PlaybackTime(const string &in path, int, int) {
	// log("PlaybackTime()", path);
}

void PlaybackPause(const string &in path) {
	// log("PlaybackPause()", path);
}

void PlaybackResume(const string &in path) {
	// log("PlaybackResume()", path);
}

void PlaybackComplete(const string &in path) {
	// log("PlaybackComplete()", path);

	string id = HostRegExpParse(path, "live.bilibili.com/([0-9]+)");
	if (id.empty()) return;

	if (!GetDanmujiServer().isEmpty()) {
		string unixTime = formatInt(DateTimeToUnixTime(FormatDateTime(datetime())));
		post(GetDanmujiServer() + "/disconnectRoom?_=" + unixTime);
		SetDanmujiStatus(false);
	}
}

void PlaybackClose(const string &in path) {
	// log("PlaybackClose()", path);

	string id = HostRegExpParse(path, "live.bilibili.com/([0-9]+)");
	if (id.empty()) return;

	if (!GetDanmujiServer().isEmpty()) {
		string unixTime = formatInt(DateTimeToUnixTime(FormatDateTime(datetime())));
		post(GetDanmujiServer() + "/disconnectRoom?_=" + unixTime);
		SetDanmujiStatus(false);
	}
}