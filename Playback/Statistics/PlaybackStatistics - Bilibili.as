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
	HostPrintUTF8("[" + formatFloat(HostGetTickCount() / 1000.0, "", 3, 3) + "] - " + item);
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

void SetDanmujiServer(const string&in server) {
	HostSaveString(DANMUJI_SERVER, server);
}
string GetDanmujiServer() {
	return HostLoadString(DANMUJI_SERVER);
}


void PlaybackOpen(const string &in path) {
	// log("PlaybackOpen()", path);
}

void PlaybackStart(const string &in path, int) {
	// log("PlaybackStart()", path);
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
	log("PlaybackComplete()", path);

	string id = HostRegExpParse(path, "live.bilibili.com/([0-9]+)");
	if (id.empty()) return;

	if (!GetDanmujiServer().isEmpty() && GetDanmujiStatus()) {
		string unixTime = formatInt(DateTimeToUnixTime(FormatDateTime(datetime())));
		post(GetDanmujiServer() + "/disconnectRoom?_=" + unixTime);
	}
}

void PlaybackClose(const string &in path) {
	log("PlaybackClose()", path);

	string id = HostRegExpParse(path, "live.bilibili.com/([0-9]+)");
	if (id.empty()) return;

	if (!GetDanmujiServer().isEmpty() && GetDanmujiStatus()) {
		string unixTime = formatInt(DateTimeToUnixTime(FormatDateTime(datetime())));
		post(GetDanmujiServer() + "/disconnectRoom?_=" + unixTime);
	}
}