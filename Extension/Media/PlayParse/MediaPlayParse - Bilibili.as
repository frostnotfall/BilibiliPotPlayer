/*
	Bilibili media parse
	author: frostnotfall
	link: https://github.com/frostnotfall/BilibiliPotPlayer
	originalAuthor: chen310
	originalLink: https://github.com/chen310/BilibiliPotPlayer
*/

// void OnInitialize()
// void OnFinalize()
// string GetTitle() 									-> get title for UI
// string GetVersion									-> get version for manage
// string GetDesc()										-> get detail information
// string GetLoginTitle()								-> get title for login dialog
// string GetLoginDesc()								-> get desc for login dialog
// string GetUserText()									-> get user text for login dialog
// string GetPasswordText()								-> get password text for login dialog
// string ServerCheck(string User, string Pass)			-> server check
// string ServerLogin(string User, string Pass)			-> login
// void ServerLogout()									-> logout
// string GetWebAccountUrl()							-> login process by WebBrowser
// string GetWebAccountDomain()							-> transport cookie domain for login
// string GetConfigFile()
// void ApplyConfigFile()
//------------------------------------------------------------------------------------------------
// bool PlayitemCheck(const string &in)					-> check playitem
// array<dictionary> PlayitemParse(const string &in)	-> parse playitem
// void PlayitemCancel()								-> cancel playitem
// bool PlaylistCheck(const string &in)					-> check playlist
// array<dictionary> PlaylistParse(const string &in)	-> parse playlist
// void PlaylistCancel()								-> cancel playlist
// string GetStatus()									-> display status
// string GetBroadcastListUrl()							-> get broadcast list url
// string GetBroadcastListScript()						-> for WebView2::AddScriptToExecuteOnDocumentCreated for script process

uint status = 0;
Config ConfigData;
VideoIsUGCorPGC videoIsUGCorPGC;
dictionary ResponseCache;
string MixinKey;

const string Host = "https://api.bilibili.com";
const string ConfigFileName = "Bilibili_Config.json";
const array<string> BilibiliDomains = { "bilibili.com", "bilivideo.com", "bilivideo.cn", "smtcdns.net", "hdslb.com" };
const string Referer = "https://www.bilibili.com";
const string UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36";
const array<string> knownP2pCdnDomainPattern = {
	"302ppio",
	"302kodo",
	".mcdn.bilivideo",
	"szbdyd.com",
	".nexusedgeio.com",
	".ahdohpiechei.com",
	"upos-sz-mirror14b.bilivideo.com"
};

void OnInitialize() {
	CheckUpdate();

	for (uint i = 0; i < BilibiliDomains.length(); i++) {
		HostSetUrlUserAgentHTTP(BilibiliDomains[i], UserAgent);
		HostSetUrlRefererHTTP(BilibiliDomains[i], Referer);
	}
	string configFile = HostGetScriptFolder() + ConfigFileName;
	if (HostFileExist(configFile)) {
		ConfigData = ReadConfigFile(configFile);
		if (ConfigData.debug) HostOpenConsole();
	} else {
		HostMessageBox("配置文件不存在\n\n路径: " + configFile, "BilibiliPotPlayer", 0, 0);
	}
}

string GetTitle() {
	string title = "BiliBili @" + GetVersion();
	if (!HostFileExist(HostGetScriptFolder() + ConfigFileName)) {
		return title + "（配置文件不存在）";
	}

	Config config;
	uintptr fp = HostFileOpen(HostGetScriptFolder() + ConfigFileName);
	config.fullConfig = HostFileRead(fp, HostFileLength(fp));
	HostFileClose(fp);

	if (config.fullConfig.length() >= 3 && config.fullConfig[0] == 0xEF && config.fullConfig[1] == 0xBB && config.fullConfig[2] == 0xBF) {
		config.fullConfig = config.fullConfig.substr(3);
	}

	JsonReader reader;
	JsonValue root;
	if (!reader.parse(config.fullConfig, root) || !root.isObject()) {
		return title + "（配置文件格式错误）";
	}

	return title;
}

string GetVersion() {
	return "3.7.42";
}

string GetDesc() {
	const string GitHub_Link = "https://github.com/frostnotfall/BilibiliPotPlayer";
	const string GitHub_OriginalLink = "https://github.com/chen310/BilibiliPotPlayer";
	string info =
		"<a href=\"" + GitHub_Link + "\">BilibiliPotPlayer</a> 版本: " + GetVersion() + ""
		"\r\n"
		"教程: "
		"<a href=\"https://github.com/frostnotfall/BilibiliPotPlayer/wiki/安装与快速开始\">安装与快速开始</a>, "
		"<a href=\"https://github.com/frostnotfall/BilibiliPotPlayer/wiki/使用技巧\">使用技巧</a>\r\n"
		"\r\n"
		"基于原项目<a href=\"" + GitHub_OriginalLink + "\">BilibiliPotPlayer</a>\r\n"
		" ";
	return info;
}

string GetConfigFile() {
	return HostGetScriptFolder() + ConfigFileName;
}

void ApplyConfigFile() {
	Config config;
	uintptr fp = HostFileOpen(HostGetScriptFolder() + ConfigFileName);
	config.fullConfig = HostFileRead(fp, HostFileLength(fp));
	HostFileClose(fp);

	if (config.fullConfig.length() >= 3 && config.fullConfig[0] == 0xEF && config.fullConfig[1] == 0xBB && config.fullConfig[2] == 0xBF) {
		config.fullConfig = config.fullConfig.substr(3);
	}

	JsonReader reader;
	JsonValue root;
	if (!reader.parse(config.fullConfig, root) || !root.isObject()) {
		HostMessageBox("配置文件存在问题", "BilibiliPotPlayer", 0, 1);
	}
}

string GetWebAccountUrl() {
	return "https://passport.bilibili.com/login";
}

string GetWebAccountDomain() {
	return "www.bilibili.com;bilibili.com";
}

string GetStatus() {
	string info = "";

	switch(status) {
	case 1:
		info = "单视频检查";
		break;
	case 2:
		info = "合集检查";
		break;
	case 3:
		info = "解析视频合集";
		break;
	case 4:
		info = "解析视频信息";
		break;
	case 5:
		info = "解析真实播放地址";
		break;
	case 6:
		info = "请求空降助手接口";
		break;
	case 7:
		info = "解析真实M3U8地址";
		break;
	case 8:
		info = "解析并生成字幕";
		break;
	case 9:
		info = "解析并生成弹幕";
		break;
	default:
		info = "请等待";
	}

	return info;
}

string GetBroadcastListUrl() {
	log('GetBroadcastListUrl()');
	return "https://www.bilibili.com/;https://t.bilibili.com";
}

string GetBroadcastListScript() {
	return ReadWebScript(ConfigData.BroadcastListScript);
}

string ReadWebScript(const string &in filename) {
	if (!HostFileExist(filename)) return "";
	uintptr fp = HostFileOpen(filename);
	if (fp == 0) return "";
	string js = HostFileRead(fp, HostFileLength(fp));
	HostFileClose(fp);
	if (js.length() >= 3 && js[0] == 0xEF && js[1] == 0xBB && js[2] == 0xBF) js = js.substr(3);
	return js;
}

void OnFinalize() {
	log("OnFinalize()");
}

void PlayitemCancel() {
	log("PlayitemCancel()");
}

void PlaylistCancel() {
	log("PlaylistCancel()");
}

class VideoIsUGCorPGC {
	string url = "";
	bool isUGCSeason = false;
	bool isPGC = false;
	string pgcURL = "";
}

class ResponseCacheItem {
	string response;
	uint tick_count;
	uint valid_time;
}

class QualityListItem {
	string url;
	string quality;
	string qualityDetail;
	string resolution;
	string bitrate;
	string format;
	int itag = 0;
	double fps = 0.0;
	int type3D = 0; // 1:sbs, 2:t&b
	bool is360 = false;
	bool is180 = false; // VR180(mesh 투영).
	bool isHDR = false;
	string audioName;
	string audioCode;
	bool audioIsDefault = false;
	int bitrateVal = 0;
	int qn;
	int codecid;
	string va;
	string referer;
	bool videoIsDefault;

	dictionary toDictionary() {
		dictionary ret;

		ret["url"] = url;
		ret["quality"] = quality;
		ret["qualityDetail"] = qualityDetail;
		ret["resolution"] = resolution;
		ret["bitrate"] = bitrate;
		ret["format"] = format;
		ret["itag"] = itag;
		ret["fps"] = fps;
		ret["type3D"] = type3D;
		ret["is360"] = is360;
		ret["is180"] = is180;
		ret["isHDR"] = isHDR;
		ret["audioName"] = audioName;
		ret["audioCode"] = audioCode;
		ret["audioIsDefault"] = audioIsDefault;
		ret["bitrateVal"] = bitrateVal;
		ret["qn"] = qn;
		ret["codecid"] = codecid;
		ret["va"] = va;
		ret["referer"] = referer;
		ret["videoIsDefault"] = videoIsDefault;

		return ret;
	}
}

class Config {
	string fullConfig;

	int mid;
	int uid = 0;

	bool subtitleEnable = false;
	string subtitleServer;
	bool danmakuEnable = false;
	string danmakuServer;
	string danmakuFont;
	float danmakuFontSize = 32.0;
	float danmakuOpacity = 0.85;
	float danmakuDisplayArea = 0.8;
	float danmakuStayTime = 15.0;
	bool danmakuBold = true;
    int danmakuFontEffect = 2;
    float danmakuShadowDepth = 1.0;
    float danmakuOutlineWidth = 1.5;
    float danmakuBlurRadius = 5.0;
    bool danmakuBlockTop = false;
    bool danmakuBlockBottom = false;
    bool danmakuBlockColor = false;
    bool danmakuMergeSame = false;
    bool danmakuEnlarge = false;
    bool danmakuAutoShrink = false;
    bool danmakuAutoSelect = true;
    bool danmakuBlockRepeatedUser = false;
    bool danmakuEnableCloudBlockList = false;
    array<int> danmakuBlockRuleTypes;
    array<string> danmakuBlockRuleFilters;

	bool blockP2PCDN = true;
	int cacheValidTime = 300;
	bool enableSponsorBlock = false;
	string sponsorBlockMirror;
	bool heartBeat = false;

	int webDynamicVideoNums = 50;
	int recommendVideoNums = 30;
	int liveRecommendPage = 1;
	int historyVideoNums = 30;
	int popularAllPages = 1;
	int spaceDynamicVideoNums = 30;
	int maxliveroom = 40;

	bool showRecommendedVideos = false;
	bool showUgcSeason = true;
	bool showTrailer = true;
	bool enableVodChatUrl = false;
	bool queryPlayPosition = false;
	int heartBeatInterval = 15;

	bool useHttpStream = false;
	bool parseM3u8RealUrl = true;
	bool parseM3u8RealUrlFastMode = true;
	array<string> m3u8RedirectDomains;
	bool liveChatUrlUseWebPage = true;
	bool useBilibiliDanmuji = false;
	string bilibiliDanmujiServer;
	bool useKeyframe = false;
	bool showRecommendedLiveRooms = false;

	bool disableAVC = false;
	array<string> defaultCodec = {"hevc", "avc", "av1"};
	bool preferHDR = false;

	bool debug = false;

	string danmakuUrl;
	string subtitleUrl;

	dictionary codecNameToCodeId = { {"avc",  7}, {"hevc", 12}, {"av1",  13} };
	array<int> videoIdOrder = { 6, 16, 32, 64, 74, 80, 100, 112, 116, 120, 125, 126, 127, 129 };

	string ChatScriptVod = HostGetScriptFolder() + "Bilibili - ChatScriptVod.js";
	string ChatScriptLive = HostGetScriptFolder() + "Bilibili - ChatScriptLive.js";
	string BroadcastListScript = HostGetScriptFolder() + "Bilibili - BroadcastListScript.js";
}

Config ReadConfigFile(string file) {
	Config config;

	uintptr fp = HostFileOpen(file);
	config.fullConfig = HostFileRead(fp, HostFileLength(fp));
	HostFileClose(fp);

	if (config.fullConfig.length() >= 3 && config.fullConfig[0] == 0xEF && config.fullConfig[1] == 0xBB && config.fullConfig[2] == 0xBF) {
		config.fullConfig = config.fullConfig.substr(3);
	}

	JsonReader reader;
	JsonValue root;
	if (!reader.parse(config.fullConfig, root) || !root.isObject()) {
		HostMessageBox("配置文件存在问题", "BilibiliPotPlayer", 0, 1);
	}

	if (root["subtitle"].isObject()) {
		JsonValue subtitle = root["subtitle"];
		if (subtitle["enable"].isBool()) {
			config.subtitleEnable = subtitle["enable"].asBool();
		}
		if (subtitle["server"].isString() && !subtitle["server"].asString().empty()) {
			config.subtitleServer = subtitle["server"].asString();
		}
	}
    if (root["danmaku"].isObject()) {
        JsonValue danmaku = root["danmaku"];
        if (danmaku["enable"].isBool()) {
            config.danmakuEnable = danmaku["enable"].asBool();
        }
        if (danmaku["server"].isString() && !danmaku["server"].asString().empty()) {
            config.danmakuServer = danmaku["server"].asString();
        }
        if (danmaku["font"].isString()) {
            config.danmakuFont = danmaku["font"].asString();
        }
        if (danmaku["fontSize"].isNumeric()) {
            config.danmakuFontSize = danmaku["fontSize"].asFloat();
        }
        if (danmaku["opacity"].isNumeric()) {
            config.danmakuOpacity = danmaku["opacity"].asFloat();
        }
        if (danmaku["displayArea"].isNumeric()) {
            config.danmakuDisplayArea = danmaku["displayArea"].asFloat();
        }
        if (danmaku["stayTime"].isNumeric()) {
            config.danmakuStayTime = danmaku["stayTime"].asFloat();
        }
        if (danmaku["bold"].isBool()) {
            config.danmakuBold = danmaku["bold"].asBool();
        }
        if (danmaku["fontEffect"].isObject()) {
            JsonValue fontEffect = danmaku["fontEffect"];
            if (fontEffect["type"].isNumeric()) {
                config.danmakuFontEffect = fontEffect["type"].asInt();
                if (config.danmakuFontEffect < 0 || config.danmakuFontEffect > 4) config.danmakuFontEffect = 2;
            }
            if (fontEffect["shadowDepth"].isNumeric()) {
                config.danmakuShadowDepth = fontEffect["shadowDepth"].asFloat();
                if (config.danmakuShadowDepth < 0) config.danmakuShadowDepth = 0;
            }
            if (fontEffect["outlineWidth"].isNumeric()) {
                config.danmakuOutlineWidth = fontEffect["outlineWidth"].asFloat();
                if (config.danmakuOutlineWidth < 0) config.danmakuOutlineWidth = 0;
            }
            if (fontEffect["blurRadius"].isNumeric()) {
                config.danmakuBlurRadius = fontEffect["blurRadius"].asFloat();
                if (config.danmakuBlurRadius < 0) config.danmakuBlurRadius = 0;
            }
        }
        if (danmaku["blockTop"].isBool()) {
            config.danmakuBlockTop = danmaku["blockTop"].asBool();
        }
        if (danmaku["blockBottom"].isBool()) {
            config.danmakuBlockBottom = danmaku["blockBottom"].asBool();
        }
        if (danmaku["blockColor"].isBool()) {
            config.danmakuBlockColor = danmaku["blockColor"].asBool();
        }
        if (danmaku["mergeSameDanmaku"].isBool()) {
            config.danmakuMergeSame = danmaku["mergeSameDanmaku"].asBool();
        }
        if (danmaku["enlargeMergedDanmaku"].isBool()) {
			config.danmakuEnlarge = danmaku["enlargeMergedDanmaku"].asBool();
		}
        if (danmaku["autoShrinkDanmaku"].isBool()) {
			config.danmakuAutoShrink = danmaku["autoShrinkDanmaku"].asBool();
		}
        if (danmaku["autoSelectDanmaku"].isBool()) {
			config.danmakuAutoSelect = danmaku["autoSelectDanmaku"].asBool();
		}
        if (danmaku["blockRepeatedUserDanmaku"].isBool()) {
            config.danmakuBlockRepeatedUser = danmaku["blockRepeatedUserDanmaku"].asBool();
        }
        if (danmaku["enableCloudBlockList"].isBool()) {
            config.danmakuEnableCloudBlockList = danmaku["enableCloudBlockList"].asBool();
        }
        if (danmaku["blockRules"].isArray()) {
            JsonValue blockRules = danmaku["blockRules"];
            for (uint i = 0; i < blockRules.size(); i++) {
                JsonValue rule = blockRules[i];
                if (!rule.isObject() || !rule["type"].isNumeric() || !rule["filter"].isString()) continue;
                int type = rule["type"].asInt();
                string filter = rule["filter"].asString();
                if (type < 0 || type > 2 || filter.empty()) continue;
                config.danmakuBlockRuleTypes.insertLast(type); config.danmakuBlockRuleFilters.insertLast(filter);
            }
        }
    }

	if (root["blockP2PCDN"].isBool()) {
		config.blockP2PCDN = root["blockP2PCDN"].asBool();
	}
	if (root["cacheValidTime"].isNumeric()) {
		config.cacheValidTime = root["cacheValidTime"].asInt();
	}
	if (root["enableSponsorBlock"].isBool()) {
		config.enableSponsorBlock = root["enableSponsorBlock"].asBool();
	}
	if (root["sponsorBlockMirror"].isString()) {
		config.sponsorBlockMirror = root["sponsorBlockMirror"].asString();
	}
	if (root["heartBeat"].isBool()) {
		config.heartBeat = (root["heartBeat"].asBool());
	}
	HostSaveInteger("BilibiliPotPlayer.HeartBeat()", config.heartBeat ? 1 : 0);

	if (root["videoNums"].isObject()) {
		JsonValue videoNums = root["videoNums"];
		if (videoNums["webDynamicVideoNums"].isNumeric()) {
			config.webDynamicVideoNums = videoNums["webDynamicVideoNums"].asInt();
		}
		if (videoNums["recommendVideoNums"].isNumeric()) {
			config.recommendVideoNums = videoNums["recommendVideoNums"].asInt();
		}
		if (videoNums["liveRecommendPage"].isNumeric()) {
			config.liveRecommendPage = videoNums["liveRecommendPage"].asInt();
		}
		if (videoNums["historyVideoNums"].isNumeric()) {
			config.historyVideoNums = videoNums["historyVideoNums"].asInt();
		}
		if (videoNums["popularAllPages"].isNumeric()) {
			config.popularAllPages = videoNums["popularAllPages"].asInt();
		}
		if (videoNums["spaceDynamicVideoNums"].isNumeric()) {
			config.spaceDynamicVideoNums = videoNums["spaceDynamicVideoNums"].asInt();
		}
		if (videoNums["maxliveroom"].isNumeric()) {
			config.maxliveroom = videoNums["maxliveroom"].asInt();
		}
	}

	if (root["vod"].isObject()) {
		JsonValue vod = root["vod"];

		if (vod["showRecommendedVideos"].isBool()) {
			config.showRecommendedVideos = vod["showRecommendedVideos"].asBool();
		}
		if (vod["showUgcSeason"].isBool()) {
			config.showUgcSeason = vod["showUgcSeason"].asBool();
		}
		if (vod["showTrailer"].isBool()) {
			config.showTrailer = vod["showTrailer"].asBool();
		}
		if (vod["enableVodChatUrl"].isBool()) {
			config.enableVodChatUrl = vod["enableVodChatUrl"].asBool();
		}
		if (vod["queryPlayPosition"].isBool()) {
			config.queryPlayPosition = vod["queryPlayPosition"].asBool();
		}
		if (vod["heartBeatInterval"].isNumeric()) {
			config.heartBeatInterval = vod["heartBeatInterval"].asInt();
		}
	}
	if (config.heartBeatInterval < 15) config.heartBeatInterval = 15;
	HostSaveString("BilibiliPotPlayer.HeartBeatInterval()", formatInt(config.heartBeatInterval));

	if (root["live"].isObject()) {
		JsonValue live = root["live"];

		if (live["useHttpStream"].isBool()) {
			config.useHttpStream = live["useHttpStream"].asBool();
		}

		if (live["parseM3u8RealUrl"].isObject()) {
			JsonValue parseM3u8RealUrl = live["parseM3u8RealUrl"];

			if (parseM3u8RealUrl["enable"].isBool()) {
				config.parseM3u8RealUrl = parseM3u8RealUrl["enable"].asBool();

				if ( parseM3u8RealUrl["fastMode"].isBool() ) {
					config.parseM3u8RealUrlFastMode = parseM3u8RealUrl["fastMode"].asBool();
				}
				if ( config.parseM3u8RealUrl && parseM3u8RealUrl["m3u8RedirectDomains"].size() > 0 ) {
					for (uint i = 0; i < parseM3u8RealUrl["m3u8RedirectDomains"].size(); i++) {
						config.m3u8RedirectDomains.insertLast(parseM3u8RealUrl["m3u8RedirectDomains"][i].asString());
					}
				}
			}
		}

		if (live["liveChatUrl"].isObject()) {
			JsonValue liveChatUrl = live["liveChatUrl"];

			if (liveChatUrl["useWebPage"].isBool()) {
				config.liveChatUrlUseWebPage = liveChatUrl["useWebPage"].asBool();
			}
			if (liveChatUrl["useBilibiliDanmuji"].isBool()) {
				config.useBilibiliDanmuji = liveChatUrl["useBilibiliDanmuji"].asBool();
			}
			if (config.useBilibiliDanmuji && liveChatUrl["bilibiliDanmujiServer"].isString() && !liveChatUrl["bilibiliDanmujiServer"].asString().isEmpty()) {
				config.bilibiliDanmujiServer = liveChatUrl["bilibiliDanmujiServer"].asString();
				HostSaveString("BilibiliPotPlayer.DanmujiServer()", config.bilibiliDanmujiServer);
			}
		}
		if (live["useKeyframe"].isBool()) {
			config.useKeyframe = live["useKeyframe"].asBool();
		}
		if (live["showRecommendedLiveRooms"].isBool()) {
			config.showRecommendedLiveRooms = live["showRecommendedLiveRooms"].asBool();
		}
	}

	if (root["disableAVC"].isBool()) {
		config.disableAVC = root["disableAVC"].asBool();
	}
	if (root["defaultCodec"].isArray() && root["defaultCodec"].size() > 0) {
		config.defaultCodec.resize(0);
		for (uint i = 0; i < root["defaultCodec"].size(); i++) {
			config.defaultCodec.insertLast(root["defaultCodec"][i].asString());
		}
	}
	if (root["preferHDR"].isBool()) {
		config.preferHDR = root["preferHDR"].asBool();
		if (config.preferHDR) {
			config.videoIdOrder = { 6, 16, 32, 64, 74, 80, 100, 112, 116, 120, 127, 125, 126, 129 };
		}
	}

	if (root["debug"].isBool()) {
		config.debug = root["debug"].asBool();
	}

	if (!config.danmakuServer.empty()) {
		config.danmakuUrl = config.danmakuServer + "/subtitle?font=" + HostUrlEncode(config.danmakuFont) + "&font_size=" + config.danmakuFontSize + "&alpha=" + config.danmakuOpacity + "&display_area=" + config.danmakuDisplayArea + "&duration_marquee=" + config.danmakuStayTime + "&duration_still=" + config.danmakuStayTime + "&cid=";
		config.subtitleUrl = config.danmakuServer + "/subtitle?url=";
	}

	return config;
}

void log(string item) {
	if (!ConfigData.debug) return;
	HostPrintUTF8("[" + formatFloat(HostGetTickCount() / 1000.0, "", 3, 3) + "] - " + item);
}

void log(string item, string info) {
	log(item + ": " + info);
}

void log(string item, int info) {
	log(item + ": " + info);
}

void log(string item, int64 info) {
	log(item + ": " + info);
}

void log(string item, uint info) {
	log(item + ": " + info);
}

void log(string item, float info) {
	log(item + ": " + info);
}

void log(string item, double info) {
	log(item + ": " + info);
}

void log(string item, bool info) {
	log(item + ": " + info);
}

void log(string item, dictionaryValue value) {
	if (value.isString()) log(item, string(value));
	else if (value.isInt()) log(item, int(value));
	else if (value.isDouble()) log(item, double(value));
	else if (value.isBool()) log(item, bool(value));
	else if (value.isDictionary()) log(item, dictionary(value));
	else log(item + ": <unknown>");
}

void log(string item, const dictionary&in dict) {
	string result = "{\n";
	array<string>@ keys = dict.getKeys();

	for (uint i = 0; i < keys.length(); i++) {
		string key = keys[i];
		result += "    \"" + key + "\": ";
		dictionaryValue value = dict[key];

		if (value.isString())
			result += "\"" + string(value) + "\"";
		else if (value.isInt())
			result += "" + int64(value);
		else if (value.isDouble())
			result += "" + double(value);
		else if (value.isBool())
			result += bool(value) ? "true" : "false";
		else if (value.isDictionary())
			result += "<dictionary>";
		else if (value.isArray())
			result += "<array>";
		else
			result += "<unknown>";

		if (i + 1 < keys.length())
			result += ",";

		result += "\n";
	}

	result += "}";
	log(item, result);
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

string UnixTimeToDateTime(int64 t) {
    t += 8 * 3600; // UTC -> UTC+8

    int64 d = t / 86400;
    int s = int(t % 86400);

    int y = 1970, m = 1, md;

    while (true) {
        int dy = ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0) ? 366 : 365;
        if (d < dy) break;
        d -= dy;
        y++;
    }

    bool leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

    while (true) {
        md = m == 2 ? (leap ? 29 : 28) : (m == 4 || m == 6 || m == 9 || m == 11 ? 30 : 31);
        if (d < md) break;
        d -= md;
        m++;
    }

    int h = s / 3600;
    int min = s % 3600 / 60;
    s %= 60;

    return formatInt(y) + "-" + formatInt(m + 100).substr(1) + "-" + formatInt(int(d) + 101).substr(1) + " " + formatInt(h + 100).substr(1) + ":" + formatInt(min + 100).substr(1) + ":" + formatInt(s + 100).substr(1);
}

void CheckUpdate() {
    HostCreateThread(function(any@ param) {
        const string api = "https://api.github.com/repos/frostnotfall/BilibiliPotPlayer/releases/latest";
        const string headers = "Accept: application/vnd.github+json\r\nUser-Agent: BilibiliPotPlayer\r\n";

        array<string> mirrors = {
			"https://cors.isteed.cc",
			"https://dockerproxy.link",
			"https://dockerproxy.net",
			"https://gh-proxy.com",
			"https://ghfast.top",
			"https://ghproxy.net",
			"https://mirror.houlang.cloud",
			"https://proxy.vvvv.ee"
        };

        string latestVersion;

        for (int i = -1; i < int(mirrors.length()); i++) {
            string url = i < 0 ? api : mirrors[i] + "/" + api;
            string response = post(url, "", headers, false);
            if (response.empty()) continue;

            JsonReader reader;
            JsonValue root;
            if (reader.parse(response, root) && root.isObject() && root["tag_name"].isString()) {
                latestVersion = root["tag_name"].asString();
                if (!latestVersion.empty()) break;
            }
        }

        if (latestVersion.empty()) return;

        string currentVersion = GetVersion();

        if (latestVersion.length() > 0 && (latestVersion[0] == 118 || latestVersion[0] == 86))
            latestVersion = latestVersion.substr(1);
        if (currentVersion.length() > 0 && (currentVersion[0] == 118 || currentVersion[0] == 86))
            currentVersion = currentVersion.substr(1);

        array<string> latest = latestVersion.split(".");
        array<string> current = currentVersion.split(".");
        uint count = latest.length() > current.length() ? latest.length() : current.length();

        for (uint i = 0; i < count; i++) {
            int a = i < latest.length() ? parseInt(latest[i]) : 0;
            int b = i < current.length() ? parseInt(current[i]) : 0;

            if (a < b) return;
            if (a > b) {
                HostMessageBox("发现新版本：" + latestVersion + "\n当前版本：" + currentVersion + "\n\n是否打开项目 Releases 页面？", "BilibiliPotPlayer", 2, 4,
                    function(int result) {
                        if (result == 1) HostExecuteProgram("explorer.exe", "https://github.com/frostnotfall/BilibiliPotPlayer/releases");
                    }
                );
                return;
            }
        }
    }, 0);
}

void SetIds(const int64&in aid, const string&in bvid, const int64&in cid, const int64&in epid, const int64&in ssid, const int64&in mid) {
	string ids = '{"aid": ' + formatInt(aid) + ',"bvid": "' + bvid + '","cid": ' + formatInt(cid) + ',"epid": ' + formatInt(epid) + ',"ssid": ' + formatInt(ssid) + ',"mid": ' + formatInt(mid) + '}';
	HostSaveString("BilibiliPotPlayer.Ids()", ids);
}

string post(string url, string data = "", string headers = "", bool debug = true) {
	if (headers.empty()) headers = "User-Agent: " + UserAgent + "\r\n" + "Referer: " + Referer + "\r\n";

	uint start = HostGetTickCount();
	string res =  HostUrlGetString(url, "", headers, data);
	uint end = HostGetTickCount();
	HostIncTimeOut(end - start);

	if (debug) log("Request time: " + formatFloat((end - start) / 1000.0, "", 3, 3) + "s" + ", url: " + url);

	return res;
}

string apiPost(string api, bool useCache = true, bool isProtobuf = false) {
	return apiPost(api, "", Host, "", useCache, isProtobuf);
}

string apiPost(string api, string data, bool useCache = true, bool isProtobuf = false) {
	return apiPost(api, data, Host, "", useCache, isProtobuf);
}

string apiPost(string api, string data, string host, bool useCache = true, bool isProtobuf = false) {
	return apiPost(api, data, host, "", useCache, isProtobuf);
}

string apiPost(string api, string data, string host, string headers, bool useCache = true, bool isProtobuf = false) {
	ResponseCacheItem item;
	bool debug = true;
	string key;
	string cacheStatus = "";

	if (useCache) {
		debug = false;
		key = HostRegExpRemove(HostRegExpRemove(api, "&w_rid=[^&]*"), "&wts=[^&]*");

		if (!data.empty()) {
			key += "?" + data;
		}

		key = (isProtobuf ? "protobuf:" : "json:") + host + key;

		if (ResponseCache.get(key, item)) {
			if (HostGetTickCount() - item.tick_count <= item.valid_time) {
				log("Cache Hit, url", host + api);
				return item.response;
			} else {
				cacheStatus = "Cache expire";
			}
		} else {
			cacheStatus = "Cache not Hit";
		}
	}

	uint start = HostGetTickCount();
	string resp = post(host + api, data, headers, debug);
	uint end = HostGetTickCount();

	if (!cacheStatus.empty()) {
		log(cacheStatus + ", request time: " + formatFloat((end - start) / 1000.0, "", 3, 3) + "s, url: " + host + api);
	}

	if (!isProtobuf) {
		if (resp.empty()) {
			HostMessageBox("未获取到响应数据，请等待一段时间后重试一下\n\nurl: " + host + api, "BilibiliPotPlayer");
			return "";
		}

		JsonReader Reader;
		JsonValue Root;
		if (!Reader.parse(resp, Root) || !Root.isObject()) {
			HostMessageBox("未能解析响应数据\nurl: " + host + api, "BilibiliPotPlayer");
			return "";
		}
		if (Root["code"].asInt() != 0) {
			log("error code: " + Root["code"].asInt() + ", error message: " + Root["message"].asString() + ", url:" + host + api);
			HostMessageBox("error code: " + Root["code"].asInt() + "\nerror message: " + Root["message"].asString() + "\n\nurl:" + host + api, "BilibiliPotPlayer");
			return "";
		}
	}

	if (useCache) {
		item.response = resp;
		item.tick_count = HostGetTickCount();
		item.valid_time = ConfigData.cacheValidTime * 1000;
		ResponseCache[key] = item;
	}

	return resp;
}

string getMixinKey() {
	JsonReader Reader;
	JsonValue Root;
	string key = "";
	string res = apiPost("/x/web-interface/nav");
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].isInt()) {
			if (Root["code"].asInt() == 0) {
				ConfigData.mid = Root["data"]["mid"].asInt64();
				JsonValue wbi_img = Root["data"]["wbi_img"];
				string img_url = wbi_img["img_url"].asString();
				string sub_url = wbi_img["sub_url"].asString();
				array<string> parts = img_url.split("/");
				string img_value = parts[parts.length() - 1].split(".")[0];
				parts = sub_url.split("/");
				string sub_value = parts[parts.length() - 1].split(".")[0];
				string ae = img_value + sub_value;
				array<int> oe = { 46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52 };
				for (uint i = 0; i < oe.length(); i++) {
					key += ae.substr(oe[i], 1);
				}
			} else {
				HostMessageBox("error code: " + Root["code"].asInt() + "\n" + "error message: " + Root["message"].asString(), "BilibiliPotPlayer", 0, 0);
			}
		}
	}
	return key.substr(0, 32);
}

string encWbi(string params, bool useWts = true) {
	if (MixinKey.empty()) {
		MixinKey = getMixinKey();
	}

	array<string> lst;
	if (!params.empty()) {
		lst = params.split("&");
	}

	lst.sortAsc();
	string requestParams = join(lst, "&");

	string wtsParam;
	if (useWts) {
		wtsParam = "wts=" + formatInt( DateTimeToUnixTime(FormatDateTime(datetime())) );
		lst.insertLast(wtsParam);
		lst.sortAsc();
	}

	string signParams = join(lst, "&");
	string w_rid = HostHashMD5(signParams + MixinKey);

	if (!requestParams.empty()) requestParams += "&";
	requestParams += "w_rid=" + w_rid;
	if (useWts) requestParams += "&" + wtsParam;

	return requestParams;
}

string makeWebUrl(string path) {
	array<string> strs = path.split("?");
	if (strs.length() <= 1) {
		return path;
	}

	string url = strs[0];
	string p = parse(path, "p");
	string t = parse(path, "t");

	string query = "";

	if (!t.empty()) {
		query += "t=" + t;
	}

	if (!p.empty() && p != "0" && p != "1") {
		if (!query.empty()) {
			query += "&";
		}
		query += "p=" + p;
	}

	if (query.empty()) {
		return url;
	}

	return url + "?" + query;
}

string parse(string url, string key, string defaultValue = "") {
	string value = HostRegExpParse(url, "\\?" + key + "=([^&]+)");
	if (!value.empty()) {
		return value;
	}
	value = HostRegExpParse(url, "&" + key + "=([^&]+)");
	if (!value.empty()) {
		return value;
	}

	value = defaultValue;
	return value;
}

string parseBVId(string url) {
	return HostRegExpParse(url, "(BV[a-zA-Z0-9]+)");
}

string parseAVId(string url) {
	return HostRegExpParse(url, "av([0-9]+)");
}

string parseEPId(string url) {
	return HostRegExpParse(url, "ep([0-9]+)");
}

string parseSSId(string url) {
	return HostRegExpParse(url, "ss([0-9]+)");
}

string parseMDId(string url) {
	return HostRegExpParse(url, "md([0-9]+)");
}

string parseFid(string path) {
	string fid = parse(path, "fid");
	if (fid.empty()) {
		fid = parse(path, "searchFid");
	}
	if (fid.empty()) {
		fid = HostRegExpParse(path, "/medialist/detail/ml([0-9]+)");
	}
	return fid;
}

string md2ss(string mdid) {
	JsonReader Reader;
	JsonValue Root;
	string ssid = "";
	string res = apiPost("/pgc/review/user?media_id=" + mdid);
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() == 0) {
			ssid = Root["result"]["media"]["season_id"].asString();
		}
	}
	return ssid;
}

uint gettid(string path) {
	array<string> urls = { 'www.bilibili.com/v/anime/serial', 'www.bilibili.com/v/anime/finish', 'www.bilibili.com/v/anime/information', 'www.bilibili.com/v/anime/offical', 'www.bilibili.com/anime', 'www.bilibili.com/movie', 'www.bilibili.com/v/guochuang/chinese', 'www.bilibili.com/v/guochuang/original', 'www.bilibili.com/v/guochuang/puppetry', 'www.bilibili.com/v/guochuang/motioncomic', 'www.bilibili.com/v/guochuang/information', 'www.bilibili.com/guochuang', 'www.bilibili.com/tv', 'www.bilibili.com/documentary', 'www.bilibili.com/v/douga/mad', 'www.bilibili.com/v/douga/mmd', 'www.bilibili.com/v/douga/voice', 'www.bilibili.com/v/douga/garage_kit', 'www.bilibili.com/v/douga/tokusatsu', 'www.bilibili.com/v/douga/acgntalks', 'www.bilibili.com/v/douga/other', 'www.bilibili.com/v/douga', 'www.bilibili.com/v/game/stand_alone', 'www.bilibili.com/v/game/esports', 'www.bilibili.com/v/game/mobile', 'www.bilibili.com/v/game/online', 'www.bilibili.com/v/game/board', 'www.bilibili.com/v/game/gmv', 'www.bilibili.com/v/game/music', 'www.bilibili.com/v/game/mugen', 'www.bilibili.com/v/game', 'www.bilibili.com/v/kichiku/guide', 'www.bilibili.com/v/kichiku/mad', 'www.bilibili.com/v/kichiku/manual_vocaloid', 'www.bilibili.com/v/kichiku/theatre', 'www.bilibili.com/v/kichiku/course', 'www.bilibili.com/v/kichiku', 'www.bilibili.com/v/music/original', 'www.bilibili.com/v/music/cover', 'www.bilibili.com/v/music/perform', 'www.bilibili.com/v/music/vocaloid', 'www.bilibili.com/v/music/live', 'www.bilibili.com/v/music/mv', 'www.bilibili.com/v/music/commentary', 'www.bilibili.com/v/music/tutorial', 'www.bilibili.com/v/music/other', 'www.bilibili.com/v/music', 'www.bilibili.com/v/dance/otaku', 'www.bilibili.com/v/dance/hiphop', 'www.bilibili.com/v/dance/star', 'www.bilibili.com/v/dance/china', 'www.bilibili.com/v/dance/three_d', 'www.bilibili.com/v/dance/demo', 'www.bilibili.com/v/dance', 'www.bilibili.com/v/cinephile/cinecism', 'www.bilibili.com/v/cinephile/montage', 'www.bilibili.com/v/cinephile/shortfilm', 'www.bilibili.com/v/cinephile/trailer_info', 'www.bilibili.com/v/cinephile', 'www.bilibili.com/v/ent/variety', 'www.bilibili.com/v/ent/talker', 'www.bilibili.com/v/ent/fans', 'www.bilibili.com/v/ent/celebrity', 'www.bilibili.com/v/ent', 'www.bilibili.com/v/knowledge/science', 'www.bilibili.com/v/knowledge/social_science', 'www.bilibili.com/v/knowledge/humanity_history', 'www.bilibili.com/v/knowledge/business', 'www.bilibili.com/v/knowledge/campus', 'www.bilibili.com/v/knowledge/career', 'www.bilibili.com/v/knowledge/design', 'www.bilibili.com/v/knowledge/skill', 'www.bilibili.com/v/knowledge', 'www.bilibili.com/v/tech/digital', 'www.bilibili.com/v/tech/application', 'www.bilibili.com/v/tech/computer_tech', 'www.bilibili.com/v/tech/industry', 'www.bilibili.com/v/tech', 'www.bilibili.com/v/information/hotspot', 'www.bilibili.com/v/information/global', 'www.bilibili.com/v/information/social', 'www.bilibili.com/v/information/multiple', 'www.bilibili.com/v/information', 'www.bilibili.com/v/food/make', 'www.bilibili.com/v/food/detective', 'www.bilibili.com/v/food/measurement', 'www.bilibili.com/v/food/rural', 'www.bilibili.com/v/food/record', 'www.bilibili.com/v/food', 'www.bilibili.com/v/life/funny', 'www.bilibili.com/v/life/parenting', 'www.bilibili.com/v/life/travel', 'www.bilibili.com/v/life/rurallife', 'www.bilibili.com/v/life/home', 'www.bilibili.com/v/life/handmake', 'www.bilibili.com/v/life/painting', 'www.bilibili.com/v/life/daily', 'www.bilibili.com/v/life', 'www.bilibili.com/v/car/racing', 'www.bilibili.com/v/car/modifiedvehicle', 'www.bilibili.com/v/car/newenergyvehicle', 'www.bilibili.com/v/car/touringcar', 'www.bilibili.com/v/car/motorcycle', 'www.bilibili.com/v/car/strategy', 'www.bilibili.com/v/car/life', 'www.bilibili.com/v/car', 'www.bilibili.com/v/fashion/makeup', 'www.bilibili.com/v/fashion/cos', 'www.bilibili.com/v/fashion/clothing', 'www.bilibili.com/v/fashion/trend', 'www.bilibili.com/v/fashion', 'www.bilibili.com/v/sports/basketball', 'www.bilibili.com/v/sports/football', 'www.bilibili.com/v/sports/aerobics', 'www.bilibili.com/v/sports/athletic', 'www.bilibili.com/v/sports/culture', 'www.bilibili.com/v/sports/comprehensive', 'www.bilibili.com/v/sports', 'www.bilibili.com/v/animal/cat', 'www.bilibili.com/v/animal/dog', 'www.bilibili.com/v/animal/reptiles', 'www.bilibili.com/v/animal/wild_animal', 'www.bilibili.com/v/animal/second_edition', 'www.bilibili.com/v/animal/animal_composite', 'www.bilibili.com/v/animal', 'www.bilibili.com/v/life/funny', 'www.bilibili.com/v/game/stand_alone' };
	array<uint> tids = { 33, 32, 51, 152, 13, 23, 153, 168, 169, 195, 170, 167, 11, 177, 24, 25, 47, 210, 86, 253, 27, 1, 17, 171, 172, 65, 173, 121, 136, 19, 4, 22, 26, 126, 216, 127, 119, 28, 31, 59, 30, 29, 193, 243, 244, 130, 3, 20, 198, 199, 200, 154, 156, 129, 182, 183, 85, 184, 181, 71, 241, 242, 137, 5, 201, 124, 228, 207, 208, 209, 229, 122, 36, 95, 230, 231, 232, 188, 203, 204, 205, 206, 202, 76, 212, 213, 214, 215, 211, 138, 254, 250, 251, 239, 161, 162, 21, 160, 245, 246, 246, 248, 240, 227, 176, 223, 157, 252, 158, 159, 155, 235, 249, 164, 236, 237, 238, 234, 218, 219, 222, 221, 220, 75, 217, 138, 17 };
	// array<string> names = { '连载动画', '完结动画', '资讯', '官方延伸', '番剧', '电影', '国产动画', '国产原创相关', '布袋戏', '动态漫·广播剧', '资讯', '国创', '电视剧', '纪录片', 'MAD·AMV', 'MMD·3D', '短片·手书·配音', '手办·模玩', '特摄', '动漫杂谈', '综合', '动画', '单机游戏', '电子竞技', '手机游戏', '网络游戏', '桌游棋牌', 'GMV', '音游', 'Mugen', '游戏', '鬼畜调教', '音MAD', '人力VOCALOID', '鬼畜剧场', '教程演示', '鬼畜', '原创音乐', '翻唱', '演奏', 'VOCALOID·UTAU', '音乐现场', 'MV', '乐评盘点', '音乐教学', '音乐综合', '音乐', '宅舞', '街舞', '明星舞蹈', '中国舞', '舞蹈综合', '舞蹈教程', '舞蹈', '影视杂谈', '影视剪辑', '小剧场', '预告·资讯', '影视', '综艺', '娱乐杂谈', '粉丝创作', '明星综合', '娱乐', '科学科普', '社科·法律·心理', '人 文历史', '财经商业', '校园学习', '职业职场', '设计·创意', '野生技能协会', '知识', '数码', '软件应用', '计算机技术', '科 工机械', '科技', '热点', '环球', '社会', '综合', '资讯', '美食制作', '美食侦探', '美食测评', '田园美食', '美食记录', '美食', '搞笑', '亲子', '出行', '三农', '家居房产', '手工', '绘画', '日常', '生活', '赛车', '改装玩车', '新能源车', '房车', '摩托车', '购车攻略', '汽车生活', '汽车', '美妆护肤', '仿妆cos', '穿搭', '时尚潮流', '时尚', '篮球', '足球', '健身', ' 竞技体育', '运动文化', '运动综合', '运动', '喵星人', '汪星人', '小宠异宠', '野生动物', '动物二创', '动物综合', '动物圈', '搞笑', '单机游戏' };
	for (uint i = 0; i < urls.size(); i++) {
		if (path.find(urls[i]) >= 0) {
			return tids[i];
		}
	}
	return 0;
}

int parseTime(string s) {
	array<string> strs = s.split(":");
	int t = 0;
	if (strs.length() == 1) {
		t = parseInt(strs[0]) * 1000;
	} else if (strs.length() == 2) {
		t = (parseInt(strs[0]) * 60 + parseInt(strs[1])) * 1000;
	} else if (strs.length() == 3) {
		t = (parseInt(strs[0]) * 3600 + parseInt(strs[1]) * 60 + parseInt(strs[2])) * 1000;
	}
	return t;
}

int GetStartSeconds(const string &in path, const string &in aid, const string &in cid, const string &in epid = "") {
	string source = path.split("#")[0];
	double seconds = 0;
	if (!HostRegExpParse(source, "([?&]t=)").empty()) {
		string t = HostUrlDecode(parse(source, "t"));
		seconds = parseFloat(HostRegExpParse(t, "^([0-9]+(?:\\.[0-9]+)?)$"));
	} else {
		if (!ConfigData.queryPlayPosition || aid.empty() || cid.empty()) return 0;
		string params = "aid=" + aid + "&cid=" + cid;
		if (!epid.empty()) params += "&ep_id=" + epid;
		string res = post(Host + "/x/player/wbi/v2?" + encWbi(params), "", "", false);
		JsonReader reader;
		JsonValue root;
		if (!reader.parse(res, root) || !root.isObject() || root["code"].asInt() != 0 || !root["data"].isObject()) return 0;
		if (root["data"]["last_play_cid"].asString() != cid) return 0;
		seconds = root["data"]["last_play_time"].asDouble() / 1000;
	}
	return seconds > 0 && seconds <= 2147483647.0 ? int(seconds) : 0;
}

int getVideoItag(int id, int codecid) {
	array<array<int>> videoItagMap = {
		// 360P
		{16,  7,  160},
		{16,  12, 160},
		{16,  13, 394},
		// 480P
		{32,  7,  133},
		{32,  12,  133},
		{32,  13, 395},
		// 720P
		{64,  7,  134},
		{64,  12,  134},
		{64,  13,  396},
		// 高清 1080P
		{80,  7,  135},
		{80,  12, 135},
		{80,  13, 397},
		// 高清 1080P+ 高帧率
		{112, 7,  136},
		{112, 12, 136},
		{112, 13, 398},
		// 1080P60 高帧率
		{116, 7,  298},
		{116, 12, 299},
		{116, 13, 304},
		// 超清 4K
		{120, 7,  266},
		{120, 12, 266},
		{120, 13, 401},
		// HDR
		{125, 7,  337},
		{125, 12, 337},
		{125, 13, 701},
		// 杜比视界
		{126, 7,  337},
		{126, 12, 337},
		{126, 13, 702},
		// 8K
		{127, 7,  402},
		{127, 12, 402},
		{127, 13, 571},
		// HDR Vivid
		{129, 7,  337},
		{129, 12, 337},
		{129, 13, 702}
	};

	for (int i = 0; i < videoItagMap.size(); i++) {
		if (videoItagMap[i][0] == id && videoItagMap[i][1] == codecid) {
			return videoItagMap[i][2];
		}
	}

	return 0;
}

int getAudioItag(int id) {
	array<int> ids = { 30251, 30250, 30280, 30232, 30216 };
	array<int> itags = { 380, 328, 327, 256, 139 };
	int idx = ids.find(id);
	if (idx >= 0) {
		return itags[idx];
	}
	return id;
}

uint getUniItag() {
	uint itag = 1;
	while (HostExistITag(itag)) itag++;
	HostSetITag(itag);
	return itag;
}

string getCodec(int codecid) {
	array<int> codecids = { 7, 12, 13 };
	array<string> codec = { "avc", "hevc", "av1" };
	int idx = codecids.find(codecid);
	if (idx >= 0) {
		return codec[idx];
	}
	return "未知";
}

string GetM3u8RealURL(string url) {
	if ( ConfigData.parseM3u8RealUrlFastMode && !ConfigData.m3u8RedirectDomains.isEmpty()) {
		bool matched = false;

		for (uint j = 0; j < ConfigData.m3u8RedirectDomains.size(); j++) {
			if (url.find(ConfigData.m3u8RedirectDomains[j]) >= 0) {
				matched = true;
				break;
			}
		}

		if (!matched) {
			return url;
		}
	}

	string resp = post(url, "", "", false);
	array<string> lines = resp.split("\n");

	for (uint j = 0; j + 1 < lines.size(); j++) {
		string line = lines[j].Trim();
		if (line.find("#EXT-X-STREAM-INF:") != 0) continue;
		bool found = false;
		for (uint k = 0; k < ConfigData.m3u8RedirectDomains.size(); k++) {
			if (lines[j + 1].Trim().find(ConfigData.m3u8RedirectDomains[k]) >= 0) {
				found = true;
				break;
			}
		}
		if (!found) log("!-------------------found redirect m3u8, origin url", url);
		return lines[j + 1].Trim();
	}

	return url;
}

bool isPlaylist(const string&in path) {
	videoIsUGCorPGC = VideoIsUGCorPGC();
	videoIsUGCorPGC.url = makeWebUrl(path);
	string bvid = parseBVId(path);
	string aid = parseAVId(path);
	string query = HostRegExpParse(path, "^[^?#]*\\?([^#]*)");

	array<string> queryParts;
	if (!bvid.empty()) queryParts.insertLast("bvid=" + bvid);
	if (!aid.empty()) queryParts.insertLast("aid=" + aid);

	string params = join(queryParts, "&");
	if (params.empty()) return false;

	string res = apiPost("/x/web-interface/wbi/view/detail?" + encWbi(params));

	JsonReader Reader;
	JsonValue Root;
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() == 0) {
			JsonValue redirect_url = Root["data"]["View"]["redirect_url"];
			if (redirect_url.isString() && redirect_url.asString().find("bangumi/play/ep") >= 0) {
				videoIsUGCorPGC.isPGC = true;
				string redirect = redirect_url.asString();
				if (!query.empty()) redirect += (redirect.find("?") >= 0 ? "&" : "?") + query;
				videoIsUGCorPGC.pgcURL = makeWebUrl(redirect);
				return true;
			}
			if (Root["data"]["View"]["ugc_season"].isObject()) {
				videoIsUGCorPGC.isUGCSeason = true;
				return true;
			} else if (Root["data"]["View"]["pages"].size() > 1) {
				videoIsUGCorPGC.isUGCSeason = true;
				return true;
			}
		} else {
			log("Video view API code != 0", Root["code"].asInt());
			log("Video view API message", Root["message"].asString());
		}
	}
	return false;
}

bool isP2PCDN(const string&in url) {
	if (parse(url, "os") == "mcdn") return true;

	array<string> parts = url.split("://");
	string hostname = parts.length() > 1 ? parts[1] : parts[0];

	int pos = hostname.findFirst("/");
	if (pos >= 0)
		hostname = hostname.substr(0, pos);

	pos = hostname.findFirst("?");
	if (pos >= 0)
		hostname = hostname.substr(0, pos);

	pos = hostname.findFirst("#");
	if (pos >= 0)
		hostname = hostname.substr(0, pos);

	pos = hostname.findFirst(":");
	if (pos >= 0)
		hostname = hostname.substr(0, pos);

	for (uint i = 0; i < knownP2pCdnDomainPattern.length(); i++) {
		if (hostname.find(knownP2pCdnDomainPattern[i]) >= 0) {
			return true;
		}
	}

	string subdomain = hostname.split(".")[0];
	return subdomain.find("302") >= 0;
}

array<dictionary> generateChapter(JsonValue&in chapterData, const string&in bvid, const float duration, bool isPGC) {
	array<dictionary> chapter;
	if (isPGC && chapterData.isObject()) {
		dictionary item;
		if (chapterData["op"].isObject() && chapterData["op"]["end"].asInt() != 0) {
			item["title"] = "开场动画";
			item["time"] = formatFloat(chapterData["op"]["start"].asFloat() * 1000, "", 32, 0);
			chapter.insertLast(item);

			item["title"] = "正片";
			item["time"] = formatFloat(chapterData["op"]["end"].asFloat() * 1000, "", 32, 0);
			chapter.insertLast(item);
		}
		if (chapterData["ed"].isObject() && chapterData["ed"]["start"].asInt() != 0 && chapterData["ed"]["end"].asInt() != 0) {
			item["title"] = "片尾";
			item["time"] = formatFloat(chapterData["ed"]["start"].asFloat() * 1000, "", 32, 0);
			chapter.insertLast(item);

			if (chapterData["ed"]["end"].asFloat() * 1000 < duration) {
				item["title"] = "正片";
				item["time"] = formatFloat(chapterData["ed"]["end"].asFloat() * 1000, "", 32, 0);
				chapter.insertLast(item);
			}
		}
	} else if (!isPGC && chapterData.isArray()) {
		for (int i = 0; i < chapterData.size(); i++) {
			JsonValue point = chapterData[i];
			if (!point.isObject() || point["type"].asInt() != 2 || !point["from"].isNumeric() || !point["content"].isString()) continue;
			float time = point["from"].asFloat() * 1000;
			string title = point["content"].asString();
			if (time < 0 || (duration > 0 && time >= duration) || title.empty()) continue;

			dictionary item;
			item["title"] = title;
			item["time"] = formatFloat(time, "", 32, 0);
			chapter.insertLast(item);
		}
	}

	if (ConfigData.enableSponsorBlock) chapter = generateSponsorBlockChapter(bvid, chapter, duration, isPGC);

	return chapter;
}

array<dictionary> generateSponsorBlockChapter(const string&in bvid, const array<dictionary>&in chapter, const float duration, bool isPGC) {
	status = 6;
	array<dictionary> result;

	const float MIN_CHAPTER_DURATION = 1.0f;
	const float END_TOLERANCE = 2.0f;

	dictionary typesToName = {
		{ "sponsor", "赞助" }, 
		{ "selfpromo", "推广" }, 
		{ "exclusive_access", "品牌合作" }, 
		{ "interaction", "三连提醒" }, 
		{ "poi_highlight", "精彩时刻" }, 
		{ "intro", "开场动画" }, 
		{ "outro", "片尾" }, 
		{ "preview", "预览" }, 
		{ "padding", "填充内容" }, 
		{ "filler", "离题" }, 
		{ "music_offtopic", "非音乐" }
	};

	string headers = "origin: https://github.com/frostnotfall/BilibiliPotPlayer\r\nx-ext-version: " + GetVersion() + "\r\n";
	string url = !ConfigData.sponsorBlockMirror.empty() ? ConfigData.sponsorBlockMirror + "/api/skipSegments?videoID=" + bvid : "https://bsbsb.top/api/skipSegments?videoID=" + bvid;

	string resp = post(url, "", headers);

	if (resp.empty()) {
		log("SponsorBlock response is empty. url: " + url);
		return chapter;
	}

	JsonReader Reader;
	JsonValue SponsorBlock;

	if (!Reader.parse(resp, SponsorBlock) || !SponsorBlock.isArray()) {
		log("Failed to parse SponsorBlock response. url: " + url);
		return chapter;
	}

	if (SponsorBlock.size() == 0) return chapter;

	if (chapter.size() == 0) {
		array<float> starts;
		array<float> ends;
		array<string> titles;
		array<float> times;

		for (int i = 0; i < SponsorBlock.size(); i++) {
			JsonValue item = SponsorBlock[i];

			string category = item["category"].asString();

			if (!typesToName.exists(category)) continue;

			float start = item["segment"][0].asFloat();
			float end = item["segment"][1].asFloat();

			if (start >= end) continue;

			float videoDuration = duration / 1000.0f;

			if (start < 0)
				start = 0;

			if (end > videoDuration)
				end = videoDuration;

			if (end > videoDuration - END_TOLERANCE)
				end = videoDuration;

			if (start >= end) continue;

			starts.insertLast(start);
			ends.insertLast(end);
			titles.insertLast(string(typesToName[category]));

			times.insertLast(start);
			times.insertLast(end);
		}

		if (starts.size() == 0) return chapter;

		for (int i = 1; i < times.size(); i++) {
			float value = times[i];
			int j = i - 1;

			while (j >= 0 && times[j] > value) {
				times[j + 1] = times[j];
				j--;
			}

			times[j + 1] = value;
		}

		array<float> sortedTimes;

		for (int i = 0; i < times.size(); i++) {
			if (sortedTimes.size() == 0 ||
				sortedTimes[sortedTimes.size() - 1] != times[i]) {

				sortedTimes.insertLast(times[i]);
			}
		}

		array<float> resultTimes;
		array<string> resultTitles;

		string lastTitle;

		for (int i = 0; i < sortedTimes.size(); i++) {
			float time = sortedTimes[i];

			string currentTitle;
			float selectedStart = -1;

			for (int j = 0; j < starts.size(); j++) {
				if (starts[j] <= time && ends[j] > time) {
					if (starts[j] > selectedStart) {
						selectedStart = starts[j];
						currentTitle = titles[j];
					}
				}
			}

			if (currentTitle.empty()) currentTitle = "正片";

			if (currentTitle == lastTitle) continue;

			resultTimes.insertLast(time);
			resultTitles.insertLast(currentTitle);

			lastTitle = currentTitle;
		}

		array<float> filteredTimes;
		array<string> filteredTitles;

		for (int i = 0; i < resultTimes.size(); i++) {
			if (i == 0) {
				filteredTimes.insertLast(resultTimes[i]);
				filteredTitles.insertLast(resultTitles[i]);
				continue;
			}

			float chapterDuration = resultTimes[i] - resultTimes[i - 1];

			if (chapterDuration < MIN_CHAPTER_DURATION) {
				if (filteredTimes.size() > 0) {
					filteredTimes.removeLast();
					filteredTitles.removeLast();
				}

				filteredTimes.insertLast(resultTimes[i]);
				filteredTitles.insertLast(resultTitles[i]);

				continue;
			}

			filteredTimes.insertLast(resultTimes[i]);
			filteredTitles.insertLast(resultTitles[i]);
		}

		array<float> finalTimes;
		array<string> finalTitles;

		for (int i = 0; i < filteredTimes.size(); i++) {
			if (finalTitles.size() > 0 &&
				finalTitles[finalTitles.size() - 1] == filteredTitles[i]) {

				continue;
			}

			finalTimes.insertLast(filteredTimes[i]);
			finalTitles.insertLast(filteredTitles[i]);
		}

		for (int i = 0; i < finalTimes.size(); i++) {
			dictionary item;

			item["title"] = finalTitles[i];
			item["time"] = formatFloat(finalTimes[i] * 1000, "", 32, 0);

			result.insertLast(item);
		}

		return result;
	}

	bool hasIntro = false;
	bool hasOutro = false;

	float videoDuration = duration / 1000.0f;

	array<float> chapterStarts;
	array<float> chapterEnds;
	array<string> chapterTitles;

	for (int i = 0; i < chapter.size(); i++) {
		string title = string(chapter[i]["title"]);
		string timeString = string(chapter[i]["time"]);

		float start = 0;

		float factor = 1.0f;
		bool decimal = false;
		float decimalFactor = 0.1f;

		for (int k = 0; k < timeString.length(); k++) {
			uint8 c = timeString[k];

			if (c >= 48 && c <= 57) {
				if (!decimal) {
					start = start * 10.0f + float(c - 48);
				} else {
					start += float(c - 48) * decimalFactor;
					decimalFactor *= 0.1f;
				}
			} else if (c == 46) {
				decimal = true;
			}
		}

		start /= 1000.0f;

		float end = videoDuration;

		if (i + 1 < chapter.size()) {
			string nextTimeString = string(chapter[i + 1]["time"]);

			float nextTime = 0;
			bool nextDecimal = false;
			float nextDecimalFactor = 0.1f;

			for (int k = 0; k < nextTimeString.length(); k++) {
				uint8 c = nextTimeString[k];

				if (c >= 48 && c <= 57) {
					if (!nextDecimal) {
						nextTime = nextTime * 10.0f + float(c - 48);
					} else {
						nextTime += float(c - 48) * nextDecimalFactor;
						nextDecimalFactor *= 0.1f;
					}
				} else if (c == 46) {
					nextDecimal = true;
				}
			}

			end = nextTime / 1000.0f;
		}

		// if (title == "开场动画") hasIntro = true;
		// if (title == "片尾") hasOutro = true;
		if (start >= end) continue;

		chapterStarts.insertLast(start);
		chapterEnds.insertLast(end);
		chapterTitles.insertLast(title);
	}

	array<float> sponsorStarts;
	array<float> sponsorEnds;
	array<string> sponsorTitles;

	for (int i = 0; i < SponsorBlock.size(); i++) {
		JsonValue item = SponsorBlock[i];

		string category = item["category"].asString();

		if (!typesToName.exists(category)) continue;

		if (category == "intro" && hasIntro) continue;

		if (category == "outro" && hasOutro) continue;

		float start = item["segment"][0].asFloat();
		float end = item["segment"][1].asFloat();

		if (start >= end) continue;

		if (start < 0)
			start = 0;

		if (end > videoDuration)
			end = videoDuration;

		if (end > videoDuration - END_TOLERANCE)
			end = videoDuration;

		if (start >= end) continue;

		sponsorStarts.insertLast(start);
		sponsorEnds.insertLast(end);
		sponsorTitles.insertLast(string(typesToName[category]));
	}

	if (sponsorStarts.size() == 0) return chapter;

	array<float> times;

	for (int i = 0; i < chapterStarts.size(); i++) {
		times.insertLast(chapterStarts[i]);
		times.insertLast(chapterEnds[i]);
	}

	for (int i = 0; i < sponsorStarts.size(); i++) {
		times.insertLast(sponsorStarts[i]);
		times.insertLast(sponsorEnds[i]);
	}

	for (int i = 1; i < times.size(); i++) {
		float value = times[i];
		int j = i - 1;

		while (j >= 0 && times[j] > value) {
			times[j + 1] = times[j];
			j--;
		}

		times[j + 1] = value;
	}

	array<float> sortedTimes;

	for (int i = 0; i < times.size(); i++) {
		if (sortedTimes.size() == 0 ||
			sortedTimes[sortedTimes.size() - 1] != times[i]) {
			sortedTimes.insertLast(times[i]);
		}
	}

	array<float> resultTimes;
	array<string> resultTitles;
	string lastTitle;

	for (int i = 0; i < sortedTimes.size() - 1; i++) {
		float start = sortedTimes[i];
		float end = sortedTimes[i + 1];

		if (start >= end) continue;

		string currentTitle;
		int selectedChapter = -1;

		for (int j = 0; j < chapterStarts.size(); j++) {
			if (chapterStarts[j] <= start &&
				chapterEnds[j] > start) {

				selectedChapter = j;
				break;
			}
		}

		// PGC 原生章节优先；UGC 在空降区间内优先显示空降分类。
		if (isPGC && selectedChapter >= 0) {
			string chapterTitle = chapterTitles[selectedChapter];
			if (chapterTitle != "正片") currentTitle = chapterTitle;
		}

		if (currentTitle.empty()) {
			int selectedSponsor = -1;
			float selectedStart = -1;

			for (int j = 0; j < sponsorStarts.size(); j++) {
				if (sponsorStarts[j] <= start &&
					sponsorEnds[j] > start) {

					if (sponsorStarts[j] > selectedStart) {
						selectedStart = sponsorStarts[j];
						selectedSponsor = j;
					}
				}
			}

			if (selectedSponsor >= 0) currentTitle = sponsorTitles[selectedSponsor]; else if (selectedChapter >= 0) {
				currentTitle = chapterTitles[selectedChapter];
			} else {
				currentTitle = "正片";
			}
		}

		if (currentTitle == lastTitle) continue;

		resultTimes.insertLast(start);
		resultTitles.insertLast(currentTitle);

		lastTitle = currentTitle;
	}

	array<float> filteredTimes;
	array<string> filteredTitles;

	for (int i = 0; i < resultTimes.size(); i++) {
		if (i == 0) {
			filteredTimes.insertLast(resultTimes[i]);
			filteredTitles.insertLast(resultTitles[i]);
			continue;
		}

		float chapterDuration = resultTimes[i] - resultTimes[i - 1];

		if (chapterDuration < MIN_CHAPTER_DURATION) {
			if (filteredTimes.size() > 0) {
				filteredTimes.removeLast();
				filteredTitles.removeLast();
			}

			filteredTimes.insertLast(resultTimes[i]);
			filteredTitles.insertLast(resultTitles[i]);

			continue;
		}

		filteredTimes.insertLast(resultTimes[i]);
		filteredTitles.insertLast(resultTitles[i]);
	}

	array<float> finalTimes;
	array<string> finalTitles;

	for (int i = 0; i < filteredTimes.size(); i++) {
		if (finalTitles.size() > 0 &&
			finalTitles[finalTitles.size() - 1] == filteredTitles[i]) {
			continue;
		}

		finalTimes.insertLast(filteredTimes[i]);
		finalTitles.insertLast(filteredTitles[i]);
	}

	for (int i = 0; i < finalTimes.size(); i++) {
		dictionary item;

		item["title"] = finalTitles[i];
		item["time"] = formatFloat(finalTimes[i] * 1000, "", 32, 0);

		result.insertLast(item);
	}

	return result;
}

array<dictionary> generateSubtitle(const string&in aid, const string&in cid, const float duration, bool isBangumi) {
	array<dictionary> subtitle;
	dictionary dic;

	if (ConfigData.subtitleEnable && !isBangumi) {
		if (!ConfigData.subtitleServer.isEmpty()) {
			dic["url"] = ConfigData.subtitleServer + "aid=" + aid + "&cid=" + cid;
		} else {
			status = 8;
			array<dictionary> bilibiliSubtitles = GetBilibiliSubtitles(aid, cid, true);
			if (bilibiliSubtitles.length() != 0) {
				for (uint i = 0; i < bilibiliSubtitles.length(); i++) {
					subtitle.insertLast(bilibiliSubtitles[i]);
				}
			} else {
				log("subtitle", "no subtitles found");
			}
		}
	}

	if (ConfigData.danmakuEnable) {
		dic["name"] = "弹幕";

		if (!ConfigData.danmakuUrl.isEmpty()) {
			dic["url"] = ConfigData.danmakuUrl + cid;
		} else {
			status = 9;
			string danmuAss = BuildDanmakuAss(aid, cid, duration);
			if (danmuAss.isEmpty()) {
				HostMessageBox('弹幕生成失败，请将配置文件中的"debug"设为true后查看日志。\n请同步更新Extension\\Lib目录下的BilibiliRegex.dll。\n也可在配置文件的"danmaku" - "server"中指定可用的弹幕源。', "BilibiliPotPlayer", 0, 0);
			}
			dic["fileContent"] = danmuAss;
		}

		subtitle.insertLast(dic);
	}

	return subtitle;
}

array<dictionary> GetBilibiliSubtitles(const string &in aid, const string &in cid, bool allowAiSubtitle) {
    array<dictionary> result;
    if (aid.empty() || cid.empty()) return result;

    for (uint attempt = 0; attempt < (allowAiSubtitle ? 2 : 1); attempt++) {
        string param = "oid=" + cid + "&pid=" + aid + "&context_ext=%7B%22video_type%22%3A1%7D&type=1&cur_production_type=0";
        if (attempt == 1) param += "&preferred_language=ai-zh";
        string response = apiPost("/x/v2/subtitle/web/view?" + encWbi(param + "&playlist_switch=0"), true, true);
        if (response.empty()) return result;

        array<string> ownUrls, ownNames, ownLangs, aiUrls, aiNames, aiLangs;
        array<uint> ends = {response.length(), 0, 0};
        uint pos = 0, depth = 0;
        string lan, name, url;

        while (true) {
            if (pos == ends[depth]) {
                if (depth == 2 && !lan.empty() && !url.empty()) {
                    if (name.empty()) name = lan;
                    if (url.find("//") == 0) url = "https:" + url;
                    if (lan.find("ai-") == 0) { aiUrls.insertLast(url); aiNames.insertLast(name); aiLangs.insertLast(lan); }
                    else { ownUrls.insertLast(url); ownNames.insertLast(name); ownLangs.insertLast(lan); }
                }
                if (depth == 0) break;
                depth--;
                continue;
            }

            uint64 tag = 0, value = 0;
            uint shift = 0;
            bool done = false;
            for (uint i = 0; i < 10 && pos < ends[depth]; i++) {
                uint8 b = uint8(response[pos++]); tag |= uint64(b & 127) << shift;
                if ((b & 128) == 0) { done = true; break; }
                shift += 7;
            }
            if (!done || (tag >> 3) == 0) return result;

            uint field = uint(tag >> 3), wire = uint(tag & 7);
            if (wire == 0 || wire == 2) {
                shift = 0; done = false;
                for (uint i = 0; i < 10 && pos < ends[depth]; i++) {
                    uint8 b = uint8(response[pos++]); value |= uint64(b & 127) << shift;
                    if ((b & 128) == 0) { done = true; break; }
                    shift += 7;
                }
                if (!done) return result;
                if (wire == 0) continue;
                if (value > uint64(ends[depth] - pos)) return result;

                uint next = pos + uint(value);
                if (depth == 0 && field == 1) { depth = 1; ends[1] = next; }
                else if (depth == 1 && field == 3) { lan = ""; name = ""; url = ""; depth = 2; ends[2] = next; }
                else {
                    if (depth == 2) {
                        if (field == 3) lan = response.substr(pos, uint(value));
                        else if (field == 4) name = response.substr(pos, uint(value));
                        else if (field == 5) url = response.substr(pos, uint(value));
                    }
                    pos = next;
                }
            } else if (wire == 1 || wire == 5) {
                uint size = wire == 1 ? 8 : 4;
                if (size > ends[depth] - pos) return result;
                pos += size;
            } else return result;
        }

        if (attempt == 0 && ownUrls.empty()) continue;

        array<string> urls = ownUrls, names = ownNames, langs = ownLangs;
        if (attempt == 1) { urls = aiUrls; names = aiNames; langs = aiLangs; }

        const uint maxConcurrent = 5;

        for (uint batchStart = 0; batchStart < urls.length(); batchStart += maxConcurrent) {
            uint batchCount = urls.length() - batchStart;
            if (batchCount > maxConcurrent) batchCount = maxConcurrent;

            array<dictionary@> tasks(batchCount);
            array<int> threads(batchCount, -1);

            for (uint i = 0; i < batchCount; i++) {
                @tasks[i] = dictionary();
                tasks[i].set("url", urls[batchStart + i]);

                threads[i] = HostCreateThread(function(any@ threadParam) {
                    dictionary@ task;
                    if (threadParam is null || !threadParam.retrieve(@task) || task is null) return;

                    string subtitleUrl;
                    if (!task.get("url", subtitleUrl) || subtitleUrl.empty()) return;

                    const string hostPrefix = "https://subtitle.bilibili.com/";

                    if (subtitleUrl.find(hostPrefix) == 0) {
                        uint pathStart = hostPrefix.length();
                        int queryStart = subtitleUrl.find("?", pathStart);
                        if (queryStart < 0) return;

                        string encoded = subtitleUrl.substr(pathStart, uint(queryStart) - pathStart);
                        const string hex = "0123456789ABCDEF";
                        array<uint8> cipher;

                        for (uint p = 0; p < encoded.length(); p++) {
                            if (encoded[p] == 37 && p + 2 < encoded.length()) {
                                int hi = hex.find(encoded.substr(p + 1, 1).MakeUpper());
                                int lo = hex.find(encoded.substr(p + 2, 1).MakeUpper());
                                if (hi >= 0 && lo >= 0) {
                                    cipher.insertLast(uint8((hi << 4) | lo));
                                    p += 2;
                                    continue;
                                }
                            }
                            cipher.insertLast(uint8(encoded[p]));
                        }

                        array<string> prefixes = {
                            "nP](wOFRvU.+<fjS{jn-!$D|Dz&\",zT`",
                            "Bn\"q~|albg@]Go~ACgyDvKnd+)_D}^&J?"
                        };
                        array<string> keys = {
                            "=CFxYRn{.y|uVyO$uh&sikph?N.ilF/`bilibili",
                            "Cu~L!xs~f^&r@'vh=q]q{eeng*sEg^kp#Jbilibili"
                        };

                        string path;
                        for (uint k = 0; k < keys.length(); k++) {
                            string decodedEncoded;
                            for (uint p = 0; p < cipher.length(); p++) {
                                uint8 b = cipher[p] ^ uint8(keys[k][p % keys[k].length()]);
                                decodedEncoded += "%" + hex.substr(b >> 4, 1) + hex.substr(b & 15, 1);
                            }
                            string decoded = HostUrlDecode(decodedEncoded);
                            if (decoded.find(prefixes[k]) == 0) {
                                path = decoded.substr(prefixes[k].length());
                                break;
                            }
                        }

                        if (path.find("/bfs/") != 0) return;
                        subtitleUrl = path + subtitleUrl.substr(uint(queryStart));
                    }

                    string json = apiPost(subtitleUrl, "", "https://aisubtitle.hdslb.com", true, true);
                    if (json.empty()) return;

                    JsonReader reader;
                    JsonValue root;
                    if (!reader.parse(json, root) || !root.isObject() || !root["body"].isArray()) return;

                    JsonValue body = root["body"];
                    string srt;
                    uint number = 0;

                    for (int j = 0; j < body.size(); j++) {
                        JsonValue line = body[j];
                        if (!line.isObject() || !line["from"].isNumeric() || !line["to"].isNumeric() || !line["content"].isString()) continue;

                        double from = line["from"].asDouble(), to = line["to"].asDouble();
                        if (from < 0 || to <= from) continue;

                        uint start = uint(from * 1000 + 0.5), finish = uint(to * 1000 + 0.5);
                        string t1 = formatInt(start / 3600000) + ":" + (start / 60000 % 60 < 10 ? "0" : "") + formatInt(start / 60000 % 60) + ":" + (start / 1000 % 60 < 10 ? "0" : "") + formatInt(start / 1000 % 60) + "," + (start % 1000 < 100 ? "0" : "") + (start % 1000 < 10 ? "0" : "") + formatInt(start % 1000);
                        string t2 = formatInt(finish / 3600000) + ":" + (finish / 60000 % 60 < 10 ? "0" : "") + formatInt(finish / 60000 % 60) + ":" + (finish / 1000 % 60 < 10 ? "0" : "") + formatInt(finish / 1000 % 60) + "," + (finish % 1000 < 100 ? "0" : "") + (finish % 1000 < 10 ? "0" : "") + formatInt(finish % 1000);
                        srt += formatInt(++number) + "\r\n" + t1 + " --> " + t2 + "\r\n" + line["content"].asString() + "\r\n\r\n";
                    }

                    if (!srt.empty()) task.set("srt", srt);
                }, @tasks[i]);

                if (threads[i] < 0) return result;
            }

            for (uint i = 0; i < batchCount; i++) while (!HostWaitThread(threads[i], 10)) HostIncTimeOut(10);

            for (uint i = 0; i < batchCount; i++) {
                uint index = batchStart + i;
                string srt;
                if (!tasks[i].get("srt", srt) || srt.empty()) continue;

                dictionary subtitle;
                subtitle["name"] = langs[index].find("ai-") == 0 ? names[index] + "(AI)" : names[index];
                subtitle["langCode"] = langs[index].find("ai-") == 0 ? langs[index].substr(3) : langs[index];
                subtitle["fileContent"] = srt;
                result.insertLast(subtitle);
            }
        }

        return result;
    }

    return result;
}

class DanmakuRegexDll {
    private uintptr library = 0;
    private uintptr compileProc = 0, testProc = 0, freeProc = 0;
    private uintptr errorProc = 0, errorCodeProc = 0;
    private uintptr createSetProc = 0, setRuleProc = 0, freeSetProc = 0, errorRuleProc = 0;
    private uintptr ruleSet = 0;
    private uintptr merger = 0, mergeFeedProc = 0, mergeTextProc = 0, mergeFreeProc = 0;
    private uintptr prepareProc = 0, densityProc = 0, layoutInitProc = 0, placeProc = 0, refineTopProc = 0;
    private uintptr measureProc = 0;
    private array<uint64> handles;
    private array<string> patterns;

    ~DanmakuRegexDll() {
        // 工作线程通过 dictionary 持有本对象的句柄；最后一个引用释放后才能卸载 DLL。
        Close();
    }

    void Close() {
        if (merger != 0) HostCallProcInt(mergeFreeProc, "P", merger);
        merger = 0;
        if (ruleSet != 0) HostCallProcInt(freeSetProc, "P", ruleSet);
        ruleSet = 0;
        for (uint i = 0; i < handles.length(); i++) {
            if (handles[i] != 0) HostCallProcInt(freeProc, "P", handles[i]);
        }
        handles.resize(0);
        if (library != 0) HostFreeLibrary(library);
        library = 0;
    }

    bool InitializeMerge(uint windowMs, const string &in font, bool bold) {
        library = HostLoadLibrary(HostGetExtensionFolder() + "Lib\\BilibiliRegex.dll");
        if (library == 0) return false;
        uintptr create = HostGetProcAddress(library, "BiliDanmakuCreate");
        mergeFeedProc = HostGetProcAddress(library, "BiliDanmakuFeed");
        mergeTextProc = HostGetProcAddress(library, "BiliDanmakuText");
        mergeFreeProc = HostGetProcAddress(library, "BiliDanmakuFree");
        prepareProc = HostGetProcAddress(library, "BiliDanmakuPrepare");
        densityProc = HostGetProcAddress(library, "BiliDanmakuCommit");
        layoutInitProc = HostGetProcAddress(library, "BiliDanmakuLayoutInit");
        placeProc = HostGetProcAddress(library, "BiliDanmakuPlace");
        refineTopProc = HostGetProcAddress(library, "BiliDanmakuRefineTop");
        uintptr fontProc = HostGetProcAddress(library, "BiliDanmakuFont");
        measureProc = HostGetProcAddress(library, "BiliDanmakuMeasure");
        if (create == 0 || mergeFeedProc == 0 || mergeTextProc == 0 || mergeFreeProc == 0 || prepareProc == 0 || densityProc == 0 || layoutInitProc == 0 || placeProc == 0 || refineTopProc == 0 || fontProc == 0 || measureProc == 0) return false;
        merger = HostCallProcUIntPtr(create, "I", windowMs);
        return merger != 0 && HostCallProcInt(fontProc, "PPII", merger, HostString2UIntPtr(font), font.length(), bold ? 1 : 0) == 0;
    }

    int Merge(const string &in text, uint progress) {
        return HostCallProcInt(mergeFeedProc, "PPII", merger, HostString2UIntPtr(text), text.length(), progress);
    }

    string MergedText(uint group) {
        uintptr text = HostCallProcUIntPtr(mergeTextProc, "PI", merger, group);
        return text == 0 ? "" : HostUIntPtr2String(text);
    }

    int Prepare(const string &in text, uint progress, uint packed, uint peers) {
        return HostCallProcInt(prepareProc, "PPIIII", merger, HostString2UIntPtr(text), text.length(), progress, packed, peers);
    }

    int CommitSize() {
        return HostCallProcInt(densityProc, "P", merger);
    }

    bool InitLayout(uint area, uint pitch, uint durationMs) {
        return HostCallProcInt(layoutInitProc, "PIII", merger, area, pitch, durationMs) == 0;
    }

    uint64 Place(uint progress, uint mode, uint width, uint height) {
        return uint64(HostCallProcUIntPtr(placeProc, "PIIII", merger, progress, mode, width, height));
    }

    uint64 RefineTop(uint progress, uint64 placement) {
        uint64 code = placement - 1;
        return uint64(HostCallProcUIntPtr(refineTopProc, "PIII", merger, progress, uint(code >> 32), uint(code & 0xFFFFFFFF)));
    }

    int Measure(const string &in text, uint size) {
        return HostCallProcInt(measureProc, "PPII", merger, HostString2UIntPtr(text), text.length(), size);
    }

    string LastError() const {
        uintptr message = HostCallProcUIntPtr(errorProc, "");
        return message == 0 ? "DLL未返回错误说明" : HostUIntPtr2String(message);
    }

    bool Initialize(const array<string> &in rules, const string &in context) {
        string dllPath = HostGetExtensionFolder() + "Lib\\BilibiliRegex.dll";
        library = HostLoadLibrary(dllPath);
        if (library == 0) {
            log("[DanmakuRegexDllError] " + context + " DLL加载失败，请确认64位BilibiliRegex.dll位于Extension\\Lib。path=" + dllPath);
            return false;
        }
        compileProc = HostGetProcAddress(library, "BiliRegexCompileRule");
        testProc = HostGetProcAddress(library, "BiliRegexTestSet");
        createSetProc = HostGetProcAddress(library, "BiliRegexCreateSet");
        setRuleProc = HostGetProcAddress(library, "BiliRegexSetRule");
        freeSetProc = HostGetProcAddress(library, "BiliRegexFreeSet");
        errorRuleProc = HostGetProcAddress(library, "BiliRegexGetLastErrorRule");
        freeProc = HostGetProcAddress(library, "BiliRegexFree");
        errorProc = HostGetProcAddress(library, "BiliRegexGetLastError");
        errorCodeProc = HostGetProcAddress(library, "BiliRegexGetLastErrorCode");
        uintptr abiProc = HostGetProcAddress(library, "BiliRegexGetAbiVersion");
        if (compileProc == 0 || testProc == 0 || freeProc == 0 || errorProc == 0 ||
            errorCodeProc == 0 || abiProc == 0 || createSetProc == 0 ||
            setRuleProc == 0 || freeSetProc == 0 || errorRuleProc == 0) {
            log("[DanmakuRegexDllError] " + context + " DLL导出接口缺失，请同步更新支持规则集的BilibiliRegex.dll。path=" + dllPath);
            return false;
        }
        if (HostCallProcInt(abiProc, "") != 1) {
            log("[DanmakuRegexDllError] " + context + " DLL ABI版本不兼容，需要版本1。path=" + dllPath);
            return false;
        }
        patterns = rules;
        handles.resize(rules.length());
        for (uint r = 0; r < rules.length(); r++) {
            // 指针来源必须是存活的局部字符串，不能取数组索引临时表达式的地址。
            string pattern = rules[r];
            uint started = HostGetTickCount();
            handles[r] = HostCallProcUIntPtr(compileProc, "PII", HostString2UIntPtr(pattern), pattern.length(), 250);
            uint elapsed = HostGetTickCount() - started;
            if (elapsed > 0) HostIncTimeOut(int(elapsed));
            if (handles[r] != 0) continue;
            int code = HostCallProcInt(errorCodeProc, "");
            log("[DanmakuRegexDllError] " + context + " phase=compile regex_index=" + formatUInt(r + 1) +
                " code=" + formatInt(code) + " pattern=" + rules[r] + " error=" + LastError());
            // 与网页一致跳过无效语法；资源或宿主错误必须明确终止本次弹幕生成。
            if (code != -2) return false;
        }
        ruleSet = HostCallProcUIntPtr(createSetProc, "I", rules.length());
        if (ruleSet == 0) {
            log("[DanmakuRegexDllError] " + context + " phase=create_set error=" + LastError());
            return false;
        }
        for (uint r = 0; r < handles.length(); r++) {
            if (HostCallProcInt(setRuleProc, "PIP", ruleSet, r, handles[r]) < 0) {
                log("[DanmakuRegexDllError] " + context + " phase=set_rule regex_index=" + formatUInt(r + 1) + " error=" + LastError());
                return false;
            }
        }
        return true;
    }

    int Test(const string &in content) const {
        if (ruleSet == 0) return 0;
        uint started = HostGetTickCount();
        int result = -1000;
        try {
            result = HostCallProcInt(testProc, "PPII", ruleSet, HostString2UIntPtr(content), content.length(), 250);
        } catch {
            // 宿主调用异常同样不能被当作“不匹配”。
        }
        uint elapsed = HostGetTickCount() - started;
        if (elapsed > 0) HostIncTimeOut(int(elapsed));
        return result;
    }

    int TestCached(const string &in content, dictionary &inout results) const {
        if (ruleSet == 0) return 0;
        int result = 0;
        bool cacheable = content.length() <= 384;
        if (cacheable && results.get(content, result)) return result;
        result = Test(content);
        // 只缓存成功的匹配/不匹配；每个工作线程独立持有，错误仍立即终止。
        if (cacheable && result >= 0) {
            if (results.getSize() >= 4096) results.deleteAll();
            results.set(content, result);
        }
        return result;
    }

    void ReportMatchError(int code, const string &in context, uint progress, uint bytes) const {
        int index = code == -1000 ? -1 : HostCallProcInt(errorRuleProc, "");
        string error = code == -1000 ? "PotPlayer HostCallProcInt调用异常" : LastError();
        log("[DanmakuRegexDllError] " + context + " phase=match regex_index=" + formatInt(index + 1) +
            " time_ms=" + formatUInt(progress) + " content_bytes=" + formatUInt(bytes) +
            " code=" + formatInt(code) + " pattern=" + (index >= 0 && uint(index) < patterns.length() ? patterns[uint(index)] : "unknown") + " error=" + error);
    }
}

void SortDanmakuOrder(array<uint64> &inout order) {
    uint count = order.length();
    if (count < 2) return;
    // 普通候选优先级经常已经有序，避免分配归并缓冲区和重复排序。
    uint heartbeat = HostGetTickCount();
    bool sorted = true;
    for (uint i = 1; i < count; i++) {
        if (order[i - 1] > order[i]) { sorted = false; break; }
        if ((i & 4095) == 0) {
            uint now = HostGetTickCount();
            if (now != heartbeat) { HostIncTimeOut(int(now - heartbeat)); heartbeat = now; }
        }
    }
    if (sorted) return;
    // 官方SDK的基础类型sortAsc使用插入排序；显式归并保证最坏O(n log n)。
    // 保留完整的“毫秒时间<<32 | 原始索引”比较，时间相同的条目顺序不变。
    array<uint64> buffer(count);
    array<uint64>@ source = @order;
    array<uint64>@ target = @buffer;
    for (uint width = 1; width < count;) {
        uint left = 0;
        while (left < count) {
            uint middle = left + (width < count - left ? width : count - left);
            uint right = middle + (width < count - middle ? width : count - middle);
            uint a = left, b = middle, dest = left;
            while (a < middle && b < right) {
                if (source[a] <= source[b]) target[dest++] = source[a++];
                else target[dest++] = source[b++];
            }
            while (a < middle) target[dest++] = source[a++];
            while (b < right) target[dest++] = source[b++];
            left = right;
        }
        array<uint64>@ previous = @source;
        @source = @target;
        @target = @previous;
        uint now = HostGetTickCount();
        if (now != heartbeat) { HostIncTimeOut(int(now - heartbeat)); heartbeat = now; }
        if (width > count / 2) break;
        width *= 2;
    }
    if (source !is @order) order = source;
}

string BuildDanmakuAss(const string &in aid, const string &in cid, uint duration) {
    if (aid.empty() || cid.empty() || duration == 0 || !ConfigData.danmakuEnable) return "";
    uint totalStart = HostGetTickCount();

    const string hex = "0123456789ABCDEF";
    const string lowerHex = "0123456789abcdef";
    string font = ConfigData.danmakuFont.empty() ? "微软雅黑 Light" : ConfigData.danmakuFont;
    int fontSize = int(ConfigData.danmakuFontSize);
    if (fontSize <= 0) fontSize = 24;
    if (fontSize > 200) fontSize = 200;

    double opacity = ConfigData.danmakuOpacity, area = ConfigData.danmakuDisplayArea, stay = ConfigData.danmakuStayTime;
    if (opacity < 0) opacity = 0; else if (opacity > 1) opacity = 1;
    if (area < 0) area = 0; else if (area > 1) area = 1;
    if (stay <= 0) stay = 15;

    uint alpha = uint((1 - opacity) * 255 + 0.5);
    string alphaHex = hex.substr(alpha >> 4, 1) + hex.substr(alpha & 15, 1);
    // 按像素搜索空位；实际占用高度仍按最终字号加原有 4 像素行距计算。
    uint laneHeight = 1;
    uint lanes = uint(1080 * area) / laneHeight;
    if (lanes == 0) lanes = 1;

    string boldEffect = ConfigData.danmakuBold ? "\\b1" : "";

    array<int> blockRuleTypes = ConfigData.danmakuBlockRuleTypes;
    array<string> blockRuleFilters = ConfigData.danmakuBlockRuleFilters;

    for (uint i = 0; i < blockRuleTypes.length(); i++) {
        if (blockRuleTypes[i] != 2) continue;

        uint crc = 0xFFFFFFFF;
        for (uint j = 0; j < blockRuleFilters[i].length(); j++) {
            crc ^= uint8(blockRuleFilters[i][j]);
            for (uint k = 0; k < 8; k++) crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
        }
        crc ^= 0xFFFFFFFF;

        string midHash;
        do {
            midHash = lowerHex.substr(crc & 15, 1) + midHash;
            crc >>= 4;
        } while (crc != 0);

        blockRuleFilters[i] = midHash;
    }

    dictionary@ cloudTask;
    int cloudThread = -1;

    if (ConfigData.danmakuEnableCloudBlockList) {
        @cloudTask = dictionary();

        cloudThread = HostCreateThread(function(any@ threadParam) {
            dictionary@ task;
            if (threadParam is null || !threadParam.retrieve(@task) || task is null) return;

            string data = apiPost("/x/dm/filter/user", true, true);
            task.set("data", data);
        }, @cloudTask);

        if (cloudThread < 0) return "";
    }

    array<uint> times, modes, colors, weights;
    array<string> contents, midHashes;
    array<uint64> order;

    string ass =
        "[Script Info]\r\nTitle: Bilibili Danmaku\r\nScriptType: v4.00+\r\nPlayResX: 1920\r\nPlayResY: 1080\r\nWrapStyle: 2\r\nScaledBorderAndShadow: yes\r\nYCbCr Matrix: TV.709\r\n\r\n"
        "[V4+ Styles]\r\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\r\n"
        "Style: Danmaku," + font + "," + formatInt(fontSize) + ",&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,1.5,0,8,0,0,0,1\r\n"
        "Style: Subtitle," + font + "," + formatInt(fontSize) + ",&H00FFFFFF,&H00FFFFFF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,2,1,2,10,10,20,1\r\n\r\n"
        "[Events]\r\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\r\n";

    uint totalSegments = (duration - 1) / 360000 + 1;
    const uint maxConcurrent = 5;
    uint concurrent = totalSegments < maxConcurrent ? totalSegments : maxConcurrent;
    array<dictionary@> tasks(concurrent);
    array<int> threads(concurrent, -1);
    uint filterMask = (ConfigData.danmakuBlockTop ? 1 : 0) |
        (ConfigData.danmakuBlockBottom ? 2 : 0) | (ConfigData.danmakuBlockColor ? 4 : 0);
    uint heartbeat = HostGetTickCount();

    uint collectedCapacity = 0;
    array<dictionary@> downloaded(totalSegments);
    for (uint segment = 1; segment <= totalSegments + concurrent; segment++) {
        uint slot = segment - 1;
        if (segment > concurrent) {
            // 任一任务完成就复用槽位；不让慢分段阻止后续下载。
            slot = concurrent;
            while (slot == concurrent) {
                for (uint w = 0; w < concurrent; w++) {
                    if (threads[w] >= 0 && HostWaitThread(threads[w], 0)) { slot = w; break; }
                }
                if (slot != concurrent) break;
                for (uint w = 0; w < concurrent; w++) {
                    if (threads[w] < 0) continue;
                    if (HostWaitThread(threads[w], 10)) slot = w;
                    else HostIncTimeOut(10);
                    break;
                }
            }
            int64 completed = 0;
            if (!tasks[slot].get("segment", completed) || completed < 1 || completed > int64(totalSegments)) return "";
            @downloaded[uint(completed) - 1] = tasks[slot];
            @tasks[slot] = null;
            threads[slot] = -1;
        }

        if (segment > totalSegments) continue;
        @tasks[slot] = dictionary();
        tasks[slot].set("aid", aid);
        tasks[slot].set("cid", cid);
        tasks[slot].set("segment", int64(segment));
        tasks[slot].set("mask", int64(filterMask));
        array<uint>@ segTimes = array<uint>();
        array<uint>@ segModes = array<uint>();
        array<uint>@ segColors = array<uint>();
        array<uint>@ segWeights = array<uint>();
        array<string>@ segContents = array<string>();
        array<string>@ segHashes = array<string>();
        tasks[slot].set("times", @segTimes);
        tasks[slot].set("modes", @segModes);
        tasks[slot].set("colors", @segColors);
        tasks[slot].set("weights", @segWeights);
        tasks[slot].set("contents", @segContents);
        tasks[slot].set("hashes", @segHashes);

        threads[slot] = HostCreateThread(function(any@ threadParam) {
            dictionary@ task;
            if (threadParam is null || !threadParam.retrieve(@task) || task is null) return;

            string taskAid, taskCid;
            int64 segmentIndex = 0, mask = 0;
            array<uint>@ partTimes, partModes, partColors, partWeights;
            array<string>@ partContents, partHashes;
            if (!task.get("aid", taskAid) || !task.get("cid", taskCid) ||
                !task.get("segment", segmentIndex) || !task.get("mask", mask) ||
                !task.get("times", @partTimes) || !task.get("modes", @partModes) ||
                !task.get("colors", @partColors) || !task.get("weights", @partWeights) || !task.get("contents", @partContents) ||
                !task.get("hashes", @partHashes) || partTimes is null || partModes is null ||
                partColors is null || partWeights is null || partContents is null || partHashes is null) return;

            string param = "type=1&oid=" + taskCid + "&pid=" + taskAid + "&segment_index=" + formatInt(segmentIndex) + "&web_location=1315873";
            string data = apiPost("/x/v2/dm/wbi/web/seg.so?" + encWbi(param), true, true);
            if (data.empty() || uint8(data[0]) == 123) return;

            uint pos = 0, dataSize = data.length(), workerHeartbeat = HostGetTickCount(), scanned = 0;
            uint flags = uint(mask);
            uint partCapacity = 0;
            while (pos < dataSize) {
                if ((++scanned & 1023) == 0) {
                    uint now = HostGetTickCount();
                    if (now != workerHeartbeat) { HostIncTimeOut(int(now - workerHeartbeat)); workerHeartbeat = now; }
                }
                uint64 tag = 0, length = 0;
                uint shift = 0;
                bool done = false;

                for (uint i = 0; i < 10 && pos < dataSize; i++) {
                    uint8 b = uint8(data[pos++]); tag |= uint64(b & 127) << shift;
                    if ((b & 128) == 0) { done = true; break; }
                    shift += 7;
                }
                if (!done || (tag >> 3) == 0) return;
                uint field = uint(tag >> 3), wire = uint(tag & 7);

                if (wire == 0) {
                    done = false;
                    for (uint i = 0; i < 10 && pos < dataSize; i++)
                        if ((uint8(data[pos++]) & 128) == 0) { done = true; break; }
                    if (!done) return;
                    continue;
                }
                if (wire == 1 || wire == 5) {
                    uint size = wire == 1 ? 8 : 4;
                    if (size > dataSize - pos) return;
                    pos += size;
                    continue;
                }
                if (wire != 2) return;
                shift = 0; done = false;
                for (uint i = 0; i < 10 && pos < dataSize; i++) {
                    uint8 b = uint8(data[pos++]); length |= uint64(b & 127) << shift;
                    if ((b & 128) == 0) { done = true; break; }
                    shift += 7;
                }
                if (!done || length > uint64(dataSize - pos)) return;
                uint end = pos + uint(length);
                if (field != 1) { pos = end; continue; }

                uint progress = 0, mode = 1, color = 0xFFFFFF, weight = 1;
                string content, midHash;
                while (pos < end) {
                    uint64 innerTag = 0, value = 0;
                    shift = 0; done = false;
                    for (uint i = 0; i < 10 && pos < end; i++) {
                        uint8 b = uint8(data[pos++]); innerTag |= uint64(b & 127) << shift;
                        if ((b & 128) == 0) { done = true; break; }
                        shift += 7;
                    }
                    if (!done || (innerTag >> 3) == 0) return;
                    uint innerField = uint(innerTag >> 3), innerWire = uint(innerTag & 7);
                    if (innerWire == 0 || innerWire == 2) {
                        shift = 0; done = false;
                        for (uint i = 0; i < 10 && pos < end; i++) {
                            uint8 b = uint8(data[pos++]); value |= uint64(b & 127) << shift;
                            if ((b & 128) == 0) { done = true; break; }
                            shift += 7;
                        }
                        if (!done) return;
                        if (innerWire == 2) {
                            if (value > uint64(end - pos)) return;
                            if (innerField == 6) midHash = data.substr(pos, uint(value));
                            else if (innerField == 7) content = data.substr(pos, uint(value));
                            pos += uint(value);
                        } else {
                            if (innerField == 2) progress = uint(value);
                            else if (innerField == 3) mode = uint(value);
                            else if (innerField == 5) color = uint(value) & 0xFFFFFF;
                            else if (innerField == 9) weight = value < 1 ? 1 : (value > 11 ? 11 : uint(value));
                        }
                    } else if (innerWire == 1 || innerWire == 5) {
                        uint size = innerWire == 1 ? 8 : 4;
                        if (size > end - pos) return;
                        pos += size;
                    } else return;
                }
                if (pos != end) return;
                if (content.empty() || (mode != 1 && mode != 4 && mode != 5 && mode != 6)) continue;
                if ((flags & 1) != 0 && mode == 5) continue;
                if ((flags & 2) != 0 && mode == 4) continue;
                if ((flags & 4) != 0 && color != 0xFFFFFF) continue;

                // SDK数组不会自动倍增容量；显式扩容避免逐条复制整个分段。
                if (partTimes.length() == partCapacity) {
                    partCapacity = partCapacity == 0 ? 256 : partCapacity * 2;
                    partTimes.reserve(partCapacity); partModes.reserve(partCapacity); partColors.reserve(partCapacity);
                    partWeights.reserve(partCapacity); partContents.reserve(partCapacity); partHashes.reserve(partCapacity);
                }
                partTimes.insertLast(progress); partModes.insertLast(mode); partColors.insertLast(color);
                partWeights.insertLast(weight);
                partContents.insertLast(content); partHashes.insertLast(midHash);
            }
            task.set("ok", true);
        }, @tasks[slot]);

        if (threads[slot] < 0) return "";
    }

    // 完成顺序可以不同；原始索引仍按分段和段内顺序分配。
    for (uint completed = 1; completed <= totalSegments; completed++) {
        bool ok = false;
        array<uint>@ segTimes;
        array<uint>@ segModes;
        array<uint>@ segColors;
        array<uint>@ segWeights;
        array<string>@ segContents;
        array<string>@ segHashes;
        if (!downloaded[completed - 1].get("ok", ok) || !ok ||
            !downloaded[completed - 1].get("times", @segTimes) || !downloaded[completed - 1].get("modes", @segModes) ||
            !downloaded[completed - 1].get("colors", @segColors) || !downloaded[completed - 1].get("weights", @segWeights) || !downloaded[completed - 1].get("contents", @segContents) ||
            !downloaded[completed - 1].get("hashes", @segHashes) || segTimes is null || segModes is null ||
            segColors is null || segWeights is null || segContents is null || segHashes is null) return "";

        uint firstIndex = contents.length(), partCount = segTimes.length();
        if (segModes.length() != partCount || segColors.length() != partCount || segWeights.length() != partCount ||
            segContents.length() != partCount || segHashes.length() != partCount) return "";
        // 每段一次扩容，避免每条弹幕重复执行追加和容量检查。
        uint nextSize = firstIndex + partCount;
        if (nextSize > collectedCapacity) {
            collectedCapacity = nextSize > collectedCapacity * 2 ? nextSize : collectedCapacity * 2;
            times.reserve(collectedCapacity); modes.reserve(collectedCapacity); colors.reserve(collectedCapacity);
            weights.reserve(collectedCapacity); contents.reserve(collectedCapacity); midHashes.reserve(collectedCapacity);
            order.reserve(collectedCapacity);
        }
        times.resize(nextSize); modes.resize(nextSize); colors.resize(nextSize); weights.resize(nextSize);
        contents.resize(nextSize); midHashes.resize(nextSize); order.resize(nextSize);
        for (uint j = 0; j < partCount; j++) {
            uint index = firstIndex + j, progress = segTimes[j];
            times[index] = progress; modes[index] = segModes[j]; colors[index] = segColors[j];
            weights[index] = segWeights[j];
            contents[index] = segContents[j]; midHashes[index] = segHashes[j];
            order[index] = (uint64(progress) << 32) | uint64(index);
            if ((j & 1023) == 0) {
                uint now = HostGetTickCount();
                if (now != heartbeat) { HostIncTimeOut(int(now - heartbeat)); heartbeat = now; }
            }
        }
        @downloaded[completed - 1] = null;
    }
    uint fetchMs = HostGetTickCount() - totalStart;
    uint cloudStart = HostGetTickCount();

    if (cloudThread >= 0) {
        while (!HostWaitThread(cloudThread, 10)) HostIncTimeOut(10);

        string data;
        if (cloudTask.get("data", data) && !data.empty()) {
            JsonReader reader;
            JsonValue root;

            if (reader.parse(data, root) && root.isObject() && root["code"].isNumeric() && root["code"].asInt() == 0 && root["data"].isObject() && root["data"]["rule"].isArray()) {
                JsonValue rules = root["data"]["rule"];
                array<int> cloudRuleTypes;
                array<string> cloudRuleFilters;
                bool valid = true;

                for (uint i = 0; i < rules.size(); i++) {
                    JsonValue rule = rules[i];
                    if (!rule.isObject() || !rule["type"].isNumeric() || !rule["filter"].isString()) { valid = false; break; }

                    int type = rule["type"].asInt();
                    string filter = rule["filter"].asString();
                    if (type < 0 || type > 2 || filter.empty()) { valid = false; break; }

                    cloudRuleTypes.insertLast(type); cloudRuleFilters.insertLast(filter);
                }

                if (valid) {
                    for (uint i = 0; i < cloudRuleTypes.length(); i++) {
                        blockRuleTypes.insertLast(cloudRuleTypes[i]); blockRuleFilters.insertLast(cloudRuleFilters[i]);
                    }
                }
            }
        }
    }

    uint cloudMs = HostGetTickCount() - cloudStart;
    uint sortStart = HostGetTickCount();
    if (order.length() > 10000) HostIncTimeOut(10000);
    SortDanmakuOrder(order);

    uint sortMs = HostGetTickCount() - sortStart;
    uint filterStart = HostGetTickCount();
    string regexContext = "aid=" + aid + " cid=" + cid;
    bool processRules = !blockRuleTypes.empty();
    bool processRepeatedUser = ConfigData.danmakuBlockRepeatedUser;
    bool processMerge = ConfigData.danmakuMergeSame;
    array<uint> renderIndices, mergeCounts, mergeWeights, mergeModes;
    array<string> mergeTexts;
    dictionary seenUser;
    array<string> plainFilters, regexFilters, hashFilters;

    if (processRules) {
        for (uint i = 0; i < blockRuleTypes.length(); i++) {
            if (blockRuleTypes[i] == 0) plainFilters.insertLast(blockRuleFilters[i]);
            else if (blockRuleTypes[i] == 1) regexFilters.insertLast(blockRuleFilters[i]);
            else if (blockRuleTypes[i] == 2) hashFilters.insertLast(blockRuleFilters[i]);
        }
    }

    // 一批弹幕只加载、编译一次，工作线程共享只读规则及DLL引用。
    DanmakuRegexDll regexDll;
    if (!regexFilters.empty() && !order.empty() && !regexDll.Initialize(regexFilters, regexContext)) {
        regexDll.Close();
        return "";
    }
    array<uint8> blockedFlags(order.length(), 0);
    if (processRules && order.length() > 0) {
        uint workerCount = order.length() < 4096 ? 1 : 8;
        if (workerCount > order.length()) workerCount = order.length();
        array<dictionary@> filterTasks(workerCount);
        array<int> filterThreads(workerCount, -1);
        uint launched = 0;
        bool parallelOk = true;
        bool regexFailed = false;

        for (uint w = 0; w < workerCount; w++) {
            uint first = uint(uint64(order.length()) * uint64(w) / uint64(workerCount));
            uint last = uint(uint64(order.length()) * uint64(w + 1) / uint64(workerCount));
            @filterTasks[w] = dictionary();
            array<uint8>@ partFlags = array<uint8>(last - first, 0);
            filterTasks[w].set("first", int64(first));
            filterTasks[w].set("last", int64(last));
            filterTasks[w].set("order", @order);
            filterTasks[w].set("times", @times);
            filterTasks[w].set("context", regexContext + " phase=parallel worker=" + formatUInt(w + 1));
            filterTasks[w].set("contents", @contents);
            filterTasks[w].set("hashes", @midHashes);
            filterTasks[w].set("plain", @plainFilters);
            filterTasks[w].set("regexDll", @regexDll);
            filterTasks[w].set("hashRules", @hashFilters);
            filterTasks[w].set("flags", @partFlags);

            filterThreads[w] = HostCreateThread(function(any@ threadParam) {
                dictionary@ task;
                if (threadParam is null || !threadParam.retrieve(@task) || task is null) return;

                int64 first = 0, last = 0;
                string context;
                array<uint64>@ localOrder;
                array<uint>@ localTimes;
                array<string>@ localContents, localHashes, localPlain, localHashRules;
                DanmakuRegexDll@ localRegex;
                array<uint8>@ localFlags;
                if (!task.get("first", first) || !task.get("last", last) ||
                    !task.get("context", context) || !task.get("times", @localTimes) ||
                    !task.get("order", @localOrder) || !task.get("contents", @localContents) ||
                    !task.get("hashes", @localHashes) || !task.get("plain", @localPlain) ||
                    !task.get("regexDll", @localRegex) || !task.get("hashRules", @localHashRules) ||
                    !task.get("flags", @localFlags) || localOrder is null || localTimes is null ||
                    localContents is null || localHashes is null || localPlain is null ||
                    localRegex is null || localHashRules is null || localFlags is null) return;

                dictionary blockedHashes, regexResults;
                for (uint r = 0; r < localHashRules.length(); r++) blockedHashes.set(localHashRules[r], true);
                uint workerHeartbeat = HostGetTickCount();
                for (uint item = uint(first); item < uint(last); item++) {
                    uint index = uint(localOrder[item] & 0xFFFFFFFF);
                    string content = localContents[index];
                    string midHash = localHashes[index];
                    bool blocked = !midHash.empty() && blockedHashes.exists(midHash);
                    if (!blocked) {
                        for (uint r = 0; r < localPlain.length(); r++) {
                            if (content.findFirst(localPlain[r]) >= 0) { blocked = true; break; }
                        }
                    }
                    if (!blocked) {
                        int result = localRegex.TestCached(content, regexResults);
                        if (result < 0) {
                            localRegex.ReportMatchError(result, context, localTimes[index], content.length());
                            task.set("regexFailed", true);
                            return;
                        }
                        blocked = result == 1;
                    }
                    if (blocked) localFlags[item - uint(first)] = 1;
                    if ((item & 511) == 0) {
                        uint now = HostGetTickCount();
                        if (now != workerHeartbeat) { HostIncTimeOut(int(now - workerHeartbeat)); workerHeartbeat = now; }
                    }
                }
                task.set("ok", true);
            }, @filterTasks[w]);

            if (filterThreads[w] < 0) { parallelOk = false; break; }
            launched++;
        }

        for (uint w = 0; w < launched; w++) {
            while (!HostWaitThread(filterThreads[w], 10)) HostIncTimeOut(10);
            bool failed = false;
            if (filterTasks[w].get("regexFailed", failed) && failed) regexFailed = true;
            bool ok = false;
            array<uint8>@ partFlags;
            if (!filterTasks[w].get("ok", ok) || !ok ||
                !filterTasks[w].get("flags", @partFlags) || partFlags is null) {
                parallelOk = false;
                continue;
            }
            uint first = uint(uint64(order.length()) * uint64(w) / uint64(workerCount));
            uint last = uint(uint64(order.length()) * uint64(w + 1) / uint64(workerCount));
            if (partFlags.length() != last - first) { parallelOk = false; continue; }
            for (uint j = 0; j < partFlags.length(); j++) blockedFlags[first + j] = partFlags[j];
        }

        // 必须先等所有工作线程结束；执行错误不回退至旧引擎，也不输出漏屏的结果。
        if (regexFailed) { regexDll.Close(); return ""; }
        if (!parallelOk) {
            string context = regexContext + " phase=fallback";
            dictionary blockedHashes, regexResults;
            for (uint r = 0; r < hashFilters.length(); r++) blockedHashes.set(hashFilters[r], true);
            uint fallbackHeartbeat = HostGetTickCount();
            for (uint item = 0; item < order.length(); item++) {
                uint index = uint(order[item] & 0xFFFFFFFF);
                string content = contents[index];
                string midHash = midHashes[index];
                bool blocked = !midHash.empty() && blockedHashes.exists(midHash);
                if (!blocked) {
                    for (uint r = 0; r < plainFilters.length(); r++) {
                        if (content.findFirst(plainFilters[r]) >= 0) { blocked = true; break; }
                    }
                }
                if (!blocked) {
                    int result = regexDll.TestCached(content, regexResults);
                    if (result < 0) {
                        regexDll.ReportMatchError(result, context, times[index], content.length());
                        regexDll.Close();
                        return "";
                    }
                    blocked = result == 1;
                }
                blockedFlags[item] = blocked ? 1 : 0;
                if ((item & 511) == 0) {
                    uint now = HostGetTickCount();
                    if (now != fallbackHeartbeat) { HostIncTimeOut(int(now - fallbackHeartbeat)); fallbackHeartbeat = now; }
                }
            }
        }
    }

    regexDll.Close();
    uint mergeWindowMs = 30000; // pakku默认窗口，按组首条计时，不因后续合并延长。
    uint mergeStart = HostGetTickCount();
    // 候选数量不超过输入条数，一次预留，合并仍只增加实际组数。
    renderIndices.reserve(order.length()); mergeCounts.reserve(order.length());
    mergeWeights.reserve(order.length()); mergeModes.reserve(order.length());
    if (!order.empty() && !regexDll.InitializeMerge(mergeWindowMs, font, !boldEffect.empty())) {
        log("[Danmaku] " + regexContext + " 请同步更新Extension\\Lib\\BilibiliRegex.dll，弹幕优选/相似合并接口不可用。");
        regexDll.Close();
        return "";
    }
    heartbeat = HostGetTickCount();
    for (uint item = 0; item < order.length(); item++) {
        if ((item & 511) == 0) {
            uint now = HostGetTickCount();
            if (now != heartbeat) { HostIncTimeOut(int(now - heartbeat)); heartbeat = now; }
        }
        if (blockedFlags[item] != 0) continue;
        uint index = uint(order[item] & 0xFFFFFFFF);
        uint progress = times[index];
        uint mode = modes[index];
        string content = contents[index];
        string midHash = midHashes[index];
        string key;
        if (processRepeatedUser) key = formatUInt(mode) + "|" + content;
        if (processRepeatedUser && !midHash.empty()) {
            string userKey = midHash + "|" + key;
            if (seenUser.exists(userKey)) continue;
            seenUser.set(userKey, true);
        }
        if (processMerge) {
            int groupIndex = regexDll.Merge(content, progress);
            if (groupIndex < 0) { regexDll.Close(); return ""; }
            if (uint(groupIndex) < renderIndices.length()) {
                uint group = uint(groupIndex);
                mergeCounts[group]++;
                if (weights[index] > mergeWeights[group]) mergeWeights[group] = weights[index];
                if (mode == 4 || (mode == 5 && mergeModes[group] != 4)) mergeModes[group] = mode;
                continue;
            }
        }
        renderIndices.insertLast(index);
        mergeCounts.insertLast(1);
        mergeWeights.insertLast(weights[index]);
        mergeModes.insertLast(mode);
    }
    mergeTexts.resize(processMerge ? renderIndices.length() : 0);
    for (uint i = 0; i < renderIndices.length(); i++) {
        uint weight = mergeWeights[i];
        if (weight < 1) weight = 1; else if (weight > 11) weight = 11;
        mergeWeights[i] = weight;
        if (processMerge && mergeCounts[i] > 1) mergeTexts[i] = regexDll.MergedText(i);
    }

    uint renderStart = HostGetTickCount();
    uint mergeMs = renderStart - mergeStart;
    uint renderLength = renderIndices.length();
    uint renderedCount = 0, selectedOut = 0, fixedOut = 0;
    uint durationCs = uint(stay * 100 + 0.5);
    if (durationCs == 0) durationCs = 1;
    string textEffect;
    bool backgroundLayer = ConfigData.danmakuFontEffect >= 3;
    if (ConfigData.danmakuFontEffect == 0 || ConfigData.danmakuFontEffect == 3) {
        textEffect = "\\bord0\\shad0\\blur0";
    } else if (ConfigData.danmakuFontEffect == 1) {
        textEffect = "\\bord0\\xshad" + ConfigData.danmakuShadowDepth + "\\yshad" + ConfigData.danmakuShadowDepth + "\\4c&H000000&\\blur0";
    } else {
        textEffect = "\\bord" + ConfigData.danmakuOutlineWidth + "\\shad0\\3c&H000000&\\blur0";
    }
    string foregroundPrefix = "\\alpha&H" + alphaHex + "&\\1c&H";
    array<string> sizeForeground(4096), sizeWhite(4096), sizeBackground(4096);
    // 顶部与滚动弹幕独立占用空间；顶部先排常规居中位置，满后寻找左右空位。
    uint areaHeight = uint(1080 * area);
    if (areaHeight < laneHeight) areaHeight = laneHeight;

    // 时间、颜色和轨道坐标在整批弹幕间复用，减少逐条格式化和临时字符串。
    array<string> twoDigits(100), hexPairs(256), laneY(lanes), bottomPosition(lanes);
    for (uint i = 0; i < 100; i++) twoDigits[i] = (i < 10 ? "0" : "") + formatUInt(i);
    for (uint i = 0; i < 256; i++) hexPairs[i] = hex.substr(i >> 4, 1) + hex.substr(i & 15, 1);
    for (uint i = 0; i < lanes; i++) {
        uint y = i * laneHeight;
        laneY[i] = formatInt(y);
        bottomPosition[i] = "\\an2\\pos(960," + formatInt(1080 - y) + ")";
    }
    // 超长文本继续直接计算，缓存大小只与轨道数和固定上限有关。
    const uint cachedWidths = 1024;
    array<dictionary> scrollPosition(cachedWidths + 1), reversePosition(cachedWidths + 1);
    bool hasPreviousTime = false;
    uint previousTime = 0;
    string timePrefix;

    array<uint> preparedSizes(renderLength, 0), preparedWidths(renderLength, 0), preparedSidePadding(renderLength, 0);
    array<string> preparedTexts(renderLength);
    array<uint64> priority(renderLength), placements(renderLength, 0);
    heartbeat = HostGetTickCount();
    for (uint item = 0; item < renderLength; item++) {
        if ((item & 511) == 0) {
            uint now = HostGetTickCount();
            if (now != heartbeat) { HostIncTimeOut(int(now - heartbeat)); heartbeat = now; }
        }
        uint index = renderIndices[item];
        uint progress = times[index], mode = mergeModes[item], color = colors[index];
        string content = contents[index];
        if (processMerge && !mergeTexts[item].empty()) content = mergeTexts[item];
        if (processMerge && mergeCounts[item] > 1) content += "(" + formatUInt(mergeCounts[item]) + ")";
        priority[item] = (uint64(0xFFFFFFFF) << 32) | uint64(item);
        if (content.empty()) continue;
        uint packed = uint(fontSize) | (mergeWeights[item] << 12) |
            (ConfigData.danmakuEnlarge ? 65536 : 0) | (ConfigData.danmakuAutoShrink ? 131072 : 0);
        // 先按时间顺序完成字号处理；密度仅用于自动缩小，不删除弹幕。
        int selectedSize = regexDll.Prepare(content, progress, packed, mergeCounts[item]);
        if (selectedSize < 0) { regexDll.Close(); return ""; }
        uint itemSize = uint(selectedSize);

        // 一次扫描统计字符并转义；宽度由原生字体度量获得，避免按字数高估间距。
        uint characters = 0, begin = 0;
        string safeText;
        for (uint i = 0, n = content.length(); i < n; i++) {
            uint8 b = uint8(content[i]);
            if ((b & 0xC0) != 0x80) characters++;
            if (b != 10 && b != 13 && b != 92 && b != 123 && b != 125) continue;
            if (i > begin) safeText += content.substr(begin, i - begin);
            if (b == 10 || b == 13) safeText += " ";
            else if (b == 92) safeText += "＼";
            else if (b == 123) safeText += "｛";
            else safeText += "｝";
            begin = i + 1;
        }
        if (characters == 0) continue;
        if (begin == 0) safeText = content;
        else if (begin < content.length()) safeText += content.substr(begin);

        int measuredWidth = regexDll.Measure(safeText, itemSize);
        if (measuredWidth < 0) { regexDll.Close(); return ""; }
        uint width = uint(measuredWidth);
        uint padding = 1;
        if (mode == 5) {
            if (width < characters * itemSize) width = characters * itemSize;
            if (ConfigData.danmakuFontEffect == 2 || ConfigData.danmakuFontEffect == 4) padding += uint(ConfigData.danmakuOutlineWidth + 0.99);
        }
        preparedSizes[item] = itemSize; preparedWidths[item] = width; preparedSidePadding[item] = padding;
        preparedTexts[item] = safeText;
        if (ConfigData.danmakuAutoShrink && regexDll.CommitSize() < 0) { regexDll.Close(); return ""; }
        // 合并数量优先，数量相同按权重和原始时间顺序决定，不改变发送时间。
        uint count = mergeCounts[item] > 0x0FFFFFFF ? 0x0FFFFFFF : mergeCounts[item];
        uint rank = (count << 4) | mergeWeights[item];
        priority[item] = (uint64(0xFFFFFFFF - rank) << 32) | uint64(item);
    }
    uint prepareMs = HostGetTickCount() - renderStart;
    uint layoutStart = HostGetTickCount();
    bool autoSelect = ConfigData.danmakuAutoSelect;
    if (autoSelect) SortDanmakuOrder(priority);
    if (autoSelect && renderLength > 0 && !regexDll.InitLayout(areaHeight, laneHeight, durationCs * 10)) { regexDll.Close(); return ""; }
    // 关闭优选时按时间顺序沿用普通轨道排布；轨道满后复用最早可用轨道，保留全部候选。
    uint regularPitch = uint(fontSize) + 4;
    uint regularLanes = autoSelect ? 0 : areaHeight / regularPitch;
    if (!autoSelect && regularLanes == 0) regularLanes = 1;
    array<uint64> regularTopReady(regularLanes, 0), regularBottomReady(regularLanes, 0);
    array<uint> regularScrollStart(regularLanes, 0), regularReverseStart(regularLanes, 0);
    array<double> regularScrollDelay(regularLanes, 0), regularReverseDelay(regularLanes, 0);
    array<bool> regularScrollUsed(regularLanes, false), regularReverseUsed(regularLanes, false);
    // 字号及布局尺寸确定后，再按实际空间优选；先排合并弹幕，再填普通弹幕。
    // 原生时间索引检查前后重叠区间，允许优先安排稍晚发送的合并弹幕。
    for (uint pos = 0; pos < priority.length(); pos++) {
        if ((pos & 511) == 0) {
            uint now = HostGetTickCount();
            if (now != heartbeat) { HostIncTimeOut(int(now - heartbeat)); heartbeat = now; }
        }
        uint item = uint(priority[pos] & 0xFFFFFFFF);
        if (preparedSizes[item] == 0) continue;
        uint index = renderIndices[item], mode = mergeModes[item];
        uint progress = ((times[index] + 5) / 10) * 10;
        // 保留原行距规则，所有模式均按最终字号 + 4 像素占用高度。
        uint width = preparedWidths[item], height = preparedSizes[item] + 4;
        if (mode == 5) width += preparedSidePadding[item] * 2;
        if (autoSelect) {
            placements[item] = regexDll.Place(progress, mode, width, height);
            if (placements[item] == uint64(-1)) { regexDll.Close(); return ""; }
        } else {
            uint lane = regularLanes, fallbackLane = 0;
            double shortestWait = 1.0e100;
            array<uint>@ lastStart = mode == 6 ? @regularReverseStart : @regularScrollStart;
            array<double>@ entryDelay = mode == 6 ? @regularReverseDelay : @regularScrollDelay;
            array<bool>@ used = mode == 6 ? @regularReverseUsed : @regularScrollUsed;
            double exitDelay = double(durationCs * 10) * double(width) / (1920 + double(width));
            for (uint i = 0; i < regularLanes; i++) {
                double wait;
                if (mode == 5 || mode == 4) {
                    uint64 ready = mode == 5 ? regularTopReady[i] : regularBottomReady[i];
                    if (ready <= progress) { lane = i; break; }
                    wait = double(ready - progress);
                } else {
                    uint elapsed = progress >= lastStart[i] ? progress - lastStart[i] : 0;
                    double required = entryDelay[i] > exitDelay ? entryDelay[i] : exitDelay;
                    if (!used[i] || double(elapsed) >= required) { lane = i; break; }
                    wait = required - double(elapsed);
                }
                if (wait < shortestWait) { shortestWait = wait; fallbackLane = i; }
            }
            if (lane == regularLanes) lane = fallbackLane;
            if (mode == 5) regularTopReady[lane] = uint64(progress) + durationCs * 10;
            else if (mode == 4) regularBottomReady[lane] = uint64(progress) + durationCs * 10;
            else { used[lane] = true; lastStart[lane] = progress; entryDelay[lane] = exitDelay; }
            placements[item] = (uint64(960) << 32) | uint64(lane * regularPitch);
            placements[item]++;
        }
    }
    uint layoutMs = HostGetTickCount() - layoutStart;
    uint refineStart = HostGetTickCount();
    // 全部容量优选完成后再调整顶部补位坐标，避免遗漏后排入的滚动弹幕。
    // 保留居中区域；补位先用所有弹幕之外的空白，无空白时保留允许的滚动重叠。
    for (uint pos = 0; autoSelect && pos < priority.length(); pos++) {
        if ((pos & 511) == 0) {
            uint now = HostGetTickCount();
            if (now != heartbeat) { HostIncTimeOut(int(now - heartbeat)); heartbeat = now; }
        }
        uint item = uint(priority[pos] & 0xFFFFFFFF);
        if (mergeModes[item] != 5 || placements[item] == 0) continue;
        uint progress = ((times[renderIndices[item]] + 5) / 10) * 10;
        placements[item] = regexDll.RefineTop(progress, placements[item]);
        if (placements[item] == uint64(-1)) { regexDll.Close(); return ""; }
    }
    uint refineMs = HostGetTickCount() - refineStart;
    uint assStart = HostGetTickCount();
    string chunk;
    for (uint item = 0; item < renderLength; item++) {
        if ((item & 511) == 0) {
            uint now = HostGetTickCount();
            if (now != heartbeat) { HostIncTimeOut(int(now - heartbeat)); heartbeat = now; }
        }
        if (preparedSizes[item] == 0) continue;
        uint index = renderIndices[item];
        uint mode = mergeModes[item];
        uint color = colors[index];
        if (placements[item] == 0) { selectedOut++; if (mode == 5) fixedOut++; continue; }
        uint itemSize = preparedSizes[item], width = preparedWidths[item];
        uint progress = ((times[index] + 5) / 10) * 10;
        uint64 positionCode = placements[item] - 1;
        uint y = uint(positionCode & 0xFFFFFFFF);
        uint lane = y / laneHeight;
        uint fixedX = uint(positionCode >> 32), fixedY = y;
        string safeText = preparedTexts[item];

        uint start = (progress + 5) / 10;
        if (!hasPreviousTime || start != previousTime) {
            uint finish = start + durationCs;
            timePrefix = formatUInt(start / 360000) + ":" + twoDigits[start / 6000 % 60] + ":" +
                twoDigits[start / 100 % 60] + "." + twoDigits[start % 100] + "," +
                formatUInt(finish / 360000) + ":" + twoDigits[finish / 6000 % 60] + ":" +
                twoDigits[finish / 100 % 60] + "." + twoDigits[finish % 100] + ",Danmaku,,0,0,0,,{";
            previousTime = start;
            hasPreviousTime = true;
        }

        string position;
        if (mode == 5) position = "\\an8\\pos(" + formatUInt(fixedX) + "," + formatUInt(fixedY) + ")";
        else if (mode == 4) position = bottomPosition[lane];
        else {
            bool cacheable = width <= cachedWidths;
            array<dictionary>@ positions = mode == 6 ? @reversePosition : @scrollPosition;
            if (cacheable) {
                positions[width].get(laneY[lane], position);
            }
            if (position.empty()) {
                uint right = 1920 + width / 2;
                int left = -int(width / 2);
                string leftX = formatInt(left), rightX = formatInt(right), y = laneY[lane];
                if (mode == 6) position = "\\move(" + leftX + "," + y + "," + rightX + "," + y + ")";
                else position = "\\move(" + rightX + "," + y + "," + leftX + "," + y + ")";
                if (cacheable) {
                    positions[width].set(laneY[lane], position);
                }
            }
        }

        if (sizeForeground[itemSize].empty()) {
            string sizeTag = "\\fs" + formatUInt(itemSize) + "\\fn" + font + boldEffect;
            sizeForeground[itemSize] = "&" + sizeTag + textEffect + "\\q2}";
            sizeWhite[itemSize] = foregroundPrefix + "FFFFFF" + sizeForeground[itemSize];
            if (backgroundLayer) sizeBackground[itemSize] = "\\alpha&H" + alphaHex + "&\\1c&H000000&\\bord0\\shad0\\blur" + ConfigData.danmakuBlurRadius + sizeTag + "\\q2}";
        }
        if (backgroundLayer) {
            chunk += "Dialogue: 0,"; chunk += timePrefix; chunk += position;
            chunk += sizeBackground[itemSize]; chunk += safeText; chunk += "\r\n";
        }
        chunk += "Dialogue: 1,"; chunk += timePrefix; chunk += position;
        if (color == 0xFFFFFF) chunk += sizeWhite[itemSize];
        else {
            chunk += foregroundPrefix;
            chunk += hexPairs[color & 255]; chunk += hexPairs[(color >> 8) & 255]; chunk += hexPairs[(color >> 16) & 255];
            chunk += sizeForeground[itemSize];
        }
        chunk += safeText; chunk += "\r\n";
        renderedCount++;
        if (chunk.length() >= 65536) { ass += chunk; chunk = ""; }
    }
    ass += chunk;
    regexDll.Close();

    uint finished = HostGetTickCount();
    log("[Danmaku] aid=" + aid + " cid=" + cid + " comments=" + formatUInt(order.length()) +
        " rendered=" + formatUInt(renderedCount) + " selected_out=" + formatUInt(selectedOut) + " top_full=" + formatUInt(fixedOut) + " total_ms=" + formatUInt(finished - totalStart) +
        " render_ms=" + formatUInt(finished - renderStart) +
        " fetch_ms=" + formatUInt(fetchMs) + " cloud_wait_ms=" + formatUInt(cloudMs) +
        " sort_ms=" + formatUInt(sortMs) + " filter_ms=" + formatUInt(mergeStart - filterStart) +
        " merge_ms=" + formatUInt(mergeMs) + " prepare_ms=" + formatUInt(prepareMs) +
        " layout_ms=" + formatUInt(layoutMs) + " refine_ms=" + formatUInt(refineMs) + " ass_ms=" + formatUInt(finished - assStart));
    return ass;
}

string getFixedURL(JsonValue&in data) {
	string base_url = data["url"].isString() ? data["url"].asString() : (data["base_url"].isString() ? data["base_url"].asString() : data["baseUrl"].asString());

	if (!ConfigData.blockP2PCDN) {
		return base_url;
	}

	if (!isP2PCDN(base_url)) {
		return base_url;
	}

	if (data["backup_url"].isString() || data["backupUrl"].isString()) {
		string backup_url = ( data["backup_url"].isString() ) ? data["backup_url"].asString() : data["backupUrl"].asString();
		if (!isP2PCDN(backup_url)) {
			return backup_url;
		}
	} else if (data["backup_url"].isArray()) {
		for (uint j = 0; j < data["backup_url"].size(); j++) {
			string backup_url = data["backup_url"][j].asString();

			if (!isP2PCDN(backup_url)) {
				return backup_url;
			}
		}
	} else if (data["backupUrl"].isArray()) {
		for (uint j = 0; j < data["backupUrl"].size(); j++) {
			string backup_url = data["backupUrl"][j].asString();

			if (!isP2PCDN(backup_url)) {
				return backup_url;
			}
		}
	}

	log("getFixedURL: all backup URLs are P2P CDN, returning base URL");

	return base_url;
}

string getLiveQuality(JsonValue g_qn_desc, int qn, int hdr_type, JsonValue video_color_info) {
	int etof = 0;
	if (video_color_info.isObject() && video_color_info["eotf"].isNumeric()) {
		etof = video_color_info["eotf"].asInt();
	}

	if (!g_qn_desc.isArray() || g_qn_desc.size() == 0) {
		log("getLiveQualityNew: g_qn_desc is not an array or is empty");
		return "未匹配画质";
	}

	for (int i = 0; i < g_qn_desc.size(); i++) {
		JsonValue item = g_qn_desc[i];
		if (!item.isObject()) {
			log("getLiveQualityNew item is not object, index", i);
			continue;
		}

		int item_qn = item["qn"].asInt();
		int item_hdr_type = item["hdr_type"].asInt();
		int item_etof = item["eotf"].asInt();

		if (item_qn != qn || item_hdr_type != hdr_type || item["eotf"].asInt() != etof) {
			continue;
		}

		string fallback_desc = item["desc"].asString();
		JsonValue media_base_desc = item["media_base_desc"];
		if (!media_base_desc.isObject()) {
			log("getLiveQualityNew media_base_desc missing, fallback desc, qn=" + qn + ", hdr_type=" + hdr_type + ", etof=" + etof);
			return fallback_desc;
		}

		JsonValue detail_desc = media_base_desc["detail_desc"];
		if (!detail_desc.isObject()) {
			log("getLiveQualityNew detail_desc missing, fallback desc, qn=" + qn + ", hdr_type=" + hdr_type + ", etof=" + etof);
			return fallback_desc;
		}

		string main_desc = detail_desc["desc"].asString();
		if (main_desc.empty()) {
			log("getLiveQualityNew detail_desc desc empty, fallback desc, qn=" + qn + ", hdr_type=" + hdr_type + ", etof=" + etof);
			return fallback_desc;
		}

		JsonValue tags = detail_desc["tag"];
		if (!tags.isArray()) {
			return main_desc;
		}

		string tag_text = "";
		for (int t = 0; t < tags.size(); t++) {
			if (!tag_text.empty()) {
				tag_text += " ";
			}
			tag_text += tags[t].asString();
		}

		return main_desc + " (" + tag_text + ")";
	}

	return "未匹配画质";
}

string getVideoQuality(JsonValue support_formats, int quality) {
	for (int i = 0; i < support_formats.size(); i++) {
		if (support_formats[i]["quality"].asInt() == quality) return support_formats[i]["new_description"].asString();
	}
	return "未知";
}

string getBestUrl(array<dictionary>& QualityList, int best_qn = -1) {
	int bestQn = -1;

	if (best_qn == -1) {
		for (int i = int(ConfigData.videoIdOrder.length()) - 1; i >= 0; i--) {
			int qn = ConfigData.videoIdOrder[i];

			for (uint j = 0; j < QualityList.length(); j++) {
				dictionary QualityItem = QualityList[j];
				if (!QualityItem.exists("qn") || !QualityItem.exists("codecid") || (QualityItem.exists("va") && string(QualityItem["va"]) == "a")) continue;

				int itemQn = int(QualityItem["qn"]);

				if (itemQn == qn) {
					bestQn = qn;
					break;
				}
			}

			if (bestQn != -1) break;
		}
	} else {
		bestQn = best_qn;
	}

	if (bestQn == -1) {
		log("No suitable quality number found.");
		return "";
	}

	for (uint i = 0; i < ConfigData.defaultCodec.length(); i++) {
		string codecName = ConfigData.defaultCodec[i];
		if (!ConfigData.codecNameToCodeId.exists(codecName)) continue;
		int targetCodecid = int(ConfigData.codecNameToCodeId[codecName]);

		for (uint j = 0; j < QualityList.length(); j++) {
			dictionary QualityItem = QualityList[j];
			if (int(QualityItem["qn"]) != bestQn) continue;

			int codecid = int(QualityItem["codecid"]);
			if (codecid == targetCodecid) {
				QualityList[j]["itag"] = 702;
				// log("Found suitable URL for best quality number", QualityItem);
				return string(QualityItem["url"]);
			}
		}
	}

	log("No suitable URL found for the best quality number.");
	return "";
}

bool SetBangumiPlaybackError(JsonValue result, dictionary& MetaData) {
	JsonValue plugins = result["plugins"];
	if (!plugins.isArray()) return false;

	for (int i = 0; i < plugins.size(); i++) {
		JsonValue plugin = plugins[i];
		if (!plugin.isObject()) continue;
		JsonValue config = plugin["config"];
		if (!config.isObject() || !config["is_block"].asBool()) continue;

		if (@MetaData !is null) MetaData["errorMessage"] = config["data"].asString();
		return true;
	}
	return false;
}

string AppendBangumiQualityList(const string epid, const string path, dictionary& MetaData, array<dictionary>& QualityList) {
	status = 5;

	string url;
	string res;
	JsonReader Reader;
	JsonValue Root;

	string html = post(path);
	string prefix = "const playurlSSRData =";
	array<string> lines = html.split("\n");

	for (uint i = 0; i < lines.length(); i++) {
		string line = lines[i].Trim();
		if (line.find(prefix) == 0) {
			res = line.substr(prefix.length()).Trim();
			break;
		}
	}

	if (res.empty()) return url;
	if (!Reader.parse(res, Root) || !Root.isObject()) return url;
	if (!Root["data"].isObject())	return url;
	if (!Root["data"]["result"].isObject()) return url;
	if (SetBangumiPlaybackError(Root["data"]["result"], MetaData)) return url;

	string play_video_type = Root["data"]["result"]["play_video_type"].asString();
	if (play_video_type != "whole") {
		if (play_video_type == "preview") {
			HostMessageBox("应版权方要求，本片需购买，当前为试看片段", "BilibiliPotPlayer", 0, 0);
		}
	}

	if (!Root["data"]["result"]["video_info"].isObject()) return url;

	JsonValue support_formats = Root["data"]["result"]["video_info"]["support_formats"];
	JsonValue dash = Root["data"]["result"]["video_info"]["dash"];
	string referer = path;

	if (dash.isObject()) {
		JsonValue videos = dash["video"];
		if (!videos.isArray()) return url;
		videos = SortVideos(videos);

		int itag = 0;
		for (int i = 0; i < videos.size(); i++) {
			JsonValue video = videos[i];

			int qn = video["id"].asInt();
			int codecid = video["codecid"].asInt();

			url = getFixedURL(video);
			string width = formatInt(video["width"].asInt());
			string height = formatInt(video["height"].asInt());
			int bitrateVal = video["bandwidth"].asInt();
			string bitrate = HostFormatBitrate(bitrateVal) + "bps";
			int fps = parseInt(video["frame_rate"].asString());
			bool isHDR = (qn == 125 || qn == 126 || qn == 129);
			string mime_type = video["mime_type"].asString().MakeLower();
			string format = mime_type.substr(mime_type.findLast("/") + 1) + ", " + getCodec(codecid) + ", " + bitrate;
			string quality = getVideoQuality(support_formats, qn);
			itag = getVideoItag(qn, codecid);
			if (itag <= 0 || HostExistITag(itag)) {
				itag = HostGetITag(video["height"].asInt(), 0, true, false);
				if (itag <= 0) itag = HostGetITag(video["height"].asInt(), 0, true, true);
			}
			while (HostExistITag(itag)) itag++;
			HostSetITag(itag);

			QualityListItem item;

			item.url = url;
			item.bitrateVal = bitrateVal;
			item.bitrate = bitrate;
			item.resolution = width + "x" + height;
			item.fps = fps;
			item.isHDR = isHDR;
			item.format = format;
			item.quality = quality;
			item.qualityDetail = quality;
			item.itag = itag;
			item.audioIsDefault = false;
			item.qn = qn;
			item.codecid = codecid;
			item.va = "v";
			item.referer = referer;
			if (i == videos.size() - 1) item.videoIsDefault = true;

			if (@QualityList !is null) QualityList.insertLast(item.toDictionary());
		}

		JsonValue audios;
		JsonValue audio;
		if (dash["audio"].isArray()) {
			audios = dash["audio"];
			for (int i = 0; i < audios.size(); i++) {
				audio = audios[i];
				AppendAudioQualityList(audio, referer, QualityList);
			}
		}
		if (dash["dolby"]["audio"].isArray()) {
			audios = dash["dolby"]["audio"];
			for (int i = 0; i < audios.size(); i++) {
				audio = audios[i];
				AppendAudioQualityList(audio, referer, QualityList);
			}
		}
		if (dash["flac"].isObject()) {
			audio = dash["flac"]["audio"];
			AppendAudioQualityList(audio, referer, QualityList);
		}

	} else if (Root["data"]["result"]["video_info"]["durls"].isArray()) {
		JsonValue durls = Root["data"]["result"]["video_info"]["durls"];
		int itag;
		for (uint i = 0; i < durls.size(); i++) {
			JsonValue durl = durls[i];
			url = getFixedURL(durl["durl"][0]);
			int qn = durl["quality"].asInt();
			string quality = getVideoQuality(support_formats, qn);
			int itag = getUniItag();
			referer = referer;

			QualityListItem item;

			item.url = url;
			item.quality = quality;
			item.qualityDetail = quality;
			item.itag = itag;
			item.qn = qn;
			item.va = "va";
			item.referer = referer;

			if (@QualityList !is null) QualityList.insertLast(item.toDictionary());
		}
	} else if (Root["data"]["result"]["video_info"]["durl"].isArray()) {
		JsonValue durl = Root["data"]["result"]["video_info"]["durl"][0];
		url = getFixedURL(durl);
		int itag = getUniItag();

		QualityListItem item;

		item.url = url;
		item.itag = itag;
		item.va = "va";
		item.referer = referer;

		if (@QualityList !is null) QualityList.insertLast(item.toDictionary());
	}

	if (QualityList.size() > 1) {
		string bestUrl = getBestUrl(QualityList);
		if (!bestUrl.isEmpty()) url = bestUrl;
	}

	return url;
}

string AppendVideoQualityList(string bvid, string aid, string cid, array<dictionary>& QualityList) {
	status = 5;

	string url;
	int qn = 127;
	string params;
	string res;
	string referer;
	JsonReader reader;
	JsonValue root;

	params = "bvid=" + bvid + "&avid=" + aid + "&cid=" + cid + "&qn=" + qn + "&fnval=4048&fourk=1";
	res = apiPost("/x/player/wbi/playurl?" + encWbi(params));
	if (reader.parse(res, root) && root.isObject()) {
		if (root["code"].asInt() == 0) {
			JsonValue data = root["data"];
			JsonValue support_formats = data["support_formats"];
			referer = "https://www.bilibili.com/video/" + bvid;

			if (data["dash"].isObject()) {
				int itag = 0;
				JsonValue videos = data["dash"]["video"];
				videos = SortVideos(videos);

				for (int i = 0; i < videos.size(); i++) {
					JsonValue video = videos[i];

					int qn = video["id"].asInt();
					int codecid = video["codecid"].asInt();

					url = getFixedURL(video);
					string width = formatInt(video["width"].asInt());
					string height = formatInt(video["height"].asInt());
					int bitrateVal = video["bandwidth"].asInt();
					string bitrate = HostFormatBitrate(bitrateVal) + "bps";
					int fps = ( video["frame_rate"].isString() ) ? parseInt(video["frame_rate"].asString()) : parseInt(video["frameRate"].asString());
					bool isHDR = (qn == 125 || qn == 126 || qn == 129);
					string mime_type = ( video["mime_type"].isString() ) ? video["mime_type"].asString().MakeLower() : video["mimeType"].asString().MakeLower();
					string format = mime_type.substr(mime_type.findLast("/") + 1) + ", " + getCodec(codecid) + ", " + bitrate;
					string quality = getVideoQuality(data["support_formats"], qn);
					itag = getVideoItag(qn, codecid);
					if (itag <= 0 || HostExistITag(itag)) {
						itag = HostGetITag(video["height"].asInt(), 0, true, false);
						if (itag <= 0) itag = HostGetITag(video["height"].asInt(), 0, true, true);
					}
					while (HostExistITag(itag)) itag++;
					HostSetITag(itag);

					QualityListItem item;

					item.url = url;
					item.bitrateVal = bitrateVal;
					item.bitrate = bitrate;
					item.resolution = width + "x" + height;
					item.fps = fps;
					item.isHDR = isHDR;
					item.format = format;
					item.quality = quality;
					item.qualityDetail = quality;
					item.itag = itag;
					item.audioIsDefault = false;
					item.qn = qn;
					item.codecid = codecid;
					item.va = "v";
					item.referer = referer;
					if (i == videos.size() - 1) item.videoIsDefault = true;

					if (@QualityList !is null) QualityList.insertLast(item.toDictionary());
				}

				JsonValue audios;
				JsonValue audio;
				if (data["dash"]["audio"].isArray()) {
					audios = data["dash"]["audio"];
					for (int i = 0; i < audios.size(); i++) {
						audio = audios[i];
						AppendAudioQualityList(audio, referer, QualityList);
					}
				}
				if (data["dash"]["dolby"]["audio"].isArray()) {
					audios = data["dash"]["dolby"]["audio"];
					for (int i = 0; i < audios.size(); i++) {
						audio = audios[i];
						AppendAudioQualityList(audio, referer, QualityList);
					}
				}
				if (data["dash"]["flac"].isObject()) {
					audio = data["dash"]["flac"]["audio"];
					AppendAudioQualityList(audio, referer, QualityList);
				}
			} else if (data["durls"].isArray()) {
				JsonValue durls = data["durls"];
				int itag;
				for (uint i = 0; i < durls.size(); i++) {
					JsonValue durl = durls[i];
					url = getFixedURL(durl["durl"][0]);
					int qn = durl["quality"].asInt();
					string quality = getVideoQuality(support_formats, qn);
					int itag = getUniItag();
					referer = referer;

					QualityListItem item;

					item.url = url;
					item.quality = quality;
					item.qualityDetail = quality;
					item.itag = itag;
					item.qn = qn;
					item.va = "va";
					item.referer = referer;

					if (@QualityList !is null) QualityList.insertLast(item.toDictionary());
				}
			} else if (data["durl"].isArray()) {
				JsonValue durl = data["durl"][0];
				url = getFixedURL(durl);
				int itag = getUniItag();

				QualityListItem item;

				item.url = url;
				item.itag = itag;
				item.va = "va";
				item.referer = referer;

				if (@QualityList !is null) QualityList.insertLast(item.toDictionary());
			}
		}
	}

	if (QualityList.size() > 1) {
		string bestUrl = getBestUrl(QualityList);
		if (!bestUrl.isEmpty()) url = bestUrl;
	}

	return url;
}

void AppendAudioQualityList(JsonValue audio, string referer, array<dictionary>& QualityList) {
	int itag = 0;
	string quality; 
	bool audioIsDefault = false;
	int audioid = audio["id"].asInt();

	string url = getFixedURL(audio);

	if (audioid == 30250) {
		quality = "杜比全景声";
	} else if (audioid == 30251) {
		quality = "Hi-Res无损";
		audioIsDefault = true;
	} else if (audio["codecs"].asString().MakeLower().find("mp4a") >= 0) {
		quality = "AAC";
	}

	int bitrateVal = audio["bandwidth"].asInt();
	string bitrate = HostFormatBitrate(bitrateVal) + "bps";

	itag = getAudioItag(audioid);
	// if (itag <= 0 || HostExistITag(itag)) {
	// 	itag = HostGetITag(0, int(bitrateVal / 1000.0), true, false);
	// 	if (itag <= 0) itag = HostGetITag(0, int(bitrateVal / 1000.0), true, true);
	// }
	// while (HostExistITag(itag)) itag++;
	// HostSetITag(itag);

	string codec = audio["codecs"].asString().MakeLower();
	string mime_type = audio["mime_type"].asString().MakeLower();
	string format = mime_type.substr(mime_type.findLast("/") + 1) + ", " + (codec.find(".") >= 0 ? codec.substr(0, codec.find(".")) : codec) + ", " + bitrate;

	QualityListItem item;

	item.url = url;
	item.bitrateVal = bitrateVal;
	item.bitrate = bitrate;
	item.resolution = "audio only";	
	item.format = format;
	item.quality = quality;
	item.qualityDetail = item.quality;
	item.itag = itag;
	item.audioIsDefault = audioIsDefault;
	item.va = "a";
	item.referer = referer;

	if (@QualityList !is null) QualityList.insertLast(item.toDictionary());
}

JsonValue SortVideos(JsonValue& videos) {
	JsonReader reader;
	JsonValue sortedVideos;
	reader.parse("[]", sortedVideos);

	array<bool> used(videos.size(), false);

	for (uint i = 0; i < videos.size(); i++) {
		int minIndex = -1;
		int minOrder = 0;

		for (uint j = 0; j < videos.size(); j++) {
			if (used[j]) continue;

			int codecid = videos[j]["codecid"].asInt();
			int id = videos[j]["id"].asInt();

			int order = int(ConfigData.videoIdOrder.length());

			for (uint k = 0; k < ConfigData.videoIdOrder.length(); k++) {
				if (ConfigData.videoIdOrder[k] == id) {
					order = int(k);
					break;
				}
			}

			if (ConfigData.disableAVC && codecid == 7) {
				bool hasHevcOrAv1 = false;

				for (uint k = 0; k < videos.size(); k++) {
					if (k == j) continue;
					if (videos[k]["id"].asInt() != id) continue;

					int otherCodecId = videos[k]["codecid"].asInt();
					if (otherCodecId == 12 || otherCodecId == 13) {
						hasHevcOrAv1 = true;
						break;
					}
				}

				if (hasHevcOrAv1) {
					continue;
				}
			}

			if (minIndex == -1 || order < minOrder) {
				minIndex = int(j);
				minOrder = order;
			} else if (order == minOrder && codecid < videos[minIndex]["codecid"].asInt()) {
				minIndex = int(j);
			}
		}

		if (minIndex == -1) break;

		sortedVideos[i] = videos[minIndex];
		used[minIndex] = true;
	}

	return sortedVideos;
}

array<dictionary> BangumiEpisodes(string id, string type, const string &in path) {
	log("============================BangumiEpisodes============================");
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;
	string res;
	string author;
	string target_ep_id;
	string query = HostRegExpParse(path, "^[^?#]*\\?([^#]*)");

	if (type == "media_id") {
		id = md2ss(id);
		if (id.empty()) return videos;
		type = "season_id";
	}

	if (type == "season_id") {
		res = apiPost("/pgc/view/web/simple/season?season_id=" + id);
		Reader.parse(res, Root);
		author = "@" + Root["result"]["up_info"]["uname"].asString();

		res = apiPost("/pgc/view/web/ep/page?season_id=" + id);
		Reader.parse(res, Root);
		target_ep_id = Root["result"]["locator"]["target_ep_id"].asString();
	}

	// TODO: type 为 ep_id 时获取 author。

	res = apiPost("/pgc/view/web/ep/list?" + type + "=" + id);
	Reader.parse(res, Root);
	JsonValue episodes = Root["result"]["episodes"];
	if (!episodes.isArray()) return videos;

	for (int j = 0; j < episodes.size(); j++) {
		JsonValue episode = episodes[j];
		if (!ConfigData.showTrailer && episode["badge_type"].asInt() == 1) continue;
		string title = ((episode["badge"].isString() && !episode["badge"].asString().empty()) ?  "【" + episode["badge"].asString() + "】\n" : "") + episode["share_copy"].asString() + "\n" + episode["show_title"].asString();
		bool isCurrent = episode["ep_id"].asString() == id || episode["ep_id"].asString() == target_ep_id;
		string videoUrl = episode["link"].asString();
		if (isCurrent && !query.empty()) videoUrl = makeWebUrl(videoUrl + (videoUrl.find("?") >= 0 ? "&" : "?") + query);

		dictionary video;

		video["title"] = title;
		video["duration"] = episode["duration"].asString();
		video["thumbnail"] = episode["cover"].asString();
		if (!author.isEmpty()) video["author"] = author;
		video["url"] = videoUrl;
		// if (!episode["desc"].asString().empty() || episode["desc"].asString() != "-")  video["content"] = view["desc"].asString();
		video["viewCount"] = episode["stat"]["play"].asString();
		video["likeCount"] = episode["stat"]["likes"].asString();
		// video["dislikeCount"] = episode["stat"]["dislike"].asString();
		video["date"] = UnixTimeToDateTime(episode["pub_time"].asInt64());
		if (isCurrent) video["current"] = "1";
		if (type == "season_id") video["referer"] = "www.bilibili.com/bangumi/play/ss" + id;
		if (type == "ep_id") video["referer"] = "www.bilibili.com/bangumi/play/ep" + id;

		videos.insertLast(video);
	}

	return videos;
}

array<dictionary> UGCSeason(const string&in path) {
	log("============================UGCSeason============================");
	array<dictionary> videos;

	string bvid = parseBVId(path);
	string aid = parseAVId(path);
	string cid;
	string p = parse(path, "p", "1");

	array<string> queryParts;
	if (!bvid.empty()) queryParts.insertLast("bvid=" + bvid);
	if (!aid.empty()) queryParts.insertLast("aid=" + aid);

	string params = join(queryParts, "&");
	if (params.empty()) return videos;

	string res = apiPost("/x/web-interface/wbi/view/detail?" + encWbi(params));

	JsonReader Reader;
	JsonValue Root;
	Reader.parse(res, Root);

	if (Root["data"]["View"]["ugc_season"].isObject()) {
		JsonValue sections = Root["data"]["View"]["ugc_season"]["sections"];
		if (!sections.isArray()) return videos;

		// 单/多分组合集
		bool multiSection = (sections.size() > 1) ? true : false;

		for (int i = 0; i < sections.size(); i++) {
			JsonValue section = sections[i];
			if (!section.isObject()) continue;

			string sectionTitle;
			if (multiSection) sectionTitle = "【" + section["title"].asString() + "】";

			JsonValue episodes = section["episodes"];
			if (!episodes.isArray())  continue;

			for (int j = 0; j < episodes.size(); j++) {
				JsonValue episode = episodes[j];
				if (!episode.isObject()) continue;

				string episodeTitle = episode["arc"]["title"].asString();

				JsonValue pages = episode["pages"];
				if (!pages.isArray()) continue;

				// 单/多P视频
				bool multiPages = (pages.size() > 1) ? true : false;

				for (int k = 0; k < pages.size(); k++) {
					JsonValue page = pages[k];
					if (!page.isObject()) continue;

					bool isCurrent = ((episode["bvid"].asString() == bvid || episode["aid"].asString() == aid) && page["page"].asString() == p) ? true : false;

					if (!ConfigData.showUgcSeason && !isCurrent) continue;

					string finalTitle;

					if (multiPages) {
						if (sectionTitle.isEmpty()) {
							finalTitle = episodeTitle + "\n" + page["part"].asString();
						} else {
							finalTitle = sectionTitle + "\n" + episodeTitle + "\n" + page["part"].asString();
						}
					} else {
						if (sectionTitle.isEmpty()) {
							finalTitle = episodeTitle;
						} else {
							finalTitle = sectionTitle + "\n" + episodeTitle;
						}
					}

					string videoUrl = isCurrent ? makeWebUrl(path) : makeWebUrl("https://www.bilibili.com/video/" + episode["bvid"].asString() + "?p=" + page["page"].asString());

					dictionary video;

					video["title"] = finalTitle;
					video["duration"] = page["duration"].asInt() * 1000;
					video["thumbnail"] = episode["arc"]["pic"].asString();
					video["author"] = "@" + episode["arc"]["author"]["name"].asString();
					video["url"] = videoUrl;
					video["viewCount"] = episode["arc"]["stat"]["view"].asString();
					video["likeCount"] = episode["arc"]["stat"]["like"].asString();
					video["dislikeCount"] = episode["arc"]["stat"]["dislike"].asString();
					video["date"] = UnixTimeToDateTime(episode["arc"]["pubdate"].asInt64());
					if (isCurrent) video["current"] = "1";
					video["referer"] = path;

					videos.insertLast(video);
				}
			}
		}
	} else if (Root["data"]["View"]["pages"].isArray()) {
		JsonValue pages = Root["data"]["View"]["pages"];

		for (int i = 0; i < pages.size(); i++) {
			JsonValue page = pages[i];

			bool isCurrent = parse(path, "p", "1") == page["page"].asString();
			if (!ConfigData.showUgcSeason && !isCurrent) continue;
			string videoUrl = isCurrent ? makeWebUrl(path) : makeWebUrl("https://www.bilibili.com/video/" + Root["data"]["View"]["bvid"].asString() + "?p=" + page["page"].asString());

			dictionary video;

			video["title"] = Root["data"]["View"]["title"].asString() + "\n" + page["part"].asString();
			video["duration"] = page["duration"].asInt() * 1000;
			video["thumbnail"] = page["first_frame"].asString();
			video["author"] = "@" + Root["data"]["View"]["owner"]["name"].asString();
			video["url"] = videoUrl;
			video["date"] = UnixTimeToDateTime(page["ctime"].asInt64());
			if (isCurrent) video["current"] = "1";
			video["referer"] = path;

			videos.insertLast(video);
		}
	}

	return videos;
}

array<dictionary> RelatedVideos(const string&in path) {
	log("============================RelatedVideos============================");
	array<dictionary> videos;

	string bvid = parseBVId(path);
	string aid = parseAVId(path);

	array<string> queryParts;
	if (!bvid.empty()) queryParts.insertLast("bvid=" + bvid);
	if (!aid.empty()) queryParts.insertLast("aid=" + aid);

	string params = join(queryParts, "&");
	if (params.empty()) return videos;

	string res = apiPost("/x/web-interface/wbi/view/detail?" + encWbi(params));

	JsonReader Reader;
	JsonValue Root;
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() == 0) {
			if (!Root["data"]["View"].isObject()) {
				log('Root["data"]["View"] is empty.');
				return videos;
			}

			JsonValue view = Root["data"]["View"];

			dictionary video;

			video["title"] = view["title"].asString();
			video["duration"] = view["duration"].asInt() * 1000;
			video["thumbnail"] = view["pic"].asString();
			video["author"] = "@" + view["owner"]["name"].asString();
			video["url"] = makeWebUrl(path);
			if (!view["desc"].asString().empty() && view["desc"].asString() != "-") video["content"] = view["desc"].asString();
			video["viewCount"] = view["stat"]["view"].asString();
			video["likeCount"] = view["stat"]["like"].asString();
			video["dislikeCount"] = view["stat"]["dislike"].asString();
			video["date"] = UnixTimeToDateTime(view["pubdate"].asInt64());
			video["current"] = "1";
			video["referer"] = makeWebUrl(path);

			videos.insertLast(video);

			if (!ConfigData.showRecommendedVideos) return videos;

			JsonValue related = Root["data"]["Related"];
			if (related.isArray()) {
				for (int i = 0; i < related.size(); i++) {
					JsonValue item = related[i];
					if (item.isObject()) {
						dictionary video;

						video["title"] = item["title"].asString();
						video["duration"] = item["duration"].asInt() * 1000;
						video["thumbnail"] = item["pic"].asString();
						video["author"] = "@" + item["owner"]["name"].asString();
						video["url"] = "https://www.bilibili.com/video/" + item["bvid"].asString();
						if (!item["desc"].asString().empty() && item["desc"].asString() != "-") video["content"] = item["desc"].asString();
						video["viewCount"] = item["stat"]["view"].asString();
						video["likeCount"] = item["stat"]["like"].asString();
						video["dislikeCount"] = item["stat"]["dislike"].asString();
						video["date"] = UnixTimeToDateTime(item["pubdate"].asInt64());
						video["referer"] = makeWebUrl(path);

						videos.insertLast(video);
					} else {
						log("item is not exists.");
					}
				}
			} else {
				log("no related videos");
			}
		} else {
			log("Video view API code != 0", Root["code"].asInt());
			log("Video view API message", Root["message"].asString());
		}
	} else {
		log("res parse failed or Root is empty.");
	}

	return videos;
}

array<dictionary> RelatedLiveRooms(const string id, const string&in path) {
	log("============================ RelatedLiveRooms ============================");
	array<dictionary> videos;

	string url;
	string res;
	JsonReader Reader;
	JsonValue Root;

	res = apiPost("/xlive/web-room/v1/index/getInfoByRoom?room_id=" + id, "", "https://api.live.bilibili.com");

	if (!Reader.parse(res, Root) || !Root.isObject() || Root["code"].asInt() != 0) return videos;
	if (!Root["data"].isObject() || !Root["data"]["room_info"].isObject()) return videos;

	JsonValue data = Root["data"]["room_info"];
	string room_id = data["room_id"].asInt();

	string title;
	string area_title = data["parent_area_name"].asString().isEmpty() ? data["area_name"].asString() : data["area_name"].asString().isEmpty() ? data["parent_area_name"].asString() : data["parent_area_name"].asString() + " (" + data["area_name"].asString() + ")";
	if (!area_title.isEmpty()) {
		title = area_title + "\n" + data["title"].asString();
	} else {
		title = data["title"].asString();
	}

	string thumbnail = ConfigData.useKeyframe && data["keyframe"].isString() && !data["keyframe"].asString().isEmpty() ? data["keyframe"].asString() : data["cover"].asString();

	dictionary video;

	video["title"] = title;
	video["thumbnail"] = thumbnail;
	video["author"] = "@" + Root["data"]["anchor_info"]["base_info"]["uname"].asString();
	video["url"] = "https://live.bilibili.com/" + room_id;
	video["current"] = "1";
	video["referer"] = makeWebUrl(path);

	videos.insertLast(video);

	if (!ConfigData.showRecommendedLiveRooms) return videos;

	res = apiPost("/xlive/web-interface/v1/webMain/getMoreRecList?platform=web&web_location=0.0", "", "https://api.live.bilibili.com");

	if (!Reader.parse(res, Root) || !Root.isObject() || Root["code"].asInt() != 0) return videos;
	if (!Root["data"].isObject() || !Root["data"]["recommend_room_list"].isArray()) return videos;

	JsonValue recommend_room_list = Root["data"]["recommend_room_list"];
	for (int i = 0; i < recommend_room_list.size(); i++) {
		JsonValue item = recommend_room_list[i];
		if (! item.isObject()) continue;

		string title;
		string area_title;
		string pendant_title;

		area_title = item["area_v2_parent_name"].asString().isEmpty() ? item["area_v2_name"].asString() : item["area_v2_name"].asString().isEmpty() ? item["area_v2_parent_name"].asString() : item["area_v2_parent_name"].asString() + " (" + item["area_v2_name"].asString() + ")";

		if (item["pendant_info"].isObject()) {
			array<string> pendant_infos;
			array<string> keys = item["pendant_info"].getKeys();

			for (int j = 0; j < keys.size(); j++) {
				pendant_infos.insertLast(item["pendant_info"][keys[j]]["content"].asString().isEmpty() ? item["pendant_info"][keys[j]]["name"].asString() : item["pendant_info"][keys[j]]["content"].asString());
			}
			pendant_title = join(pendant_infos, " | ");
		}

		array<string> titles;
		if (!area_title.isEmpty()) titles.insertLast(area_title);
		titles.insertLast(item["title"].asString());
		if (!pendant_title.isEmpty()) titles.insertLast(pendant_title);

		title = join(titles, "\n");

		string thumbnail = ConfigData.useKeyframe && item["keyframe"].isString() && !item["keyframe"].asString().isEmpty() ? item["keyframe"].asString() : item["cover"].asString();

		dictionary video;

		video["title"] = title;
		video["thumbnail"] = thumbnail;
		video["author"] = "@" + item["uname"].asString();
		video["url"] = "https://live.bilibili.com/" + item["roomid"].asString();
		video["referer"] = makeWebUrl(path);

		videos.insertLast(video);
	}

	return videos;
}

array<dictionary> FavList(string path) {
	JsonReader Reader;
	array<dictionary> videos;
	string fid = parseFid(path);
	if (fid.empty()) {
		string mid = HostRegExpParse(path, "bilibili.com/([0-9]+)");
		if (mid.empty()) {
			mid = "" + ConfigData.uid;
		}
		string res = apiPost("/x/v3/fav/folder/created/list-all?up_mid=" + mid);
		JsonValue Root;
		if (Reader.parse(res, Root) && Root.isObject()) {
			if (Root["code"].asInt() == 0) {
				JsonValue data = Root["data"]["list"];
				if (data.isArray()) {
					fid = "" + data[0]["id"].asInt();
				}
			}
		}
	}
	if (fid.empty()) {
		return videos;
	}
	int pn = 1;
	int ps = 20;
	string baseurl;
	string url;
	string ftype = parse(path, "ftype");
	// 订阅和收藏
	if (ftype == "collect") {
		baseurl = "/x/space/fav/season/list?season_id=" + fid;
	} else {
		baseurl = "/x/v3/fav/resource/list?media_id=" + fid + "&ps=" + ps;
		baseurl += "&keyword=" + parse(path, "keyword");
		baseurl += "&order=" + parse(path, "order", "mtime");
		// url += "&type=" + parse(path, "type", "0");
		baseurl += "&tid=" + parse(path, "tid", "0");
	}
	while (true) {
		if (ftype == "collect") {
			url = baseurl;
		} else {
			url = baseurl + "&pn=" + pn;
		}
		string res = apiPost(url);
		JsonValue Root;
		if (Reader.parse(res, Root) && Root.isObject()) {
			if (Root["code"].asInt() == 0) {
				JsonValue data = Root["data"]["medias"];
				if (data.isArray()) {
					for (int i = 0; i < data.size(); i++) {
						JsonValue item = data[i];
						if (item.isObject()) {
							if (item["attr"].asInt() == 9) continue;

							dictionary video;

							video["title"] = item["title"].asString();
							video["duration"] = item["duration"].asInt() * 1000;
							video["url"] = "https://www.bilibili.com/video/" + item["bvid"].asString();
							video["thumbnail"] = item["cover"].asString();
							video["author"] = "@" + item["upper"]["name"].asString();

							videos.insertLast(video);
						}
					}
				}
				if (ftype == "collect") {
					return videos;
				}
				int count = Root["data"]["info"]["media_count"].asInt();
				if (pn * ps >= count) {
					break;
				}
				pn += 1;
			} else {
				return videos;
			}
		} else {
			return videos;
		}
	}
	return videos;
}

array<dictionary> AudioList(string path) {
	array<dictionary> audios;
	JsonReader Reader;
	JsonValue Root;
	string id = HostRegExpParse(path, "www.bilibili.com/audio/am([0-9]+)");
	if (id.empty()) {
		return audios;
	}
	string url = "https://www.bilibili.com/audio/music-service-c/web/song/of-menu?pn=1&ps=100&sid=" + id;
	string res = post(url);
	res = HostDecompress(res);
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() != 0) {
			return audios;
		}
		JsonValue data = Root["data"]["data"];
		if (data.isArray()) {
			for (int i = 0; i < data.size(); i++) {
				JsonValue item = data[i];

				dictionary audio;

				audio["title"] = item["title"].asString();
				audio["duration"] = item["duration"].asInt() * 1000;
				audio["url"] = "https://www.bilibili.com/audio/au" + item["statistic"]["sid"].asInt();
				audio["thumbnail"] = item["cover"].asString();
				if (item["author"].isString()) audio["author"] = "@" + item["author"].asString();

				audios.insertLast(audio);
			}
		}
	}
	return audios;
}

string Bangumi(const string&in path, dictionary& MetaData, array<dictionary>& QualityList) {
	log("==============================Bangumi=============================");
	string url;
	string res;
	string aid;
	string bvid;
	string cid;
	string ssid;
	string epid = parseEPId(path);

	if (epid.isEmpty()) {
		ssid = parseSSId(path);
		if (ssid.isEmpty()) {
			string mdid = parseMDId(path);
			if (mdid.isEmpty()) return url;
			ssid = md2ss(mdid);
		}
	}

	string params = !epid.isEmpty() ? ("ep_id=" + epid) : ("season_id=" + ssid);
	res = apiPost("/pgc/view/web/ep/page?" + encWbi(params));

	JsonReader Reader;
	JsonValue Root;

	if (!Reader.parse(res, Root) || !Root.isObject()) return url;

	epid = Root["result"]["locator"]["target_ep_id"].asString();
	JsonValue sections = Root["result"]["sections"];

	if (!sections.isArray()) return url;
	JsonValue section = sections[0];
	if (!section["pages"].isArray()) return url;

	for (int i = 0; i < section["pages"].size(); i++) {
		JsonValue page = section["pages"][i];
		if (!page.isObject()) continue;
		JsonValue episodes = page["episodes"];
		if (!episodes.isArray()) continue;
		for (int j = 0; j < episodes.size(); j++) {
			JsonValue episode = episodes[j];
			if (episode["ep_id"].asString() != epid) continue;

			aid = episode["aid"].asString();
			bvid = episode["bvid"].asString();
			cid = episode["cid"].asString();

			string title = ((episode["badge"].isString() && !episode["badge"].asString().empty()) ?  "【" + episode["badge"].asString() + "】\n" : "") + episode["share_copy"].asString() + "\n" + episode["show_title"].asString();

			int64 duration = episode["duration"].asInt64();
			string webUrl = "https://www.bilibili.com/bangumi/play/ep" + epid;
			int seek = GetStartSeconds(path, aid, cid, epid);

			string chatUrl;
			string chatScript;
			if (ConfigData.enableVodChatUrl && HostFileExist(ConfigData.ChatScriptVod)) {
				chatUrl = webUrl;
				chatScript = ReadWebScript(ConfigData.ChatScriptVod);
			}

			if (@MetaData !is null) {
				MetaData["title"] = title;
				MetaData["vid"] = "bilibili.com|" + epid;
				MetaData["duration"] = formatInt(duration);
				MetaData["thumbnail"] = episode["cover"].asString();
				MetaData["webUrl"] = webUrl;
				MetaData["date"] = UnixTimeToDateTime(episode["pub_time"].asInt64());
				MetaData["fileExt"] = "mp4";
				if (seek > 0) MetaData["seek"] = seek;
				if (!chatUrl.isEmpty()) MetaData["chatUrl"] = chatUrl;
				if (!chatUrl.isEmpty() &&!chatScript.isEmpty()) MetaData["chatScript"] = chatScript;

				array<dictionary> chapter = generateChapter(episode["skip"], bvid, float(duration), true);
				if (!chapter.empty()) MetaData["chapter"] = chapter;

				array<dictionary> subtitle = generateSubtitle(aid, cid, duration, true);
				if (!subtitle.empty()) MetaData["subtitle"] = subtitle;

				res = apiPost("/pgc/season/episode/web/info?ep_id=" + epid);
				Reader.parse(res, Root);

				array<string> author;
				if (Root["data"]["related_up"].isArray()) {
					for (int i = 0; i < Root["data"]["related_up"].size(); i++) {
						author.insertLast("@" + Root["data"]["related_up"][i]["uname"].asString());
					}
				}
				MetaData["author"] = join(author, ",");
				MetaData["viewCount"] = Root["data"]["stat"]["reply"].asString();
				MetaData["likeCount"] = Root["data"]["stat"]["like"].asString();
			}
			break;
		}
	}

	url = AppendBangumiQualityList(epid, path, MetaData, QualityList);
	log("url", url);

	if (ConfigData.heartBeat) SetIds(parseInt(aid), bvid, parseInt(cid), parseInt(epid), parseInt(ssid), ConfigData.mid);

	return url;
}

string Video(string id, const string&in path, dictionary& MetaData, array<dictionary>& QualityList) {
	log("==============================video=============================");
	string url;
	string res;
	string bvid;
	string aid;
	string cid;
	string title;
	string params;
	string query = HostRegExpParse(path, "^[^?#]*\\?([^#]*)");
	int64 duration;
	string thumbnail;
	string date;
	JsonReader reader;
	JsonValue Root;
	array<string> queryParts;

	if (id.find("BV") == 0) {
		bvid = id;
		queryParts.insertLast("bvid=" + id);
	}
	string parsedAid = parseAVId(path);
	if (!parsedAid.empty()) {
		aid = parsedAid;
		queryParts.insertLast("aid=" + parsedAid);
	}

	params = join(queryParts, "&");

	res = apiPost("/x/web-interface/wbi/view/detail?" + encWbi(params));
	if (!reader.parse(res, Root) || !Root.isObject()) return url;
	JsonValue view = Root["data"]["View"];
	if (view["redirect_url"].isString()) {
		string redirect = view["redirect_url"].asString();
		if (!query.empty()) redirect += (redirect.find("?") >= 0 ? "&" : "?") + query;
		return Bangumi(makeWebUrl(redirect), MetaData, QualityList);
	}

	bvid = view["bvid"].asString();
	aid = view["aid"].asString();
	cid = view["cid"].asString();
	title = view["title"].asString();
	duration = view["duration"].asInt() * 1000;
	thumbnail = view["pic"].asString();
	date = UnixTimeToDateTime(view["pubdate"].asInt64());

	int p = 1;
	if (view["pages"].isArray() && view["pages"].size() > 0) {
		p = parseInt(parse(path, "p", "1"));
		if (p <= 0 || p > view["pages"].size()) {
			p = 1;
		}

		JsonValue page = view["pages"][p - 1];

		if (page["cid"].isInt64() && !page["cid"].asString().isEmpty()) {
			cid = page["cid"].asString();
		}

		if (view["pages"].size() > 1) {
			title = view["title"].asString() + "\n" + page["part"].asString();
		}

		duration = page["duration"].asInt() * 1000;
		thumbnail = page["first_frame"].asString();
		date = UnixTimeToDateTime(page["ctime"].asInt64());
	}

	string author;
	array<string> staff;
	if (view["staff"].isArray() && view["staff"].size() > 0) {
		for (uint i = 0; i < view["staff"].size(); i++) {
			staff.insertLast("@" + view["staff"][i]["name"].asString());
		}
		author = join(staff, ", ");
	} else {
		author = "@" + view["owner"]["name"].asString();
	}

	string chatUrl;
	string chatScript;
	string webUrl = "https://www.bilibili.com/video/" + bvid + (p > 1 ? "?p=" + formatInt(p) : "");
	int seek = GetStartSeconds(path, aid, cid);
	if (ConfigData.enableVodChatUrl && HostFileExist(ConfigData.ChatScriptVod)) {
		chatUrl = webUrl;
		chatScript = ReadWebScript(ConfigData.ChatScriptVod);
	}

	bool is360;
	if (view["rights"]["is_360"].isInt()) is360 = view["rights"]["is_360"].asInt() != 0;

	bool isSteinGate;
	if (view["rights"]["is_stein_gate"].isInt()) isSteinGate = view["rights"]["is_stein_gate"].asInt() != 0;

	bool is_upower_exclusive = view["is_upower_exclusive"].asBool();
	bool is_upower_preview = view["is_upower_preview"].asBool();
	if (is_upower_exclusive) title = "【充电专属】\n" + title;

	JsonValue playerInfo, viewPoints;
	string playerResponse = apiPost("/x/player/wbi/v2?" + encWbi("aid=" + aid + "&cid=" + cid));
	if (reader.parse(playerResponse, playerInfo) && playerInfo.isObject() && playerInfo["code"].isNumeric() && playerInfo["code"].asInt() == 0 && playerInfo["data"].isObject()) {
		viewPoints = playerInfo["data"]["view_points"];
	}

	if (@MetaData !is null) {
		MetaData["vid"] = "bilibili.com|" + cid;
		MetaData["title"] = title;
		MetaData["duration"] = formatInt(duration);
		MetaData["thumbnail"] = thumbnail;
		MetaData["author"] = author;
		MetaData["content"] = view["desc"].asString();
		MetaData["webUrl"] = webUrl;
		MetaData["viewCount"] = view["stat"]["view"].asString();
		MetaData["likeCount"] = view["stat"]["like"].asString();
		MetaData["dislikeCount"] = view["stat"]["dislike"].asString();
		MetaData["date"] = date;
		MetaData["is360"] = is360;
		MetaData["fileExt"] = "mp4";
		if (seek > 0) MetaData["seek"] = seek;
		if (!chatUrl.isEmpty()) MetaData["chatUrl"] = chatUrl;
		if (!chatUrl.isEmpty() && !chatScript.isEmpty()) MetaData["chatScript"] = chatScript;

		array<dictionary> chapter = generateChapter(viewPoints, bvid, float(duration), false);
		if (!chapter.empty()) MetaData["chapter"] = chapter;

		array<dictionary> subtitle = generateSubtitle(aid, cid, duration, false);
		if (!subtitle.empty()) MetaData["subtitle"] = subtitle;
	}

	if (is_upower_exclusive) {
		if (is_upower_preview) {
			HostMessageBox("该视频为充电视频，试看中...", "BilibiliPotPlayer", 0, 0);
		} else {
			HostMessageBox("该视频为充电视频, 且不支持试看...", "BilibiliPotPlayer", 0, 0);
			if (@MetaData !is null) MetaData["fileExt"] = "jpg";
			return view["pic"].asString();
		}
	}

	if (isSteinGate) {
		HostMessageBox("该视频为互动视频\n请点击左下角up主名字 "+ author +" 进入网页端观看", "BilibiliPotPlayer", 0, 0);
	}

	url = AppendVideoQualityList(bvid, aid, cid, QualityList);
	log("url", url);

	if (ConfigData.heartBeat) SetIds(parseInt(aid), bvid, parseInt(cid), 0, 0, ConfigData.mid);

	return url;
}

string Live(string id, const string&in path, dictionary& MetaData, array<dictionary>& QualityList) {
	log("==============================live==============================");
	string url;
	string res;

	res = apiPost("/xlive/web-room/v1/index/getInfoByRoom?room_id=" + id, "", "https://api.live.bilibili.com");
	JsonReader Reader;
	JsonValue Root;
	if (!Reader.parse(res, Root) || !Root.isObject() || Root["code"].asInt() != 0) return url;
	if (!Root["data"].isObject() || !Root["data"]["room_info"].isObject()) return url;

	JsonValue data = Root["data"]["room_info"];
	string room_id = data["room_id"].asInt();

	string title;
	string area_title = data["parent_area_name"].asString().isEmpty() ? data["area_name"].asString() : data["area_name"].asString().isEmpty() ? data["parent_area_name"].asString() : data["parent_area_name"].asString() + " (" + data["area_name"].asString() + ")";
	if (!area_title.isEmpty()) {
		title = area_title + "\n" + data["title"].asString();
	} else {
		title = data["title"].asString();
	}

	string thumbnail;
	if (ConfigData.useKeyframe && data["keyframe"].isString() && !data["keyframe"].asString().isEmpty()) {
		thumbnail = data["keyframe"].asString();
	} else {
		thumbnail = data["cover"].asString();
	}

	string fileExt;
	int live_status = data["live_status"].asInt();
	if (live_status == 1) {
		fileExt = "mp4";
	} else {
		fileExt = "png";
	}

	string chatUrl;
	string chatScript;
	if (ConfigData.useBilibiliDanmuji && !ConfigData.bilibiliDanmujiServer.isEmpty()) {
		string host = HostRegExpParse(ConfigData.bilibiliDanmujiServer, "^https?://([^/]+)");
		chatUrl = ConfigData.bilibiliDanmujiServer + "/danmu_widget?sub=ws://" + host + "/danmu/sub";
	} else if (ConfigData.liveChatUrlUseWebPage && HostFileExist(ConfigData.ChatScriptLive)) {
		chatUrl = "https://live.bilibili.com/blanc/" + room_id;
		chatScript = ReadWebScript(ConfigData.ChatScriptLive);
	}

	int special_type = data["special_type"].asInt();

	if (@MetaData !is null) {
		MetaData["vid"] = id;
		MetaData["title"] = title;
		MetaData["thumbnail"] = thumbnail;
		MetaData["author"] = "@" + Root["data"]["anchor_info"]["base_info"]["uname"].asString();
		MetaData["content"] = data["description"].asString();
		MetaData["webUrl"] = makeWebUrl(path);
		MetaData["viewCount"] = Root["data"]["watched_show"]["num"].asString();
		MetaData["likeCount"] = Root["data"]["like_info_v3"]["total_likes"].asString();
		MetaData["date"] = UnixTimeToDateTime(data["live_start_time"].asInt64());
		MetaData["fileExt"] = fileExt;
		if (!chatUrl.isEmpty()) MetaData["chatUrl"] = chatUrl;
		if (!chatUrl.isEmpty() && !chatScript.isEmpty()) MetaData["chatScript"] = chatScript;
	}

	if (live_status != 1) {
		HostMessageBox(Root["data"]["anchor_info"]["base_info"]["uname"].asString() + " 当前未开播", "BilibiliPotPlayer", 0, 0);
		url = "https://i1.hdslb.com/bfs/static/blive/blfe-live-room/static/img/player-bg.866a348..png";

		return url;
	} else if (special_type == 1) {
		HostMessageBox("当前直播间为大航海专属", "BilibiliPotPlayer", 0, 0);
	}

	status = 5;

	string default_protocol = ConfigData.useHttpStream ? "http_stream" : "http_hls";
	array<int> accept_qns;
	string default_format;
	int qn = 20000;

	string param = "room_id=" + room_id + "&protocol=0,1&format=0,1,2&codec=0,1,2&qn=" + qn + "&platform=web&ptype=8&dolby=5&panorama=1&eotf=0,1,2&req_reason=0&supported_drms=0";
	res = apiPost("/xlive/web-room/v2/index/getRoomPlayInfo?" + encWbi(param), "", "https://api.live.bilibili.com");

	if (!Reader.parse(res, Root) || !Root.isObject() || Root["code"].asInt() != 0) {
		return url;
	}

	JsonValue playurl = Root["data"]["playurl_info"]["playurl"];
	if (!playurl.isObject()) {
		log('Root["data"]["playurl_info"]["playurl"] is not exists.');
		return url;
	}

	JsonValue g_qn_desc = playurl["g_qn_desc"];
	if (!g_qn_desc.isArray()) {
		log('Root["data"]["playurl_info"]["playurl"]["g_qn_desc"] is not array.');
		return url;
	}

	JsonValue streams = playurl["stream"];
	if (!streams.isArray()) {
		log('streams is not array.');
		return url;
	}

	for (int s = 0; s < streams.size(); s++) {
		if (streams[s]["protocol_name"].asString() != default_protocol) {
			continue;
		}

		JsonValue formats = streams[s]["format"];
		if (!formats.isArray()) {
			continue;
		}

		if (ConfigData.useHttpStream) {
			for (int a = 0; a < formats.size(); a++) {
				if (formats[a]["format_name"].asString() == "flv") {
					default_format = "flv";
					break;
				}
			}
		} else {
			// 一些小主播不提供 fmp4，优先选择 fmp4，其次 ts
			for (int a = 0; a < formats.size(); a++) {
				string format_name_candidate = formats[a]["format_name"].asString();
				if (format_name_candidate == "fmp4") {
					default_format = "fmp4";
					break;
				}
				if (format_name_candidate == "ts" && default_format.empty()) {
					default_format = "ts";
				}
			}
		}

		if (default_format.empty()) {
			if (ConfigData.useHttpStream) {
				log("formats(flv) is not exists.");
			} else {
				log("formats(fmp4 and ts) is not exists.");
			}
			continue;
		}

		for (int f = 0; f < formats.size(); f++) {
			if (formats[f]["format_name"].asString() != default_format) {
				continue;
			}

			JsonValue codecs = formats[f]["codec"];
			if (!codecs.isArray()) {
				continue;
			}

			for (int i = 0; i < codecs.size(); i++) {
				JsonValue codec = codecs[i];

				JsonValue qnValue = codec["accept_qn"];
				if (qnValue.isArray()) {
					for (int j = 0; j < qnValue.size(); j++) {
						int qn = qnValue[j].asInt();

						if (accept_qns.find(qn) < 0) {
							accept_qns.insertLast(qn);
						}
					}
				}
			}
		}
	}

	int best_qn = 0;
	accept_qns.sortAsc();
	for (int i = 0; i < accept_qns.size(); i++) {
		if (best_qn < accept_qns[i]) {
			best_qn = accept_qns[i];
		}
	}

	int itag = 0;
	for (int i = 0; i < accept_qns.size(); i++) {
		qn = accept_qns[i];

		string param = "room_id=" + room_id + "&protocol=0,1&format=0,1,2&codec=0,1,2&qn=" + qn + "&platform=web&ptype=8&dolby=5&panorama=1&eotf=0,1,2&req_reason=0&supported_drms=0";
		res = apiPost("/xlive/web-room/v2/index/getRoomPlayInfo?" + encWbi(param), "", "https://api.live.bilibili.com");

		if (!Reader.parse(res, Root) || !Root.isObject() || Root["code"].asInt() != 0) {
			return url;
		}

		JsonValue playurl = Root["data"]["playurl_info"]["playurl"];
		if (!playurl.isObject()) {
			log('Root["data"]["playurl_info"]["playurl"] is not exists.');
			return url;
		}

		g_qn_desc = playurl["g_qn_desc"];
		if (!g_qn_desc.isArray()) {
			log('Root["data"]["playurl_info"]["playurl"]["g_qn_desc"] is not array.');
			return url;
		}

		JsonValue streams = playurl["stream"];
		if (!streams.isArray()) {
			log('streams is not array.');
			return url;
		}

		for (int s = 0; s < streams.size(); s++) {
			if (streams[s]["protocol_name"].asString() != default_protocol) {
				continue;
			}

			JsonValue formats = streams[s]["format"];
			if (!formats.isArray()) {
				continue;
			}

			for (int f = 0; f < formats.size(); f++) {
				if (formats[f]["format_name"].asString() != default_format) {
					continue;
				}

				JsonValue codecs = formats[f]["codec"];
				if (!codecs.isArray()) {
					continue;
				}

				for (int i = 0; i < codecs.size(); i++) {
					JsonValue codec = codecs[i];
					string codec_name = codec["codec_name"].asString();

					if (codec["current_qn"].asInt() != qn) {
						continue;
					}

					int codecid = int(ConfigData.codecNameToCodeId[codec["codec_name"].asString()]);

					JsonValue url_infos = codec["url_info"];
					if (!url_infos.isArray() || url_infos.size() == 0) {
						continue;
					}

					for (int j = 0; j < url_infos.size(); j++) {
						string url_info_url = codec["url_info"][j]["host"].asString() +
							codec["base_url"].asString() +
							codec["url_info"][j]["extra"].asString();

						bool urlExists = false;
						if (@QualityList !is null) {
							for (int k = 0; k < QualityList.size(); k++) {
								string temp_url;
								QualityList[k].get("url", temp_url);

								if (temp_url == url_info_url) {
									urlExists = true;
									break;
								}
							}
						}

						if (urlExists) {
							continue;
						}

						if (ConfigData.blockP2PCDN && isP2PCDN(url_info_url)) {
							continue;
						}

						url = url_info_url;

						JsonValue video_color_info = codec["video_color_info"];

						int width = codec["media_info"]["width"].asInt();
						int height = codec["media_info"]["height"].asInt();

						int bitrateVal = parseInt(parse(url_info_url, "origin_bitrate"));
						string bitrate = HostFormatBitrate(bitrateVal * 1000.0) + "bps";

						bool isHDR = (codec["hdr_type"].asInt() == 1);

						string format = default_format + ", " + codec_name + ", " + bitrate;

						string quality = getLiveQuality(
							g_qn_desc,
							codec["current_qn"].asInt(),
							codec["hdr_type"].asInt(),
							video_color_info
						);

						string qualityDetail;

						if (j == 0) {
							qualityDetail = quality + " - 主 ";
						}

						if (j > 0) {
							string backup = " - 备 ";

							if (j > 1) {
								backup += j - 1;
							}

							qualityDetail = quality + backup;
						}

						if (itag <= 0 || HostExistITag(itag)) {
							itag = HostGetITag(height, 0, true, true);
						}

						while (HostExistITag(itag)) {
							itag++;
						}

						HostSetITag(itag);

						bool videoIsDefault = (best_qn == codec["current_qn"].asInt() && i == codecs.size() - 1 && j == 0) ? true : false;

						QualityListItem item;

						item.url = url_info_url;
						item.bitrateVal = bitrateVal;
						item.bitrate = bitrate;
						item.resolution = width + "x" + height;
						item.isHDR = isHDR;
						item.format = format;
						item.quality = quality;
						item.qualityDetail = qualityDetail;
						item.itag = itag;
						item.videoIsDefault = videoIsDefault;
						item.qn = codec["current_qn"].asInt();
						item.codecid = codecid;
						item.va = "va";

						if (@QualityList !is null) {
							QualityList.insertLast(item.toDictionary());
						}
					}
				}
			}
		}
	}

	if (!ConfigData.useHttpStream && ConfigData.parseM3u8RealUrl) {
		status = 7;

		for (int i = 0; i < QualityList.size(); i++) {
			string item_url;
			QualityList[i].get("url", item_url);
			if (item_url.isEmpty()) continue;

			item_url = GetM3u8RealURL(item_url);
			QualityList[i]["url"] = item_url;
			url = item_url;
		}
	}

	if (QualityList.size() > 1) {
		string bestUrl = getBestUrl(QualityList, best_qn);

		if (!bestUrl.isEmpty()) {
			url = bestUrl;
		}
	}

	log("url", url);
	return url;
}

string Audio(const string&in path, dictionary& MetaData, array<dictionary>& QualityList) {
	string id = HostRegExpParse(path, "/audio/au([0-9]+)");
	JsonReader Reader;
	JsonValue Root;
	string url;
	string res;

	res = post("https://www.bilibili.com/audio/music-service-c/web/song/info?sid=" + id);
	res = HostDecompress(res);
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() != 0) {
			return "";
		}
		JsonValue data = Root["data"];
		MetaData["title"] = data["title"].asString();
		MetaData["thumbnail"] = data["cover"].asString();
		if (data["author"].isString()) MetaData["author"] = "@" + data["author"].asString();
	}

	status = 5;
	res = post("https://www.bilibili.com/audio/music-service-c/web/url?privilege=2&quality=2&sid=" + id);
	res = HostDecompress(res);
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() != 0) {
			return "";
		}
		JsonValue data = Root["data"]["cdns"];
		if (data.isArray()) {
			return data[0].asString();
		}
	}
	return url;
}

array<dictionary> webDynamic(string path) {
	array<dictionary> videos;
	string offset;
	JsonReader Reader;
	JsonValue Root;
	string type = parse(path, "tab");
	if (type != "video") {
		type = "all";
	}

	while(videos.size() < ConfigData.webDynamicVideoNums) {		
		string url = "/x/polymer/web-dynamic/v1/feed/all?timezone_offset=-480&type=" + type + "&offset=" + offset;
		string res = apiPost(url, false);
		if (Reader.parse(res, Root) && Root.isObject()) {
			if (Root["code"].asInt() != 0) {
				return videos;
			}
			JsonValue list = Root["data"]["items"];
			if (list.isArray()) {
				for (int j = 0; j < list.size(); j++) {
					JsonValue dynamic = list[j]["modules"]["module_dynamic"];
					if (dynamic.isObject()) {
						JsonValue major = dynamic["major"];
						if (!major.isObject()) continue;

						string author = "@" + list[j]["modules"]["module_author"]["name"].asString();
						// string date = UnixTimeToDateTime(parseInt(list[j]["modules"]["module_author"]["pub_ts"].asString()));
						string date = list[j]["modules"]["module_author"]["pub_time"].asString();

						JsonValue archive = major["archive"];
						if (archive.isObject()) {
							if (archive["bvid"].isString() && !archive["bvid"].asString().empty()) {
								string bvid = archive["bvid"].asString();
								string title = archive["title"].asString();
								string badge_text = "【" + archive["badge"]["text"].asString() + "】";

								dictionary video;

								video["title"] = badge_text + "\n" + archive["title"].asString();
								video["duration"] = parseTime(archive["duration_text"].asString());
								video["url"] = "https://www.bilibili.com/video/" + bvid;
								video["thumbnail"] = archive["cover"].asString();
								video["author"] = author;
								video["date"] = date;

								videos.insertLast(video);
							}
							continue;
						}
						JsonValue live_rcmd = major["live_rcmd"];
						if (live_rcmd.isObject()) {
							string content_str = live_rcmd["content"].asString();
							JsonValue content;
							if (Reader.parse(content_str, content) && content.isObject()) {
								if (content["live_play_info"]["live_status"].asInt() == 1) {
									string parent_area_name = content["live_play_info"]["parent_area_name"].asString();
									string area_name = content["live_play_info"]["area_name"].asString();

									dictionary live;

									live["title"] = "【直播】" + "\n" + parent_area_name + " (" + area_name + ") " + "\n" + content["live_play_info"]["title"].asString();
									live["url"] = "https://live.bilibili.com/" + content["live_play_info"]["room_id"].asString();
									live["thumbnail"] = content["live_play_info"]["cover"].asString();
									live["author"] = author;
									live["date"] = UnixTimeToDateTime(content["live_play_info"]["live_start_time"].asInt64());

									videos.insertLast(live);
								}
							}
							continue;
						}
						JsonValue pgc = major["pgc"];
						if (pgc.isObject()) {
							if (pgc["epid"].isString() && !pgc["epid"].asString().empty()) {
								string title = pgc["title"].asString();
								string badge_text = "【" + pgc["badge"]["text"].asString() + "】";

								dictionary pgc_video;

								pgc_video["title"] = badge_text + "\n" + pgc["title"].asString();
								pgc_video["url"] = pgc["jump_url"].asString();
								pgc_video["thumbnail"] = pgc["cover"].asString();
								pgc_video["author"] = author;
								pgc_video["date"] = list[j]["modules"]["module_author"]["pub_time"].asString();
								pgc_video["referer"] = pgc["jump_url"].asString();

								videos.insertLast(pgc_video);
							}
							continue;
						}
					}
				}
			}
		}

		if (offset == Root["data"]["offset"].asString()) break;
		offset = Root["data"]["offset"].asString();
	}
	return videos;
}

array<dictionary> Search(string path) {
	log("================================Search===========================");
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;
	string kw;

	path = HostUrlDecode(path);

	if (path.find("?WithCaption") >= 0) {
		path.replace("?WithCaption", "");
		kw = parse(path, "keyword");
	} else {
		kw = parse(path, "keyword");
	}
	if (kw.empty()) {
		return videos;
	}
	kw = HostUrlEncode(kw);

	string type = HostRegExpParse(path, "search.bilibili.com/([a-zA-Z0-9]+)");
	string url;
	if (type == "all") {
		string params = "keyword=" + kw;
		url = "/x/web-interface/wbi/search/all/v2?" + encWbi(params);
	} else if (type == "video") {
		string params = "search_type=video&keyword=" + kw;
		url = "/x/web-interface/wbi/search/type?" + encWbi(params);
	} else {
		return videos;
	}
	string res = apiPost(url);
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() != 0) {
			return videos;
		}
		JsonValue list;
		if (type == "all") {
			for (int i = 0; i < Root["data"]["result"].size(); i++) {
				if (Root["data"]["result"][i]["result_type"].asString() == "video") {
					list = Root["data"]["result"][i]["data"];
					break;
				}
			}
		} else if (type == "video") {
			list = Root["data"]["result"];
		} else {
			return videos;
		}
		for (int i = 0; i < list.size(); i++) {
			JsonValue item = list[i];
			dictionary video;

			string title = item["title"].asString();
			title.replace("<em class=\"keyword\">", '');
			title.replace("</em>", '');
			video["title"] = title;
			video["content"] = title;
			video["duration"] = parseTime(item["duration"].asString());
			video["url"] = "https://www.bilibili.com/video/" + item["bvid"].asString();
			video["thumbnail"] = "https:" + item["pic"].asString();
			video["author"] = "@" + item["author"].asString();
			video["date"] = UnixTimeToDateTime(item["pubdate"].asInt64());

			videos.insertLast(video);
		}
	}
	return videos;
}

array<dictionary> spaceVideo(string path) {
	array<dictionary> videos;
	int ps = 50;
	int page = parseInt(parse(path, "pn", "1"));
	int pn = page;
	string baseurl = "/x/space/wbi/arc/search?";
	string params1;
	string params2;
	params1 += "keyword=" + parse(path, "keyword");
	params1 += "&mid=" + HostRegExpParse(path, "/([0-9]+)");
	params1 += "&order=" + parse(path, "order", "pubdate");

	params2 += "&ps=" + ps;
	params2 += "&tid=" + parse(path, "tid", "0");
	while (true) {
		if (pn - page >= 10) {
			break;
		}
		string params = params1 + "&pn=" + pn + params2;
		string url = baseurl + encWbi(params);
		string res = apiPost(url);
		JsonReader Reader;
		JsonValue Root;
		if (Reader.parse(res, Root) && Root.isObject()) {
			if (Root["code"].asInt() == 0) {
				JsonValue data = Root["data"]["list"]["vlist"];
				if (data.isArray()) {
					for (int i = 0; i < data.size(); i++) {
						JsonValue item = data[i];
						if (item.isObject()) {
							dictionary video;

							video["title"] = item["title"].asString();
							video["duration"] = parseTime(item["length"].asString());
							video["thumbnail"] = item["pic"].asString();
							video["author"] = "@" + item["author"].asString();
							video["url"] = "https://www.bilibili.com/video/" + item["bvid"].asString();
							if (!item["description"].asString().empty() && item["description"].asString() != "-") video["content"] = item["description"].asString();
							video["viewCount"] = item["play"].asString();
							video["date"] = UnixTimeToDateTime(item["created"].asInt64());

							videos.insertLast(video);
						}
					}
				}
				JsonValue page = Root["data"]["page"];
				if (page["pn"].asInt() * page["ps"].asInt() >= page["count"].asInt()) {
					break;
				}
				pn += 1;
			} else {
				return videos;
			}
		} else {
			return videos;
		}
	}
	return videos;
}

array<dictionary> spaceDynamic(string path) {
	log("==================================spaceDynamic====================================");
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;
	string host_mid;
	string offset;

	host_mid = HostRegExpParse(path, "/([0-9]+)/[a-zA-Z0-9]");
	if (host_mid.isEmpty()) return videos;

	while(videos.size() < ConfigData.spaceDynamicVideoNums) {
		string params = "offset=" + offset + "&host_mid=" + host_mid + "&timezone_offset=-480";
		string url = "/x/polymer/web-dynamic/v1/feed/space?" + encWbi(params);
		string res = apiPost(url, false);
		if (!Reader.parse(res, Root) || !Root.isObject()) return videos;
		if (Root["code"].asInt() != 0) return videos;

		JsonValue list = Root["data"]["items"];
		if (!list.isArray()) return videos;

		for (int j = 0; j < list.size(); j++) {
			JsonValue dynamic = list[j]["modules"]["module_dynamic"];
			if (dynamic.isObject()) {
				JsonValue major = dynamic["major"];
				if (!major.isObject()) continue;

				string author = "@" + list[j]["modules"]["module_author"]["name"].asString();
				string date = UnixTimeToDateTime(parseInt(list[j]["modules"]["module_author"]["pub_ts"].asString()));

				JsonValue archive = major["archive"];
				if (archive.isObject()) {
					if (archive["bvid"].isString() && !archive["bvid"].asString().empty()) {
						string bvid = archive["bvid"].asString();
						dictionary video;

						video["title"] = "视频 | " + archive["title"].asString();
						video["duration"] = parseTime(archive["duration_text"].asString());
						video["url"] = "https://www.bilibili.com/video/" + bvid;
						video["thumbnail"] = archive["cover"].asString();
						video["author"] = author;
						video["date"] = date;

						videos.insertLast(video);
					}
					continue;
				}
				JsonValue live_rcmd = major["live_rcmd"];
				if (live_rcmd.isObject()) {
					string content_str = live_rcmd["content"].asString();
					JsonValue content;
					if (Reader.parse(content_str, content) && content.isObject()) {
						if (content["live_play_info"]["live_status"].asInt() == 1) {
							dictionary live;

							live["title"] = "直播 | " + content["live_play_info"]["title"].asString();
							live["url"] = "https://live.bilibili.com/" + content["live_play_info"]["room_id"].asString();
							live["thumbnail"] = content["live_play_info"]["cover"].asString();
							live["author"] = author;

							videos.insertLast(live);
						}
					}
					continue;
				}
			}
		}

		if (offset == Root["data"]["offset"].asString()) break;
		offset = Root["data"]["offset"].asString();
	}

	return videos;
}

array<dictionary> spaceSeason(string path) {
	array<dictionary> videos;
	int page_size = 20;
	int page_num = 1;
	string uid = HostRegExpParse(path, "/([0-9]+)/lists");
	string sid = HostRegExpParse(path, "lists/([0-9]+)");
	string baseurl;
	bool isCollection = parse(path, "type") == "season";
	if (isCollection) {
		baseurl = "/x/polymer/web-space/seasons_archives_list?mid=" + uid + "&season_id=" + sid + "&sort_reverse=" + parse(path, "sort_reverse", "false") + "&page_size=" + page_size;
		while (true) {
			string url;
			url = baseurl + "&page_num=" + page_num;
			string res = apiPost(url);
			JsonReader Reader;
			JsonValue Root;
			if (Reader.parse(res, Root) && Root.isObject()) {
				if (Root["code"].asInt() == 0) {
					JsonValue data = Root["data"]["archives"];
					if (data.isArray()) {
						for (int i = 0; i < data.size(); i++) {
							JsonValue item = data[i];
							if (item.isObject()) {
								dictionary video;

								video["title"] = item["title"].asString();
								video["duration"] = item["duration"].asInt() * 1000;
								video["url"] = "https://www.bilibili.com/video/" + item["bvid"].asString();
								video["thumbnail"] = item["pic"].asString();
								video["date"] = UnixTimeToDateTime(item["pubdate"].asInt64());

								videos.insertLast(video);
							}
						}
					}
					JsonValue page = Root["data"]["page"];
					if (page["page_num"].asInt() * page["page_size"].asInt() >= page["total"].asInt()) {
						break;
					}
					page_num += 1;
				} else {
					return videos;
				}
			} else {
				return videos;
			}
		}
	} else {
		baseurl = "/x/polymer/web-space/seasons_series_list?mid=" + uid + "&page_size=" + page_size;
		while (true) {
			string url;
			url = baseurl + "&page_num=" + page_num;
			string res = apiPost(url);
			JsonReader Reader;
			JsonValue Root;

			if (!Reader.parse(res, Root) || !Root.isObject()) return videos;

			JsonValue seasons_lists = Root["data"]["items_lists"]["seasons_list"];
			if (seasons_lists.isArray()) {
				for (int j = 0; j < seasons_lists.size(); j++) {
					JsonValue seasons_list = seasons_lists[j];
					string title = seasons_list["meta"]["name"].asString();
					JsonValue data = seasons_list["archives"];
					if (data.isArray()) {
						for (int i = 0; i < data.size(); i++) {
							JsonValue item = data[i];
							if (item.isObject()) {
								dictionary video;

								video["title"] = "【" + title + "】-" + item["title"].asString();
								video["duration"] = item["duration"].asInt() * 1000;
								video["url"] = "https://www.bilibili.com/video/" + item["bvid"].asString();
								video["thumbnail"] = item["pic"].asString();
								video["date"] = UnixTimeToDateTime(item["pubdate"].asInt64());

								videos.insertLast(video);
							}
						}
					}
				}
			}
			JsonValue page = Root["data"]["items_lists"]["page"];
			if (page["page_num"].asInt() * page["page_size"].asInt() >= page["total"].asInt()) {
				break;
			}
			page_num += 1;
		}
	}

	return videos;
}

array<dictionary> spaceAudio(string path) {
	array<dictionary> audios;
	int ps = 50;
	int pn = 1;
	string baseurl = "/audio/music-service/web/song/upper?";
	baseurl += "uid=" + HostRegExpParse(path, "/([0-9]+)");
	baseurl += "&ps=" + ps;
	baseurl += "&order=" + parse(path, "order", "1");
	while (true) {
		string url = baseurl + "&pn=" + pn;
		string res = apiPost(url);
		JsonReader Reader;
		JsonValue Root;
		if (Reader.parse(res, Root) && Root.isObject()) {
			if (Root["code"].asInt() == 0) {
				JsonValue data = Root["data"]["data"];
				if (data.isArray()) {
					for (int i = 0; i < data.size(); i++) {
						JsonValue item = data[i];
						if (item.isObject()) {
							dictionary audio;

							audio["title"] = item["title"].asString();
							audio["duration"] = item["duration"].asInt() * 1000;
							audio["url"] = "https://www.bilibili.com/audio/au" + item["id"].asString();
							audio["thumbnail"] = item["cover"].asString();

							audios.insertLast(audio);
						}
					}
				}
				if (Root["data"]["curPage"].asInt() >= Root["data"]["pageCount"].asInt()) {
					break;
				}
				pn += 1;
			} else {
				return audios;
			}
		} else {
			return audios;
		}
	}
	return audios;
}

array<dictionary> followingLive() {
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;
	int page = 1;

	while (true) {
		string url = "/xlive/web-ucenter/user/following?page=" + page + "&page_size=10&hit_ab=true";
		string res = apiPost(url, "", "https://api.live.bilibili.com", false);

		if (!Reader.parse(res, Root) || !Root.isObject() || Root["code"].asInt() != 0) break;

		JsonValue data = Root["data"];
		JsonValue list = data["list"];

		if (!list.isArray()) break;

		bool hasOffline = false;

		for (int i = 0; i < list.size(); i++) {
			JsonValue item = list[i];

			if (item["live_status"].asInt() == 0) {
				hasOffline = true;
				break;
			}

			dictionary video;

			video["title"] = item["area_name_v2"].asString() + "\n" + item["title"].asString();
			video["url"] = "https://live.bilibili.com/" + item["roomid"].asString();
			video["thumbnail"] = item["room_cover"].asString();
			video["author"] = "@" + item["uname"].asString();

			videos.insertLast(video);
		}

		if (hasOffline) break;
		uint totalPage = data["totalPage"].asUInt();
		if (page >= totalPage) break;
		page++;
	}

	if (videos.size() == 0) {
		HostMessageBox("[正在直播] 列表是空的，刷点别的视频吧。", "BilibiliPotPlayer", 2, 0);
	}

	return videos;
}

array<dictionary> liveCategory(string path, int areaId = 0, int parentAreaId = 0) {
	JsonReader Reader;
	JsonValue Root;

	string renderData = HostRegExpParse(post(path), "window\\._render_data_\\s*=\\s*(\\{\"access_id\":\"[^\"]+\"\\})");
	if (!Reader.parse(renderData, Root) || !Root.isObject()) return array<dictionary>();
	string w_webid = Root["access_id"].asString();

	if (parentAreaId == 0) parentAreaId = parseInt(HostRegExpParse(path, "parentAreaId=([0-9]+)"));
	if (areaId == 0) areaId = parseInt(HostRegExpParse(path, "areaId=([0-9]+)"));

	return liveCategory(areaId, parentAreaId, w_webid);
}

array<dictionary> liveCategory(int areaId, int parentAreaId, string w_webid) {
	log("============================== liveCategory ==============================");
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;
	int page = 1;

	while (videos.size() < ConfigData.maxliveroom) {
		string params = "platform=web&parent_area_id=" + parentAreaId + "&area_id=" + areaId + "&page=" + page + "&w_webid=" + w_webid;
		string url = "https://api.live.bilibili.com/xlive/web-interface/v1/second/getList?" + encWbi(params);
		string res = post(url);
		if (!Reader.parse(res, Root) || !Root.isObject()) return videos;		
		if (Root["code"].asInt() != 0) return videos;

		JsonValue list = Root["data"]["list"];
		if (!list.isArray()) return videos;

		for (int i = 0; i < list.size(); i++) {
			JsonValue item = list[i];
			string title;
			string area_title;
			string pendant_title;

			area_title = item["parent_name"].asString().isEmpty() ? item["area_name"].asString() : item["area_name"].asString().isEmpty() ? item["parent_name"].asString() : item["parent_name"].asString() + " (" + item["area_name"].asString() + ")";

			if (item["pendant_info"].isObject()) {
				JsonValue pendant_info = item["pendant_info"]; 
				array<string> pendant_infos;
				array<string> keys = item["pendant_info"].getKeys();

				for (int j = 0; j < keys.size(); j++) {
					pendant_infos.insertLast(pendant_info[keys[j]]["content"].asString().isEmpty() ? pendant_info[keys[j]]["name"].asString() : pendant_info[keys[j]]["content"].asString());
				}
				pendant_title = join(pendant_infos, " | ");
			}

			array<string> titles;
			if (!area_title.isEmpty()) titles.insertLast(area_title);
			titles.insertLast(item["title"].asString());
			if (!pendant_title.isEmpty()) titles.insertLast(pendant_title);

			title = join(titles, "\n");

			string thumbnail = ConfigData.useKeyframe && item["system_cover"].isString() && !item["system_cover"].asString().isEmpty() ? item["system_cover"].asString() : item["cover"].asString();

			dictionary video;

			video["title"] = title;
			video["url"] = "https://live.bilibili.com/" + item["roomid"].asInt();
			video["thumbnail"] = thumbnail;
			video["author"] = "@" + item["uname"].asString();

			videos.insertLast(video);
		}
		page++;
		if (Root["data"]["has_more"].asInt() != 1) return videos;
	}

	return videos;
}

array<dictionary> PopularAll() {
	array<dictionary> videos;
	int ps = 50;
	int pn = 1;

	while(pn <= ConfigData.popularAllPages) {
		JsonReader Reader;
		JsonValue Root;

		string param = "ps=" + ps + "&pn=" + pn;
		string res = apiPost("/x/web-interface/popular?" + encWbi(param, false), false);
		if (Reader.parse(res, Root) && Root.isObject()) {
			if (Root["code"].asInt() != 0) {
				return videos;
			}
			JsonValue list = Root["data"]["list"];
			if (list.isArray()) {
				for (int i = 0; i < list.size(); i++) {
					JsonValue item = list[i];
					dictionary video;

					video["title"] = item["title"].asString();
					video["duration"] = item["duration"].asInt() * 1000;
					video["url"] = "https://www.bilibili.com/video/" + item["bvid"].asString();
					video["thumbnail"] = item["pic"].asString();
					video["author"] = "@" + item["owner"]["name"].asString();
					video["date"] = UnixTimeToDateTime(item["pubdate"].asInt64());

					videos.insertLast(video);
				}
			}
		}

		pn++;
	}

	return videos;
}

array<dictionary> PopularWeekly(string path) {
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;
	string num = parse(path, "num");
	if (num.empty()) {
		string params = "web_location=0.0";
		string res = apiPost("/x/web-interface/popular/series/list?" + encWbi(params), false);
		if (Reader.parse(res, Root) && Root.isObject()) {
			if (Root["code"].asInt() != 0) {
				return videos;
			}
			JsonValue list = Root["data"]["list"];
			if (list.isArray()) {
				num = "" + list[0]["number"].asInt();
			}
		}
	}
	string params = "number=" + num;
	string res = apiPost("/x/web-interface/popular/series/one?" + encWbi(params), false);
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() != 0) {
			return videos;
		}
		JsonValue list = Root["data"]["list"];
		if (list.isArray()) {
			for (int i = 0; i < list.size(); i++) {
				JsonValue item = list[i];
				dictionary video;

				video["title"] = item["title"].asString();
				video["duration"] = item["duration"].asInt() * 1000;
				video["url"] = "https://www.bilibili.com/video/" + item["bvid"].asString();
				video["thumbnail"] = item["pic"].asString();
				video["author"] = "@" + item["owner"]["name"].asString();
				video["date"] = UnixTimeToDateTime(item["pubdate"].asInt64());

				videos.insertLast(video);
			}
		}
	}
	return videos;
}

array<dictionary> PopularHistory() {
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;
	string params = "page_size=100&page=1";
	string res = apiPost("/x/web-interface/popular/precious?" + encWbi(params), false);
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() != 0) {
			return videos;
		}
		JsonValue list = Root["data"]["list"];
		if (list.isArray()) {
			for (int i = 0; i < list.size(); i++) {
				JsonValue item = list[i];
				dictionary video;

				video["title"] = item["title"].asString();
				video["duration"] = item["duration"].asInt() * 1000;
				video["url"] = "https://www.bilibili.com/video/" + item["bvid"].asString();
				video["thumbnail"] = item["pic"].asString();
				video["author"] = "@" + item["owner"]["name"].asString();
				video["date"] = UnixTimeToDateTime(item["pubdate"].asInt64());

				videos.insertLast(video);
			}
		}
	}
	return videos;
}

array<dictionary> Ranking(string path) {
	array<dictionary> videos;

	string key = HostRegExpParse(path, "/v/popular/rank/([^/?#]+)");
	if (key.empty()) {
		return videos;
	}

	string configJson = '{'
		'"all":         {"title":"全部",     "api":"/x/web-interface/ranking/v2",        "rid":0},'
		'"anime":       {"title":"番剧",     "api":"/pgc/web/rank/list",                  "season_type":1},'
		'"guochuang":   {"title":"国创",     "api":"/pgc/season/rank/web/list",           "season_type":4},'
		'"documentary": {"title":"纪录片",   "api":"/pgc/season/rank/web/list",           "season_type":3},'
		'"movie":       {"title":"电影",     "api":"/pgc/season/rank/web/list",           "season_type":2},'
		'"tv":          {"title":"电视剧",   "api":"/pgc/season/rank/web/list",           "season_type":5},'
		'"variety":     {"title":"综艺",     "api":"/pgc/season/rank/web/list",           "season_type":7},'

		'"douga":       {"title":"动画",     "api":"/x/web-interface/ranking/v2",         "rid":1005},'
		'"game":        {"title":"游戏",     "api":"/x/web-interface/ranking/v2",         "rid":1008},'
		'"kichiku":     {"title":"鬼畜",     "api":"/x/web-interface/ranking/v2",         "rid":1007},'
		'"music":       {"title":"音乐",     "api":"/x/web-interface/ranking/v2",         "rid":1003},'
		'"dance":       {"title":"舞蹈",     "api":"/x/web-interface/ranking/v2",         "rid":1004},'
		'"cinephile":   {"title":"影视",     "api":"/x/web-interface/ranking/v2",         "rid":1001},'
		'"ent":         {"title":"娱乐",     "api":"/x/web-interface/ranking/v2",         "rid":1002},'
		'"knowledge":   {"title":"知识",     "api":"/x/web-interface/ranking/v2",         "rid":1010},'
		'"tech":        {"title":"科技数码", "api":"/x/web-interface/ranking/v2",         "rid":1012},'
		'"food":        {"title":"美食",     "api":"/x/web-interface/ranking/v2",         "rid":1020},'
		'"car":         {"title":"汽车",     "api":"/x/web-interface/ranking/v2",         "rid":1013},'
		'"fashion":     {"title":"时尚美妆", "api":"/x/web-interface/ranking/v2",         "rid":1014},'
		'"sports":      {"title":"体育运动", "api":"/x/web-interface/ranking/v2",         "rid":1018},'
		'"animal":      {"title":"动物",     "api":"/x/web-interface/ranking/v2",         "rid":1024}'
	'}';

	JsonReader Reader;
	JsonValue Config;

	if (!Reader.parse(configJson, Config) || !Config.isObject()) {
		return videos;
	}

	JsonValue config = Config[key];

	if (!config.isObject()) {
		return videos;
	}

	string api = config["api"].asString();
	JsonValue Root;
	string params;

	if (api == "/x/web-interface/ranking/v2") {
		params = "rid=" + config["rid"].asInt() + "&type=all&web_location=0.0";
		string res = apiPost(api + "?" + encWbi(params), false);

		if (!Reader.parse(res, Root) || !Root.isObject()) return videos;
		if (Root["code"].asInt() != 0) return videos;

		JsonValue list = Root["data"]["list"];
		if (!list.isArray()) return videos;

		for (int i = 0; i < list.size(); i++) {
			JsonValue item = list[i];
			dictionary video;

			video["title"] = item["title"].asString();
			video["duration"] = item["duration"].asInt() * 1000;
			video["url"] = "https://www.bilibili.com/video/" + item["bvid"].asString();
			video["thumbnail"] = item["pic"].asString();
			video["author"] = "@" + item["owner"]["name"].asString();
			video["date"] = UnixTimeToDateTime(item["pubdate"].asInt64());

			videos.insertLast(video);
		}
	}
	else if (api == "/pgc/web/rank/list") {
		params = "day=3&season_type=" + config["season_type"].asInt() + "&web_location=0.0";
		string res = apiPost(api + "?" + encWbi(params), false);

		if (!Reader.parse(res, Root) || !Root.isObject()) return videos;
		if (Root["code"].asInt() != 0) return videos;

		JsonValue list = Root["result"]["list"];
		if (!list.isArray()) return videos;

		for (int i = 0; i < list.size(); i++) {
			JsonValue item = list[i];
			dictionary video;

			video["title"] = item["title"].asString();
			// video["duration"] = item["duration"].asInt() * 1000;
			video["url"] = item["url"].asString();
			video["thumbnail"] = item["ss_horizontal_cover"].asString();
			// video["author"] = item["owner"]["name"].asString();
			// video["date"] = UnixTimeToDateTime(item["pubdate"].asInt64());
			video["viewCount"] = item["stat"]["view"].asString();

			videos.insertLast(video);
		}
	}
	else if (api == "/pgc/season/rank/web/list") {
		params = "day=3&season_type=" + config["season_type"].asInt() + "&web_location=0.0";
		string res = apiPost(api + "?" + encWbi(params), false);

		if (!Reader.parse(res, Root) || !Root.isObject()) return videos;
		if (Root["code"].asInt() != 0) return videos;

		JsonValue list = Root["data"]["list"];
		if (!list.isArray()) return videos;

		for (int i = 0; i < list.size(); i++) {
			JsonValue item = list[i];
			dictionary video;

			video["title"] = item["title"].asString();
			// video["duration"] = item["duration"].asInt() * 1000;
			video["url"] = item["url"].asString();
			video["thumbnail"] = item["ss_horizontal_cover"].asString();
			// video["author"] = item["owner"]["name"].asString();
			// video["date"] = UnixTimeToDateTime(item["pubdate"].asInt64());
			video["viewCount"] = item["stat"]["view"].asString();

			videos.insertLast(video);
		}
	}

	return videos;
}

array<dictionary> medialist(const string&in path) {
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;

	string uid = HostRegExpParse(path, "/list/([0-9]+)");
	string currentOid = parse(path, "oid");
	string currentBvid = parseBVId(path);
	string oid = "0";

	string baseurl = "/x/v2/medialist/resource/list?type=1&biz_id=" + uid;
	baseurl += "&ps=20&desc=true&sort_field=1&tid=" + parse(path, "tid", "0");
	baseurl += "&otype=2&direction=false&use_pn=false&pn=1";

	while (!uid.empty()) {
		string url = baseurl + "&oid=" + oid;
		url += "&with_current=" + (oid == "0" ? "true" : "false");
		string res = apiPost(url);

		if (!Reader.parse(res, Root) || !Root.isObject()) break;
		if (Root["code"].asInt() != 0) break;

		JsonValue data = Root["data"];
		JsonValue list = data["media_list"];
		if (!list.isArray() || list.size() == 0) break;

		for (int i = 0; i < list.size(); i++) {
			JsonValue item = list[i];
			if (!item.isObject()) continue;

			string bvid = item["bv_id"].asString();
			if (bvid.empty()) continue;

			dictionary video;
			video["title"] = item["title"].asString();
			video["duration"] = item["duration"].asInt() * 1000;
			video["url"] = "https://www.bilibili.com/video/" + bvid;
			video["thumbnail"] = item["cover"].asString();
			video["author"] = "@" + item["upper"]["name"].asString();
			video["date"] = UnixTimeToDateTime(item["pubtime"].asInt64());
			video["viewCount"] = item["cnt_info"]["play"].asString();
			video["likeCount"] = item["cnt_info"]["thumb_up"].asString();
			if (!item["intro"].asString().empty()) video["content"] = item["intro"].asString();
			if (item["id"].asString() == currentOid || bvid == currentBvid) video["current"] = "1";

			videos.insertLast(video);
		}

		if (!data["has_more"].asBool()) break;

		string nextOid = list[list.size() - 1]["id"].asString();
		if (nextOid.empty() || nextOid == oid) break;
		oid = nextOid;
	}

	return videos;
}

array<dictionary> watchlater() {
	array<dictionary> videos;
	string res = apiPost("/x/v2/history/toview/web", false);
	JsonReader Reader;
	JsonValue Root;
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() == 0) {
			JsonValue data = Root["data"]["list"];
			if (data.isArray()) {
				for (int i = 0; i < data.size(); i++) {
					JsonValue item = data[i];
					if (item.isObject()) {
						dictionary video;

						int p = item["page"]["page"].asInt();
						if (p == 1) {
							video["title"] = item["title"].asString();
						} else {
							video["title"] = item["title"].asString() + " | " + item["page"]["part"].asString();
						}
						video["duration"] = item["duration"].asInt() * 1000;
						video["url"] = makeWebUrl("https://www.bilibili.com/video/" + item["bvid"].asString() + "?p=" + p);
						video["thumbnail"] = item["pic"].asString();
						video["author"] = "@" + item["owner"]["name"].asString();
						video["date"] = UnixTimeToDateTime(item["pubdate"].asInt64());

						videos.insertLast(video);
					}
				}
			}
		}
	}
	if (videos.size() == 0) {
		HostMessageBox("[稍后再看] 列表是空的，刷点别的视频吧。", "BilibiliPotPlayer", 2,0);
	}
	return videos;
}

array<dictionary> History() {
	array<dictionary> videos;
	int ps = 30;
	string max = "0";
	int view_at = 0;
	string business = "";

	while (videos.size() < ConfigData.historyVideoNums) {
		string res = apiPost("/x/web-interface/history/cursor?max=" + max + "&view_at=" + formatInt(view_at) + "&business=" + business + "&ps=" + ps + "&type=all", false);

		JsonReader Reader;
		JsonValue Root;

		if (!Reader.parse(res, Root) || !Root.isObject()) break;
		if (Root["code"].asInt() != 0) break;

		JsonValue cursor = Root["data"]["cursor"];

		max = cursor["max"].asString();
		view_at = cursor["view_at"].asInt();
		business = cursor["business"].asString();

		JsonValue data = Root["data"]["list"];

		if (!data.isArray() || data.size() == 0) break;

		for (int i = 0; i < data.size(); i++) {
			JsonValue item = data[i];
			if (!item.isObject()) continue;

			string type = item["history"]["business"].asString();
			// archive / live
			if (type == "archive" || type == "live") {
				dictionary video;

				video["thumbnail"] = item["cover"].asString();
				video["author"] = "@" + item["author_name"].asString();

				if (type == "live") {
					if (item["live_status"].asInt() != 1) continue;

					video["title"] = "直播 | " + item["title"].asString();
					video["url"] = item["uri"].asString();

				} else if (type == "archive") {
					int p = item["history"]["page"].asInt();

					if (p == 1) {
						video["title"] = item["title"].asString();
					} else {
						video["title"] = item["title"].asString() + " | " + item["history"]["part"].asString();
					}

					video["duration"] = item["duration"].asInt() * 1000;
					video["url"] = makeWebUrl("https://www.bilibili.com/video/" + item["history"]["bvid"].asString() + "?p=" + p);
					video["date"] = UnixTimeToDateTime(item["view_at"].asInt64());
				}

				videos.insertLast(video);
			}
		}

		if (videos.size() >= ConfigData.historyVideoNums) break;
	}

	return videos;
}

array<dictionary> LiveRecommend() {
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;

	int page = 1;

	while (page <= ConfigData.liveRecommendPage) {
		string res = apiPost("/xlive/web-interface/v1/index/getListV2?platform=web&page=" + page, "", "https://api.live.bilibili.com", false);

		if (!Reader.parse(res, Root) || !Root.isObject()) return videos;		
		if (Root["code"].asInt() != 0) return videos;
		if (!Root["data"].isObject() || !Root["data"]["list"].isArray()) return videos;

		JsonValue list = Root["data"]["list"];
		for (int i = 0; i < list.size(); i++) {
			JsonValue item = list[i];

			if (item["is_ad"].isBool() && item["is_ad"].asBool()) continue;

			string title;
			string area_title;
			string pendant_title;

			area_title = item["area_v2_parent_name"].asString().isEmpty() ? item["area_v2_name"].asString() : (item["area_v2_name"].asString().isEmpty() ? item["area_v2_parent_name"].asString() : ( item["area_v2_parent_name"].asString() + " (" + item["area_v2_name"].asString() + ")"));

			if (item["pendant_Info"].isObject()) {
				JsonValue pendant_info = item["pendant_Info"];
				array<string> pendant_infos;
				array<string> keys = pendant_info.getKeys();

				for (int j = 0; j < keys.size(); j++) {
					pendant_infos.insertLast(pendant_info[keys[j]]["text"].isString() && !pendant_info[keys[j]]["text"].asString().isEmpty() ? pendant_info[keys[j]]["text"].asString() : pendant_info[keys[j]]["name"].asString());
				}
				pendant_title = join(pendant_infos, " | ");
			}

			array<string> titles;
			if (!area_title.isEmpty()) titles.insertLast(area_title);
			titles.insertLast(item["title"].asString());
			if (!pendant_title.isEmpty()) titles.insertLast(pendant_title);

			title = join(titles, "\n");

			string thumbnail = (ConfigData.useKeyframe && item["keyframe"].isString() && !item["keyframe"].asString().isEmpty()) ? item["keyframe"].asString() : item["cover"].asString();

			dictionary video;

			video["title"] = title;
			video["thumbnail"] = thumbnail;
			video["url"] = "https://live.bilibili.com/" + item["roomid"].asString();
			video["author"] = "@" + item["uname"].asString();

			videos.insertLast(video);
		}
		page++;
	}

	return videos;
}

array<dictionary> Recommend() {
	array<dictionary> videos;
	int maxPage = 10;
	int ps = 30;
	int page = 1;

	while (videos.size() < ConfigData.recommendVideoNums && page <= maxPage) {
		string params = "web_location=1430650&y_num=3&fresh_type=4&feed_version=V8&fresh_idx_1h=" + page + "&fetch_row=" + (3 * page + 1) + "&fresh_idx=" + page + "&brush=" + page + "&device=win&homepage_ver=1&ps=" + ps + "&last_y_num=5";
		string url = "/x/web-interface/wbi/index/top/feed/rcmd?" + encWbi(params);

		string res = apiPost(url, false);

		JsonReader Reader;
		JsonValue Root;

		if (!Reader.parse(res, Root) || !Root.isObject()) break;
		if (Root["code"].asInt() != 0) break;

		JsonValue list = Root["data"]["item"];
		if (list.isArray()) {
			for (int i = 0; i < list.size(); i++) {
				JsonValue item = list[i];
				dictionary video;

				video["thumbnail"] = item["pic"].asString();
				video["author"] = "@" + item["owner"]["name"].asString();

				if (item["uri"].asString().find("live.bilibili.com") >= 0) {
					string title = item["room_info"]["area"]["parent_area_name"].asString() + " (" + item["room_info"]["area"]["area_name"].asString() + ")\n" + item["title"].asString();

					video["title"] = title;
					video["url"] = item["uri"].asString();

					if (ConfigData.useKeyframe && !item["room_info"]["show"]["keyframe"].asString().isEmpty()) {
						video["thumbnail"] = item["room_info"]["show"]["keyframe"].asString();
					}

				} else if (!item["bvid"].asString().isEmpty()) {
					video["title"] = item["title"].asString();
					video["duration"] = item["duration"].asInt() * 1000;
					video["url"] = item["uri"].asString();
					video["date"] = UnixTimeToDateTime(item["pubdate"].asInt64());
				} else {
					continue;
				}

				videos.insertLast(video);
			}
		}

		page++;
		if (videos.size() >= ConfigData.recommendVideoNums) break; 
	}

	return videos;
}

array<dictionary> Dynamic(uint tid) {
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;
	string res = apiPost("/x/web-interface/dynamic/region?pn=1&ps=50&rid=" + tid, false);
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() != 0) {
			return videos;
		}
		JsonValue list = Root["data"]["archives"];
		if (list.isArray()) {
			for (int i = 0; i < list.size(); i++) {
				JsonValue item = list[i];
				dictionary video;

				video["title"] = item["title"].asString();
				video["duration"] = item["duration"].asInt() * 1000;
				video["url"] = "https://www.bilibili.com/video/" + item["bvid"].asString();
				video["thumbnail"] = item["pic"].asString();
				video["author"] = "@" + item["owner"]["name"].asString();

				videos.insertLast(video);
			}
		}
	}
	return videos;
}

bool PlayitemCheck(const string&in path) {
	// log("PlayitemCheck - path", path);
	status = 1;	

	if (path.find("bilibili.com") < 0) {
		return false;
	}

	if (path.find("live.bilibili.com") >= 0) {
		return true;
	}

	if (path.find("/bangumi/media/md") >= 0) {
		return true;
	}
	if (path.find("/bangumi/play/") >= 0) {
		return true;
	}
	if (path.find("www.bilibili.com/audio/au") >= 0) {
		return true;
	}

	if (path.find("/video/BV") >= 0) {
		return true;
	}
	if (path.find("/video/av") >= 0) {
		return true;
	}

	// log("PlayitemCheck", "false");
	return false;
}

bool PlaylistCheck(const string&in path) {
	// log("PlaylistCheck - path", path);
	status = 2;
	if (path.find("bilibili.com") < 0) {
		return false;
	}

	// domain
	if (path.find("t.bilibili.com") >= 0) {
		return true;
	}
	if (path.find("search.bilibili.com") >= 0) {
		return true;
	}
	if (path.find("space.bilibili.com") >= 0) {
		if (!HostRegExpParse(path, "/([0-9]+)").empty()) {
			if (path.find("/upload/video") >= 0) {
				return true;
			} else if (path.find("/dynamic") >= 0) {
				return true;
			} else if (path.find("/audio") >= 0) {
				return true;
			} else if (path.find("/favlist") >= 0) {
				return true;
			} else if (path.find("/bangumi") >= 0) {
				return false;
			} else {
				return true;
			}
		}
	}
	if (path.find("link.bilibili.com") >= 0 && path.find("/user-center/follow") >= 0) {
		return true;
	}
	if (path.find("live.bilibili.com") >= 0) {
		if (path.find("areaId") >= 0) {
			return true;
		}
		if (path.find("lol") >= 0) {
			return true;
		}
		if (path.find("pubg") >= 0) {
			return true;
		}
		if (path.find("cf") >= 0) {
			return true;
		}
		if (path.find("hpjy") >= 0) {
			return true;
		}
		string id = HostRegExpParse(path, "live\\.bilibili\\.com/(?:blanc/)?([0-9]+)");
		if (!id.empty()) {
			return true;
		} else {
			return true;
		}
	}

	// path
	if (path.find("www.bilibili.com/v/popular/all") >= 0) {
		return true;
	}
	if (path.find("www.bilibili.com/v/popular/weekly") >= 0) {
		return true;
	}
	if (path.find("www.bilibili.com/v/popular/history") >= 0) {
		return true;
	}
	if (path.find("www.bilibili.com/v/popular/rank") >= 0) {
		return true;
	}
	if (path.find("www.bilibili.com/list/") >= 0) {
		return !HostRegExpParse(path, "/list/([0-9]+)").empty();
	}
	if (path.find("/watchlater") >= 0) {
		return true;
	}
	if (path.find("/history") >= 0) {
		return true;
	}
	if (path.find("/medialist/detail/ml") >= 0) {
		return true;
	}
	if (path.find("bangumi/media/md") >= 0) {
		return true;
	}
	if (path.find("bangumi/play/") >= 0) {
		return true;
	}
	if (path.find("www.bilibili.com/audio/am") >= 0) {
		return true;
	}
	if (path.find("www.bilibili.com") >= 0 && HostRegExpParse(path, "www.bilibili.com/([a-zA-Z0-9]+)").empty()) {
		return true;
	}

	if (isPlaylist(path)) {
		return true;
	}
	if (!parseBVId(path).empty() || !parseAVId(path).empty()) {
		return true;
	}
	if (gettid(path) > 0) {
		return true;
	}

	// log("PlaylistCheck", "false");
	return false;
}

array<dictionary> PlaylistParse(const string&in url) {
	string path = url;
	log("PlaylistParse - path", path);
	status = 3;
	array<dictionary> result;

	// domain
	if (path.find("t.bilibili.com") >= 0) {
		return webDynamic(path);
	}
	if (path.find("search.bilibili.com") >= 0) {
		return Search(path);
	}
	if (path.find("space.bilibili.com") >= 0) {
		if (!HostRegExpParse(path, "/([0-9]+)").empty()) {
			if (path.find("/upload/video") >= 0) {
				return spaceVideo(path);
			} else if (path.find("/dynamic") >= 0) {
				return spaceDynamic(path);
			} else if (path.find("/audio") >= 0) {
				return spaceAudio(path);
			} else if (path.find("/favlist") >= 0) {
				return FavList(path);
			} else if (path.find("lists") >= 0) {
				return spaceSeason(path);
			} else {
				return spaceVideo(path);
			}
		}
	}
	if (path.find("link.bilibili.com") >= 0 && path.find("/user-center/follow") >= 0) {
		return followingLive();
	}
	if (path.find("live.bilibili.com") >= 0) {
		if (path.find("areaId") >= 0) {
			return liveCategory(path);
		}
		if (path.find("lol") >= 0) {
			return liveCategory(path, 86, 2);
		}
		if (path.find("pubg") >= 0) {
			return liveCategory(path, 80, 2);
		}
		if (path.find("cf") >= 0) {
			return liveCategory(path, 88, 2);
		}
		if (path.find("hpjy") >= 0) {
			return liveCategory(path, 256, 3);
		}
		string id = HostRegExpParse(path, "live\\.bilibili\\.com/(?:blanc/)?([0-9]+)");
		if (!id.empty()) {
			return RelatedLiveRooms(id, path);
		} else {
			return LiveRecommend();
		}
	}

	// path
	if (path.find("www.bilibili.com/v/popular/all") >= 0) {
		return PopularAll();
	}
	if (path.find("www.bilibili.com/v/popular/weekly") >= 0) {
		return PopularWeekly(path);
	}
	if (path.find("www.bilibili.com/v/popular/history") >= 0) {
		return PopularHistory();
	}
	if (path.find("www.bilibili.com/v/popular/rank") >= 0) {
		return Ranking(path);
	}
	if (path.find("www.bilibili.com/list/") >= 0) {
		return medialist(path);
	}
	if (path.find("/watchlater") >= 0) {
		return watchlater();
	}
	if (path.find("/history") >= 0) {
		return History();
	}
	if (path.find("/medialist/detail/ml") >= 0) {
		return FavList(path);
	}
	if (path.find("www.bilibili.com/audio/am") >= 0) {
		return AudioList(path);
	}
	if (path.find("www.bilibili.com") >= 0 && HostRegExpParse(path, "www.bilibili.com/([a-zA-Z0-9]+)").empty()) {
		return Recommend();
	}

	// playlist
	if (videoIsUGCorPGC.url == makeWebUrl(path)) {
		if (videoIsUGCorPGC.isPGC) path = videoIsUGCorPGC.pgcURL;
		else if (videoIsUGCorPGC.isUGCSeason) return UGCSeason(path);
	}

	if (path.find("bangumi/media/md") >= 0) {
		return BangumiEpisodes(parseMDId(path), "media_id", path);
	}
	if (path.find("bangumi/play/ep") >= 0) {
		return BangumiEpisodes(parseEPId(path), "ep_id", path);
	}
	if (path.find("bangumi/play/ss") >= 0) {
		return BangumiEpisodes(parseSSId(path), "season_id", path);
	}
	string bvid = parseBVId(path);
	if (!bvid.empty()) {
		return RelatedVideos(path);
	}
	string avid = parseAVId(path);
	if (!avid.empty()) {
		return RelatedVideos(path);
	}

	uint tid = gettid(path);
	if (tid > 0) {
		return Dynamic(tid);
	}

	return result;
}

string PlayitemParse(const string&in path, dictionary& MetaData, array<dictionary>& QualityList) {
	log("PlayitemParse - path", path);
	status = 4;

	if (path.find("live.bilibili.com") >= 0) {
		string id = HostRegExpParse(path, "live\\.bilibili\\.com/(?:blanc/)?([0-9]+)");
		if (!id.empty()) {
			return Live(id, path, MetaData, QualityList);
		}
	}

	if (path.find("bangumi/media/md") >= 0) {
		return Bangumi(path, MetaData, QualityList);
	}
	if (path.find("bangumi/play") >= 0) {
		return Bangumi(path, MetaData, QualityList);
	}
	if (path.find("www.bilibili.com/audio/au") >= 0) {
		return Audio(path, MetaData, QualityList);
	}

	if (path.find("/video/BV") >= 0) {
		string bvid = parseBVId(path);
		return Video(bvid, path, MetaData, QualityList);
	}
	if (path.find("/video/av") >= 0) {
		string aid = parseAVId(path);
		return Video(aid, path, MetaData, QualityList);
	}

	return path;
}
