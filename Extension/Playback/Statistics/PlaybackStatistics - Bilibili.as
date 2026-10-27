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

VodHeartbeat heartbeat;

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

string GetWebAccountUrl() {
	return "https://passport.bilibili.com/login";
}

string GetWebAccountDomain() {
	return "www.bilibili.com;bilibili.com";
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

string GetCookieValue(const string &in cookies, const string &in name) {
	array<string> fields = cookies.split(";");
	for (uint i = 0; i < fields.length(); i++) {
		string field = fields[i].Trim();
		int equals = field.find("=");
		if (equals >= 0 && field.substr(0, equals) == name) return field.substr(equals + 1);
	}
	return "";
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

			HostSleep(1000);
			if (Danmuji.IsConnected()) Danmuji.Disconnect();
			HostSleep(1000);
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

class VodHeartbeat {
	private bool playing = false;
	private uint lastTick = 0;
	private JsonValue video;
	private string startTs;

	void Start() {
		Stop();
		JsonReader reader;
		if (!reader.parse(GetIds(), video) || !video.isObject()) return;
		if (video["aid"].asInt64() == 0 && video["bvid"].asString().empty()) return;
		startTs = GetUnixTime();
		lastTick = HostGetTickCount();
		playing = true;
		Send(0);
	}

	void Pause() {
		playing = false;
		lastTick = 0;
	}

	void Resume() {
		if (startTs.empty() || playing) return;
		lastTick = HostGetTickCount();
		playing = true;
	}

	void Tick(int positionMs) {
		if (!playing) return;
		int interval = parseInt(HostLoadString("BilibiliPotPlayer.HeartBeatInterval()"));
		if (interval < 15) interval = 15;
		uint now = HostGetTickCount();
		if (uint(now - lastTick) / 1000 < uint(interval)) return;
		lastTick = now;
		Send(positionMs > 0 ? positionMs / 1000 : 0);
	}

	void Complete() {
		if (startTs.empty()) return;
		Send(-1);
		Stop();
	}

	void Stop() {
		playing = false;
		lastTick = 0;
		startTs = "";
	}

	void Send(int playedTime) {
		if (HostLoadInteger("BilibiliPotPlayer.HeartBeat()") == 0) return;

		string aid = video["aid"].asString();
		string mid = video["mid"].asString();
		string bvid = video["bvid"].asString();
		bool bangumi = video["epid"].asInt64() != 0;

		array<string> body = {
			"start_ts=" + startTs,
			"mid=" + mid,
			"cid=" + video["cid"].asString(),
			"played_time=" + formatInt(playedTime)
		};

		if (video["aid"].asInt64() != 0) body.insertLast("aid=" + aid);
		if (!bvid.empty()) body.insertLast("bvid=" + HostUrlEncode(bvid));
		if (bangumi) body.insertLast("epid=" + video["epid"].asString());
		if (video["ssid"].asInt64() != 0) body.insertLast("sid=" + video["ssid"].asString());

		string referer = bangumi ? "https://www.bilibili.com/bangumi/play/ep" + video["epid"].asString() : "https://www.bilibili.com/video/" + (bvid.empty() ? "av" + aid : bvid) + "/";
		string headers = "Content-Type: application/x-www-form-urlencoded\r\nReferer: " + referer + "\r\nOrigin: https://www.bilibili.com\r\n";

		string response = post("https://api.bilibili.com/x/click-interface/web/heartbeat", join(body, "&"), headers);

		JsonReader reader;
		JsonValue result;
		if (!reader.parse(response, result) || !result.isObject() || !result["code"].isInt()) {
			log("VOD heartbeat: invalid response");
		} else if (result["code"].asInt() != 0) {
			log("VOD heartbeat failed", result["code"].asString() + ": " + result["message"].asString());
		}
	}
}

void liveHeartBeatThread(any@ param) {
	string data;
	if (!param.retrieve(data)) return;
	JsonReader reader;
	JsonValue root;
	if (!reader.parse(data, root) || !root.isObject()) return;

	int id = root["id"].asInt();
	string biliJct = GetCookieValue(HostGetCookie(), "bili_jct");
	if (biliJct.empty()) return;

	string url = "https://api.live.bilibili.com/xlive/web-room/v1/index/roomEntryAction?csrf=" + HostUrlEncode(biliJct);
	string postData = '{"room_id": ' + formatInt(id) + ',"platform":"pc"}';

	string headers =
		"Content-Type: application/json\r\n"
		"Referer: https://live.bilibili.com/" + formatInt(id) + "\r\n"
		"Origin: https://live.bilibili.com\r\n";

	string res = post(url, postData, headers, false);
	JsonReader Reader;
	JsonValue Root;
	if (!Reader.parse(res, Root) || !Root.isObject()) return;

	if (Root["code"].asInt() != 0) {
		HostMessageBox("直播心跳上报有误，请在网页登录窗口刷新登录状态，code: " + formatInt(Root["code"].asInt()) + ", message: " + Root["message"].asString(), "直播心跳上报有误", 2, 0);
	}
}

void liveHeartBeat() {
	int id = parseInt(HostGetPlayingFileName());
	if (id <= 0) return;

	string param = '{"id":' + formatInt(id) + '}';

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

void PlaybackStart(const string &in path, int durationMs) {
	// log("PlaybackStart()", path);
	if (HostLoadInteger("BilibiliPotPlayer.HeartBeat()") == 0) return;

	if (path.find("/upgcxcode/") >= 0) heartbeat.Start();
	if (path.find("/live-bvc/") >= 0) liveHeartBeat();
}

void PlaybackTime(const string &in path, int positionMs, int durationMs) {
	heartbeat.Tick(positionMs);
}

void PlaybackPause(const string &in path) {
	// log("PlaybackPause()", path);
	heartbeat.Pause();
}

void PlaybackResume(const string &in path) {
	// log("PlaybackResume()", path);
	heartbeat.Resume();
}

void PlaybackComplete(const string &in path) {
	// log("PlaybackComplete()", path);
	heartbeat.Complete();

	int id = parseInt(HostRegExpParse(path, "live.bilibili.com/([0-9]+)"));
	if (id <= 0) return;

	string server = GetDanmujiServer();
	if (server.isEmpty()) return;

	DanmujiManager(server).Stop();
}

void PlaybackClose(const string &in path) {
	// log("PlaybackClose()", path);
	heartbeat.Stop();

	int id = parseInt(HostRegExpParse(path, "live.bilibili.com/([0-9]+)"));
	if (id <= 0) return;

	string server = GetDanmujiServer();
	if (server.isEmpty()) return;

	DanmujiManager(server).Stop();
}
