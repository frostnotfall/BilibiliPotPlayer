/*
	Bilibili PlaybackStatistics
	author: frostnotfall
	link: https://github.com/frostnotfall/BilibiliPotPlayer
*/

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
	string res = HostUrlGetString(url, "", headers, data);
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

string GetUnixTime() {
	return formatInt(DateTimeToUnixTime(FormatDateTime(datetime())));
}

string GetIds() {
	return HostLoadString("BilibiliPotPlayer.Ids()");
}

string GetBiliJct() {
	return HostLoadString("BilibiliPotPlayer.BiliJct()");
}

string GetDanmujiServer() {
	return HostLoadString("BilibiliPotPlayer.DanmujiServer()");
}

class DanmujiManager {
	string server;
	string WORKING_KEY = "BilibiliPotPlayer.DanmujiWorking()";

	DanmujiManager(const string &in serverUrl) {
		server = serverUrl;
	}

	bool IsWorking() {
		return HostLoadInteger(WORKING_KEY) != 0;
	}

	void SetWorking(bool working) {
		HostSaveInteger(WORKING_KEY, working ? 1 : 0);
	}

	bool IsConnected() {
		string res = post(server + "/connectCheck?_=" + GetUnixTime());
		if (res.isEmpty()) return false;
		JsonReader Reader;
		JsonValue Root;

		return Reader.parse(res, Root) && Root.isObject() && Root["result"].asBool();
	}

	void Disconnect() {
		post(server + "/disconnectRoom?_=" + GetUnixTime());
	}

	void Connect(int id) {
		string res = post(server + "/connectRoom?roomid=" + id + "&_=" + GetUnixTime());
		JsonReader Reader;
		JsonValue Root;
		string message;

		if (res.isEmpty()) {
			log("connectRoom failed, empty response");
			message = "弹幕姬建立房间连接失败, 服务未返回任何响应\n服务是否启动?";
		} else if (!Reader.parse(res, Root) || !Root.isObject()) {
			log("connectRoom failed", "!Reader.parse(res, Root) || !Root.isObject()");
			message = "弹幕姬建立房间连接失败, 无法解析服务器响应\n服务是否存在问题?";
		} else if (Root["code"].asString() != "200") {
			log("connectRoom failed, code: " + Root["code"].asString() + ", msg: " + Root["msg"].asString());
			message = "弹幕姬建立房间连接失败, 错误码: " + Root["code"].asString() + ", 错误信息: " + Root["msg"].asString() + "\n服务是否存在问题?";
		} else if (!Root["result"].asBool()) {
			log("connectRoom failed, result: false");
			message = "弹幕姬建立房间连接失败, 返回结果为 false, 重新打开试试";
		}

		if (!message.empty()) HostMessageBox(message, "弹幕姬连接失败", 1, 0);
	}

	void Start(int id) {
		string param = '{"server":"' + server + '","id":' + formatInt(id) + '}';

		HostCreateThread(function(any@ param) {
			string data;
			if (!param.retrieve(data)) return;
			JsonReader Reader;
			JsonValue Root;
			if (!Reader.parse(data, Root) || !Root.isObject()) return;

			DanmujiManager Danmuji(Root["server"].asString());
			while (Danmuji.IsWorking()) HostSleep(1);

			Danmuji.SetWorking(true);

			HostSleep(500);
			if (Danmuji.IsConnected()) Danmuji.Disconnect();
			HostSleep(500);
			Danmuji.Connect(Root["id"].asInt());

			Danmuji.SetWorking(false);
		}, param);
	}

	void Stop() {
		HostCreateThread(function(any@ param) {
			string server;
			if (!param.retrieve(server)) return;

			DanmujiManager Danmuji(server);
			while (Danmuji.IsWorking()) HostSleep(1);

			Danmuji.SetWorking(true);
			Danmuji.Disconnect();
			Danmuji.SetWorking(false);
		}, server);
	}
}

void vodHeartBeatThread(any@ param) {
	string ids;
	if (!param.retrieve(ids)) return;

	JsonReader reader;
	JsonValue root;

	if (!reader.parse(ids, root) || !root.isObject()) return;

	int64 aid = root["aid"].asInt64();
	string bvid = root["bvid"].asString();
	int64 cid = root["cid"].asInt64();
	int64 epid = root["epid"].asInt64();
	int64 ssid = root["ssid"].asInt64();
	int64 mid = root["mid"].asInt64();

	string unixTime = GetUnixTime();

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

	post("https://api.bilibili.com/x/click-interface/web/heartbeat?w_start_ts=" + unixTime + "&w_mid=" + formatInt(mid) + "&w_aid=" + formatInt(aid), postData, headers);
}

void liveHeartBeatThread(any@ param) {
	string data;
	if (!param.retrieve(data)) return;
	JsonReader reader;
	JsonValue root;
	if (!reader.parse(data, root) || !root.isObject()) return;

	string biliJct = root["biliJct"].asString();
	int id = root["id"].asInt();

	string url = "https://api.live.bilibili.com/xlive/web-room/v1/index/roomEntryAction?csrf=" + biliJct;
	string postData = '{"room_id": ' + formatInt(id) + ',"platform":"pc"}';

	string headers =
		"Content-Type: application/json\r\n"
		"Referer: https://live.bilibili.com/" + formatInt(id) + "\r\n"
		"Origin: https://live.bilibili.com\r\n";

	string res = post(url, postData, headers);
	JsonReader Reader;
	JsonValue Root;
	if (!Reader.parse(res, Root) || !Root.isObject()) return;

	if (Root["code"].asInt() != 0) {
		HostMessageBox("直播心跳上报有误，可能需要更新 bili_jct, code: " + formatInt(Root["code"].asInt()) + ", message: " + Root["message"].asString(), "直播心跳上报有误", 2, 0);
	}
}

void vodHeartBeat() {
	string ids = GetIds();
	if (ids.isEmpty()) return;

	HostCreateThread(vodHeartBeatThread, ids);
}

void liveHeartBeat() {
	string biliJct = GetBiliJct();
	if (biliJct.isEmpty()) return;

	int id = parseInt(HostGetPlayingFileName());
	if (id <= 0) return;

	string param = '{"biliJct":"' + biliJct + '","id":' + formatInt(id) + '}';

	HostCreateThread(liveHeartBeatThread, param);
}


void PlaybackOpen(const string &in path) {
	// log("PlaybackOpen()", path);

	if (path.find("/live-bvc/") < 0) return;

	int id = parseInt(HostGetPlayingFileName());
	if (id <= 0) return;

	string server = GetDanmujiServer();
	if (server.isEmpty()) return;

	DanmujiManager(server).Start(id);
}

void PlaybackStart(const string &in path, int) {
	// log("PlaybackStart()", path);

	if (path.find("/upgcxcode/") >= 0) vodHeartBeat();
	if (path.find("/live-bvc/") >= 0) liveHeartBeat();
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

	int id = parseInt(HostRegExpParse(path, "live.bilibili.com/([0-9]+)"));
	if (id <= 0) return;

	string server = GetDanmujiServer();
	if (server.isEmpty()) return;

	DanmujiManager(server).Stop();
}

void PlaybackClose(const string &in path) {
	// log("PlaybackClose()", path);

	int id = parseInt(HostRegExpParse(path, "live.bilibili.com/([0-9]+)"));
	if (id <= 0) return;

	string server = GetDanmujiServer();
	if (server.isEmpty()) return;

	DanmujiManager(server).Stop();
}