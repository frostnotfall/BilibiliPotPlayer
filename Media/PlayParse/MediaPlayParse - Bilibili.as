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
// string ServerCheck(string User, string Pass) 		-> server check
// string ServerLogin(string User, string Pass) 		-> login
// void ServerLogout() 									-> logout
// string GetWebAccountUrl()							-> login process by WebBrowser
// string GetWebAccountDomain()							-> transport cookie domain for login
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

Config ConfigData;
VideoIsUGCorPGC videoIsUGCorPGC;
dictionary ResponseCache;

const string ConfigFileName = "Bilibili_Config.json";
const array<string> BilibiliDomains = {"bilibili.com", "bilivideo.com", "bilivideo.cn"};
const array<string> knownP2pCdnDomainPattern = {
	"302ppio",
	"302kodo",
	".mcdn.bilivideo",
	"szbdyd.com",
	".nexusedgeio.com",
	".ahdohpiechei.com",
	"upos-sz-mirror14b.bilivideo.com"
};

const string UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36 Edg/151.0.0.0";
const string Referer = "https://www.bilibili.com";

void OnInitialize() {
	for (uint i = 0; i < BilibiliDomains.length(); i++) {
		HostSetUrlUserAgentHTTP(BilibiliDomains[i], UserAgent);
		HostSetUrlRefererHTTP(BilibiliDomains[i], Referer);
	}

	string configFile = HostGetScriptFolder() + ConfigFileName;
	if (!isFileExists(configFile)) {
		HostMessageBox("配置文件不存在\n\n路径：" + configFile + "\n\n进入设置→<扩展功能>→<媒体播放列表/项目>→选中<Bilibili>→点击下方<设置文件>进行编辑\n或\n手动建立该配置文件", "配置文件不存在");
	}

	ConfigData = ReadConfigFile(configFile);
	if (ConfigData.debug) {
		HostOpenConsole();
	}
}

string host = "https://api.bilibili.com";
string mixin_key;

string GetTitle() {
	return "Bilibili";
}

string GetVersion() {
	return "2.6.9";
}

string GetDesc() {
	return "https://www.bilibili.com";
}

string GetConfigFile() {
	return HostGetScriptFolder() + ConfigFileName;
}
string GetWebAccountUrl() {
	return "https://passport.bilibili.com/login";
}

string GetWebAccountDomain() {
    string domains = "";
    for (uint i = 0; i < BilibiliDomains.length(); i++) {
        if (i > 0)
            domains += ";";
        domains += BilibiliDomains[i];
    }
    return domains;
}

bool isFileExists(string path) {
	return HostFileOpen(path) > 0;
}

class Config {
	string fullConfig;
	int uid = 0;
	bool danmakuEnable = true;
	string danmakuServer;
	string danmakuFont;
	float danmakuFontSize = 30.0;
	float danmakuOpacity = 0.8;
	float danmakuDisplayArea = 0.8;
	float danmakuStayTime = 15.0;
	bool showRecommendedVideos = true;
	bool blockP2PCDN = true;
	int cacheValidTime = 300;
	bool enableSponsorBlock = false;
	string sponsorBlockMirror;
	bool debug = false;

	string danmakuUrl;
	string subtitleUrl;

	int maxliveroom = 200;
};

class VideoIsUGCorPGC {
	string url = "";
	bool isUGCSeason = false;
	bool isPGC = false;
	string pgcURL = "";
};

class ResponseCacheItem {
	string response;
	uint tick_count;
	uint valid_time;
}

Config ReadConfigFile(string file) {
	Config config;
	config.fullConfig = HostFileRead(HostFileOpen(file), 10000);
	JsonReader reader;
	JsonValue root;
	if (reader.parse(config.fullConfig, root) && root.isObject()) {
		if (root["maxliveroom"].isNumeric()) {
			config.maxliveroom = root["maxliveroom"].asInt();
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
		}
		if (root["showRecommendedVideos"].isBool()) {
			config.showRecommendedVideos = root["showRecommendedVideos"].asBool();
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

		if (root["debug"].isBool()) {
			config.debug = root["debug"].asBool();
		}
		if (!config.danmakuServer.empty()) {
			config.danmakuUrl = config.danmakuServer +  "/subtitle?font=" + HostUrlEncode(config.danmakuFont) + "&font_size=" + config.danmakuFontSize + "&alpha=" + config.danmakuOpacity + "&display_area=" + config.danmakuDisplayArea + "&duration_marquee=" + config.danmakuStayTime + "&duration_still=" + config.danmakuStayTime + "&cid=";
			config.subtitleUrl = config.danmakuServer + "/subtitle?url=";
		}

	}
	return config;
}

uint status = 0;
string GetStatus() {
	string info = "";

	switch (status)
	{
	case  1:
		info = "单视频检查";
		break;
	case  2:
		info = "合集检查";
		break;
	case  3:
		info = "解析视频合集";
		break;
	case  4:
		info = "解析视频信息";
		break;
	case  5:
		info = "请求空降助手接口";
		break;
	case  6:
		info = "解析真实播放地址";
		break;
	default:
		info = "请等待";
	}

	return info;
}


void log(string item) {
	if (!ConfigData.debug) {
		return;
	}
	HostPrintUTF8(item);
}

void log(string item, string info) {
	log(item + ": " + info);
}

void log(string item, int info) {
	log(item + ": " + info);
}

string UnixTimeToDate(int64 t) {
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

string post(string url, string data="", string headers="") {
	if (headers.empty()) headers = "User-Agent: " + UserAgent + "\r\n" + "Referer: " + Referer + "\r\n";
	log("request url", url);
	return HostUrlGetStringWithAPI(url, "", headers, data);
}

string apiPost(string api, string data="") {	
	string key;
	if (!data.empty()) {
		key = api + "?" + data;
	} else {
		key = api;
	}

	ResponseCacheItem item;
	if (ResponseCache.get(key, item)) {
		if (HostGetTickCount() - item.tick_count <= item.valid_time) {
			log("Cache Hit, url", host + api);
			return item.response;
		} else {
			log("Cache expire, url", host + api);
		}
	} else {
		log("Cache not Hit, url", host + api);
	}

	string resp = post(host + api, data);
	if (resp.empty()) {
		HostMessageBox("未获取到响应数据，请等待一段时间后重试一下\nurl: " + host + api, "请求失败");
		return "";
	}

	JsonReader Reader;
	JsonValue Root;
	if (!Reader.parse(resp, Root) || !Root.isObject()) {
		HostMessageBox("未能解析响应数据\nurl: " + host + api, "请求失败");
		return "";
	}
	if (Root["code"].asInt() != 0) {
		log("error code: " + Root["code"].asInt() + "\n" + "error message: " + Root["message"].asString() + "\n" + "url:"  + host + api);
		HostMessageBox("error code: " + Root["code"].asInt() + "\n" + "error message: " + Root["message"].asString() + "\n" + "url:"  + host + api,  Root["message"].asString());
		return "";
	}

	item.response = resp;
	item.tick_count = HostGetTickCount();
	item.valid_time = ConfigData.cacheValidTime * 1000;
	ResponseCache[key] = item;

	return resp;
}

array<dictionary> generateChapter(const string &in bvid) {
	array<dictionary> chapter;
    const float MIN_CHAPTER_DURATION = 1.0f;
    dictionary typesToName = {
        {"sponsor", "赞助"},
        {"selfpromo", "推广"},
        {"exclusive_access", "品牌合作"},
        {"interaction", "三连提醒"},
        {"poi_highlight", "精彩时刻"},
        {"intro", "开场动画"},
        {"outro", "片尾"},
        {"preview", "预览"},
        {"padding", "填充内容"},
        {"filler", "离题"},
        {"music_offtopic", "非音乐"}
    };

    string headers = "origin: https://github.com/frostnotfall/BilibiliPotPlayer\r\nx-ext-version: " + GetVersion() + "\r\n";
    string url = !ConfigData.sponsorBlockMirror.empty() ? ConfigData.sponsorBlockMirror + "/api/skipSegments?videoID=" + bvid : "https://bsbsb.top/api/skipSegments?videoID=" + bvid;

	string resp;
	resp = post(url, "", headers);

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

        float duration = resultTimes[i] - resultTimes[i - 1];

        if (duration < MIN_CHAPTER_DURATION) {
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
        dictionary chapterItem;

        chapterItem["title"] = finalTitles[i];
        chapterItem["time"] = formatFloat(finalTimes[i] * 1000, "", 32, 0);
        chapter.insertLast(chapterItem);
    }

    return chapter;
}

string getMixinKey() {
	JsonReader Reader;
	JsonValue Root;
	string key = "";
	string res = apiPost("/x/web-interface/nav");
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].isInt()) {
			JsonValue wbi_img = Root["data"]["wbi_img"];
			string img_url = wbi_img["img_url"].asString();
			string sub_url = wbi_img["sub_url"].asString();
			array<string> parts = img_url.split("/");
			string img_value = parts[parts.length() - 1].split(".")[0];
			parts = sub_url.split("/");
			string sub_value = parts[parts.length() - 1].split(".")[0];
			string ae = img_value + sub_value;
			array<int> oe = {46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52};
			for (uint i = 0; i < oe.length(); i++) {
				key += ae.substr(oe[i], 1);
			}
		}
	}
	if (key.empty()) {
		return key;
	}
	return key.substr(0,32);
}

string encWbi(string params) {
	if (mixin_key.empty()) {
		mixin_key = getMixinKey();
	}
	array<string> lst = params.split("&");
	lst.sortAsc();
	string newParams;
	for (uint i = 0; i < lst.length(); i++)
	{
		newParams += lst[i];
		if (i != lst.length() - 1)
			newParams += "&";
	}
	return HostHashMD5(newParams + mixin_key);
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

array<dictionary> UGCSeason(const string &in path) {
	array<dictionary> videos;

	string bvid = parseBVId(path);
	string aid = parseAVId(path);
	string params;
	if (!bvid.empty()) params += "bvid=" + bvid;
	if (!aid.empty()) params += "aid=" + aid;	
	if (bvid.empty() && aid.empty()) return videos;

	string res = apiPost("/x/web-interface/wbi/view/detail?" + params + "&w_rid=" + encWbi(params));

	JsonReader Reader;
	JsonValue Root;
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() == 0) {
			if(!Root["data"]["View"].isObject()) {
				log('Root["data"]["View"] is empty.');
				return videos;
			}

			JsonValue sections = Root["data"]["View"]["ugc_season"]["sections"];
			if (sections.isArray()) {
				string title;
				for (int j = 0; j < sections.size(); j++) {
					if (sections.size() > 0) title =  "【" + sections[j]["title"].asString() + "】";
					JsonValue episodes = sections[j]["episodes"];
					for (int i = 0; i < episodes.size(); i++) {
						JsonValue item = episodes[i];
						if (item.isObject()) {
							dictionary video;
							video["title"] = title + item["title"].asString();
							video["duration"] = item["arc"]["duration"].asInt() * 1000;
							video["thumbnail"] = item["arc"]["pic"].asString();
							video["author"] = item["arc"]["author"]["name"].asString();
							video["url"] = "https://www.bilibili.com/video/" + item["bvid"].asString();
							video["viewCount"] = item["arc"]["stat"]["view"].asString();
							video["likeCount"] = item["arc"]["stat"]["like"].asString();
							video["dislikeCount"] = item["arc"]["stat"]["dislike"].asString();
							video["date"] = UnixTimeToDate(item["arc"]["pubdate"].asInt());
							video["resolution"] = item["arc"]["dimension"]["width"].asInt() + "x" + item["arc"]["dimension"]["height"].asInt();
							if (item["bvid"].asString() == bvid || item["aid"].asString() == aid) video["current"] = "1";
							video["referer"] = "https://www.bilibili.com/video/" +  Root["data"]["View"]["bvid"].asString();
							videos.insertLast(video);
						} else {
							log("item is empty");
						}
					}
				}
			} else {
				log('Root["data"]["View"]["ugc_season"]["sections"] is not array.');
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

array<dictionary> RelatedVideos(const string &in path) {
	array<dictionary> videos;

	string bvid = parseBVId(path);
	string aid = parseAVId(path);
	string params;
	if (!bvid.empty()) params += "bvid=" + bvid;
	if (!aid.empty()) params += "aid=" + aid;	
	if (bvid.empty() && aid.empty()) return videos;

	string res = apiPost("/x/web-interface/wbi/view/detail?" + params + "&w_rid=" + encWbi(params));

	JsonReader Reader;
	JsonValue Root;
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() == 0) {
			if(!Root["data"]["View"].isObject()) {
				log('Root["data"]["View"] is empty.');
				return videos;
			}

			JsonValue view = Root["data"]["View"];
			
			dictionary video;
			video["title"] = view["title"].asString();
			video["duration"] = view["duration"].asInt() * 1000;
			video["thumbnail"] = view["pic"].asString();
			video["author"] = view["owner"]["name"].asString();
			video["url"] = "https://www.bilibili.com/video/" + bvid;
			if (!view["desc"].asString().empty() || view["desc"].asString() != "-")  video["content"] = view["desc"].asString();
			video["viewCount"] = view["stat"]["view"].asString();
			video["likeCount"] = view["stat"]["like"].asString();
			video["dislikeCount"] = view["stat"]["dislike"].asString();
			video["date"] = UnixTimeToDate(view["pubdate"].asInt());
			video["resolution"] = view["dimension"]["width"].asInt() + "x" + view["dimension"]["height"].asInt();
			video["current"] = "1";
			video["referer"] = "https://www.bilibili.com/video/" + view["bvid"].asString();
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
						video["author"] = item["owner"]["name"].asString();
						video["url"] = "https://www.bilibili.com/video/" + item["bvid"].asString();
						if (!item["desc"].asString().empty() || item["desc"].asString() != "-")  video["content"] = item["desc"].asString();
						video["viewCount"] = item["stat"]["view"].asString();
						video["likeCount"] = item["stat"]["like"].asString();
						video["dislikeCount"] = item["stat"]["dislike"].asString();
						video["date"] = UnixTimeToDate(item["pubdate"].asInt());
						video["resolution"] = item["dimension"]["width"].asInt() + "x" + item["dimension"]["height"].asInt();
						video["referer"] = "https://www.bilibili.com/video/" + view["bvid"].asString();
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

string makeWebUrl(string path) {
	array<string> strs = path.split("?");
	if (strs.length() <= 1) {
		return path;
	}
	return strs[0];
}

dictionary AppendAudioQualityList(JsonValue audio, string bvid) {
	dictionary audioqualityitem;
	string format;

	int itag = 0;
	int audioid = audio["id"].asInt();
	audioqualityitem["itag"] = getAudioItag(audioid);
	audioqualityitem["url"] = getFixedURL(audio);
	
	bool audioIsDefault = false;
	if (audioid == 30250) {
		audioqualityitem["quality"] = "杜比全景声";
	} else if (audioid == 30251) {
		audioqualityitem["quality"] = "Hi-Res无损";
		audioIsDefault = true;
	} else if (audio["codecs"].asString().MakeLower().find("mp4a") >= 0) {
		audioqualityitem["quality"] = "AAC";
	}
	audioqualityitem["qualityDetail"] = audioqualityitem["quality"];
	audioqualityitem["audioIsDefault"] = audioIsDefault;
	
	int bitrateVal = audio["bandwidth"].asInt();
	string bitrate = formatFloat(bitrateVal / 1000.0, "", 0, 1) + "Kbps";
	audioqualityitem["bitrateVal"] = bitrateVal;
	audioqualityitem["bitrate"] = bitrate;

	string codec = audio["codecs"].asString().MakeLower();
	string mimeType = audio["mimeType"].asString().MakeLower();
	audioqualityitem["format"] = mimeType.substr(mimeType.findLast("/") + 1) + ", " + codec.substr(0, codec.find(".")) + ", " + bitrate;

	audioqualityitem["resolution"] = "audio only";
	audioqualityitem["va"] = "a";
	audioqualityitem["referer"] = "https://www.bilibili.com/video/" + bvid;
	
	return audioqualityitem;
}

string Video(string id, const string &in path, dictionary &MetaData, array<dictionary> &QualityList) {
	log("==============================video=============================");
	string res;
	string bvid;
	string aid;
	string cid;
	string title;
	string url;
	string params;
	JsonReader reader;
	JsonValue root;
	int qn = 127;
	array<dictionary> subtitle;

	if (id.find("BV") == 0) {
		bvid = id;
		params += "bvid=" + id;
	}
	if (id.find("av") == 0) {
		aid = id;
		params += "aid=" + id;	
	}
	res = apiPost("/x/web-interface/wbi/view/detail?" + params + "&w_rid=" + encWbi(params));

	if (reader.parse(res, root) && root.isObject()) {
		if (root["code"].asInt() == 0) {
			JsonValue data = root["data"]["View"];
			aid = data["aid"].asString();
			bvid = data["bvid"].asString();
			aid = data["aid"].asString();
			cid = data["cid"].asString();
			title = data["title"].asString();
			
			if (@MetaData !is null) {
				MetaData["title"] = title;
				MetaData["duration"] = data["duration"].asInt() * 1000;
				MetaData["thumbnail"] = data["pic"].asString();
				MetaData["author"] = data["owner"]["name"].asString();
				MetaData["content"] = data["desc"].asString();
				MetaData["webUrl"] = "https://www.bilibili.com/video/" + data["bvid"].asString();
				MetaData["viewCount"] = data["stat"]["view"].asString();
				MetaData["likeCount"] = data["stat"]["like"].asString();
				MetaData["dislikeCount"] = data["stat"]["dislike"].asString();
				MetaData["date"] = UnixTimeToDate(data["pubdate"].asInt());
				MetaData["resolution"] = data["dimension"]["width"].asInt() + "x" + data["dimension"]["height"].asInt();
			}

			if (ConfigData.enableSponsorBlock) {
				status = 5;
				array<dictionary> chapter = generateChapter(bvid);
				if (!chapter.empty() && (@QualityList !is null)) MetaData["chapter"] = chapter;
				status = 4;
			}
			if (ConfigData.danmakuEnable) {
				dictionary dic;
				dic["name"] = "【弹幕】" + title;
				dic["url"] = ConfigData.danmakuUrl + cid;
				subtitle.insertLast(dic);
			}
		} else {
			log("Video view API code != 0", root["code"].asInt());
			log("Video view API message", root["message"].asString());
			return url;
		}
	}

	status = 6;

	params = "bvid=" + bvid + "&avid=" + aid + "&cid=" + cid + "&qn=" + qn + "&fnval=4048&fourk=1";
	res = apiPost("/x/player/wbi/playurl?" + params + "&w_rid=" + encWbi(params));
	if (reader.parse(res, root) && root.isObject()) {
		if (root["code"].asInt() == 0) {
			JsonValue data = root["data"];

			if (data["dash"].isObject()) {
				JsonValue videos = data["dash"]["video"];
				for (int i = 0; i < videos.size(); i++) {
					JsonValue video = videos[i];
					dictionary qualityitem;

					int itag = 0;
					int quality = video["id"].asInt();
					int codecid = video["codecid"].asInt();
					url = getFixedURL(video);
					qualityitem["url"] = url;

					if (itag <= 0 || HostExistITag(itag)) {
						itag = HostGetITag(video["height"].asInt(), 0, true, false);
						if (itag <= 0) itag = HostGetITag(video["height"].asInt(), 0, true, true);
					}
					while (HostExistITag(itag)) itag++; 
					HostSetITag(itag);
					qualityitem["itag"] = itag;

					qualityitem["quality"] = getVideoquality(data["support_formats"], quality);
					qualityitem["qualityDetail"] = qualityitem["quality"];
					qualityitem["resolution"] = formatInt(video["width"].asInt()) + "x" + formatInt(video["height"].asInt());
					qualityitem["isHDR"] = (quality == 125 || quality == 126 || quality == 129);

					int bitrateVal = video["bandwidth"].asInt();
					string bitrate = formatFloat(bitrateVal / 1000.0, "", 0, 1) + "Kbps";
					qualityitem["bitrateVal"] = bitrateVal;
					qualityitem["bitrate"] = formatFloat(bitrateVal / 1000.0, "", 0, 0) + "	Kbps";
					if (video["frameRate"].isFloat()) qualityitem["fps"] = video["frameRate"].asFloat();
					
					string mimeType = video["mimeType"].asString().MakeLower();
					qualityitem["format"] = mimeType.substr(mimeType.findLast("/") + 1) + ", " + getCodec(codecid) + ", " + bitrate;

					qualityitem["audioIsDefault"] = false;
					qualityitem["va"] = "v";
					qualityitem["referer"] = "https://www.bilibili.com/video/" + bvid;

					if (@QualityList !is null) QualityList.insertLast(qualityitem);
				}

				JsonValue audios;
				JsonValue audio;
				if (data["dash"]["audio"].isArray()) {
					audios = data["dash"]["audio"];
					for (int i = 0; i < audios.size(); i++) {
						audio = audios[i];
						if (@QualityList !is null) QualityList.insertLast(AppendAudioQualityList(audio, bvid));
					}
				}
				if (data["dash"]["dolby"]["audio"].isArray()){
					audios = data["dash"]["dolby"]["audio"];
					for (int i = 0; i < audios.size(); i++) {
						audio = audios[i];
						if (@QualityList !is null) QualityList.insertLast(AppendAudioQualityList(audio, bvid));
					}
				}
				if (data["dash"]["flac"].isObject()){
					audio = data["dash"]["flac"]["audio"];
					if (@QualityList !is null) QualityList.insertLast(AppendAudioQualityList(audio, bvid));
				}
			}
		} else {
			log("Video playurl response code != 0", root["code"].asInt());
			log("Video playurl response message", root["message"].asString());
			return url;
		}
	}

	log("bvid: " + bvid + " aid: " + aid + " cid: " + cid);
	log("url", url);
	// for (uint i = 0; i < QualityList.length(); i++) {
	//     log("QualityList[" + i + "] = " + string(QualityList[i]["quality"]) + " | " + int(QualityList[i]["itag"]) + " | " + string(QualityList[i]["url"]));
	// }
	return url;
}

array<dictionary> watchlater() {
	array<dictionary> videos;
	string res = apiPost("/x/v2/history/toview");
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
						video["url"] = "https://www.bilibili.com/video/" + item["bvid"].asString() + "?p=" + p;
						video["thumbnail"] = item["pic"].asString();
						video["author"] = item["owner"]["name"].asString();
						videos.insertLast(video);
					}
				}
			}
		}
	}
	return videos;
}

array<dictionary> History() {
	array<dictionary> videos;
	uint max = 0;
	uint ps = 20;
	string res = apiPost("/x/web-interface/history/cursor?max=" + max + "&ps=" + ps);
	JsonReader Reader;
	JsonValue Root;
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() == 0) {
			JsonValue data = Root["data"]["list"];
			if (data.isArray()) {
				for (int i = 0; i < data.size(); i++) {
					JsonValue item = data[i];
					string type = item["history"]["business"].asString();
					// archive live pgc
					if (type == "archive" || type == "live") {
						if (item.isObject()) {
							dictionary video;
							video["thumbnail"] = item["cover"].asString();
							video["author"] = item["author_name"].asString();
							if (type == "live") {
								if (item["live_status"].asInt() != 1) {
									continue;
								}
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
								video["url"] = "https://www.bilibili.com/video/" + item["history"]["bvid"].asString() + "?p=" + p;
							} else {
								continue;
							}
							videos.insertLast(video);
						}
					}
				}
			}
		}
	}
	return videos;
}

bool isP2PCDN(const string &in url) {
	if (parse(url, "os") == "mcdn")
		return true;

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

string getFixedURL(JsonValue &in data) {
    string baseUrl = data["baseUrl"].asString();

    if (!ConfigData.blockP2PCDN) {
        return baseUrl;
    }

    if (!isP2PCDN(baseUrl)) {
        return baseUrl;
    }

    if (data["backupUrl"].isString()) {
        string backupUrl = data["backupUrl"].asString();
        if (!isP2PCDN(backupUrl)) {
            return backupUrl;
        }
    } else if (data["backupUrl"].isArray()) {
        for (uint j = 0; j < data["backupUrl"].size(); j++) {
            string backupUrl = data["backupUrl"][j].asString();

            if (!isP2PCDN(backupUrl)) {
                return backupUrl;
            }
        }
    }

    return baseUrl;
}

string parse(string url, string key, string defaultValue="") {
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

int parseTime(string s) {
	array<string> strs = s.split(":");
	int t = 0;
	if (strs.length() == 1) {
		t = parseInt(strs[0]) * 1000;
	}
	else if (strs.length() == 2) {
		t = (parseInt(strs[0])*60 + parseInt(strs[1]))*1000;
	} else if (strs.length() == 3) {
		t = (parseInt(strs[0])*3600 + parseInt(strs[1])*60 + parseInt(strs[2]))*1000;
	}
	return t;
}

array<dictionary> Channel(string path) {
	array<dictionary> videos;
	int ps = 100;
	int pn = 1;
	string uid = HostRegExpParse(path, "/([0-9]+)/lists");
	string sid = HostRegExpParse(path, "lists/([0-9]+)");
	if (sid.empty()) {
		return videos;
	}
	string baseurl;
	string type = parse(path, "type", "season");
	bool isCollection = type == "season";
	if (isCollection) {
		baseurl = "/x/polymer/web-space/seasons_archives_list?mid=" + uid + "&season_id=" + sid + "&sort_reverse=" + parse(path, "sort_reverse", "false") + "&page_size=" + ps;
	} else {
		baseurl = "/x/series/archives?mid=" + uid + "&series_id=" + sid + "&sort=desc" + "&ps=" + ps;
	}
	while (true){
		string url;
		if (isCollection) {
			url = baseurl + "&page_num=" + pn;
		} else {
			url = baseurl + "&pn=" + pn;
		}
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
							videos.insertLast(video);
						}
					}
				}
				JsonValue page = Root["data"]["page"];
				if (isCollection) {
					if (page["page_num"].asInt() * page["page_size"].asInt() >= page["total"].asInt()) {
						break;
					}
				} else {
					if (page["num"].asInt() * page["size"].asInt() >= page["total"].asInt()) {
						break;
					}
				}
				pn += 1;
			} else {
				return videos;
			}
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
		string w_rid = encWbi(params);
		params += "&w_rid=" + w_rid;

		string url = baseurl + params;
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
							video["author"] = item["author"].asString();
							video["url"] = "https://www.bilibili.com/video/" + item["bvid"].asString();
							if (!item["description"].asString().empty() || item["description"].asString() != "-")  video["content"] = item["description"].asString();
							video["viewCount"] = item["play"].asString();
							video["date"] = UnixTimeToDate(item["created"].asInt());
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
		}
	}
	return audios;
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
							dictionary video;
							video["title"] = item["title"].asString();
							video["duration"] = item["duration"].asInt() * 1000;
							video["url"] = "https://www.bilibili.com/video/" + item["bvid"].asString();
							video["thumbnail"] = item["cover"].asString();
							video["author"] = item["upper"]["name"].asString();
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
		}
	}
	return videos;
}

array<dictionary> followingLive(uint page) {
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;
	string url = "https://api.live.bilibili.com/xlive/web-ucenter/user/following?page=" + page + "&page_size=10";
	string res = post(url);
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() == 0) {
			JsonValue list = Root["data"]["list"];
			if (list.isArray()) {
				for (int i = 0; i < list.size(); i++) {
					JsonValue item = list[i];
					// 未开播
					if (item["live_status"].asInt() == 0) {
						return videos;
					}
					dictionary video;
					video["title"] = item["title"].asString();
					video["url"] = "https://live.bilibili.com/" + item["roomid"].asInt();
					video["thumbnail"] = item["face"].asString();
					video["author"] = item["uname"].asString();
					videos.insertLast(video);
				}
				if (page < Root["data"]["totalPage"].asUInt()) {
					array<dictionary> videos2 = followingLive(page+1);
					for (uint i = 0; i < videos2.size(); i++) {
						videos.insertLast(videos2[i]);
					}
				}
			}
		}
	}
	return videos;
}

array<dictionary> liveCategory(uint page, string cateid, string parentAreaId, uint liveRoomCount) {
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;
	string params = "platform=web&parent_area_id=" + parentAreaId + "&area_id=" + cateid + "&page=" + page;
	string w_rid = encWbi(params);
	string url = "https://api.live.bilibili.com/xlive/web-interface/v1/second/getList?" + params + "&w_rid=" + w_rid;
	string res = post(url);
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() == 0) {
			JsonValue list = Root["data"]["list"];
			if (list.isArray()) {
				for (int i = 0; i < list.size(); i++) {
					JsonValue item = list[i];
					dictionary video;
					video["title"] = item["title"].asString();
					video["url"] = "https://live.bilibili.com/" + item["roomid"].asInt();
					video["thumbnail"] = item["face"].asString();
					video["author"] = item["uname"].asString();
					videos.insertLast(video);
					liveRoomCount += 1;
					if (liveRoomCount >= ConfigData.maxliveroom ) {
						return videos;
					}
				}
				if (Root["data"]["has_more"].asBool()) {
					array<dictionary> nextVideos = liveCategory(page + 1, cateid, parentAreaId, liveRoomCount);
					for (uint i = 0; i < nextVideos.size(); i++) {
						videos.insertLast(nextVideos[i]);
					}
				}
			}
		}
	}
	return videos;
}

array<dictionary> PopularHistory() {
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;
	string res = apiPost("/x/web-interface/popular/precious?page_size=100&page=1");
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
				video["author"] = item["owner"]["name"].asString();
				videos.insertLast(video);
			}
		}
	}
	return videos;
}

array<dictionary> PopularWeekly(string path) {
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;
	string num = parse(path, "num");
	if (num.empty()) {
		string res = apiPost("/x/web-interface/popular/series/list");
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
	string res = apiPost("/x/web-interface/popular/series/one?number=" + num);
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
				video["author"] = item["owner"]["name"].asString();
				videos.insertLast(video);
			}
		}
	}
	return videos;
}

array<dictionary> Ranking(string path) {
	array<dictionary> videos;

	array<string> names = { "全站", "国创相关", "动画", "音乐", "舞蹈", "游戏", "知识", "科技", "运动", "汽车", "生活", "美食", "动物圈", "鬼畜", "时尚", "娱乐", "影视" };
	array<string> urls = { "www.bilibili.com/v/popular/rank/all", "www.bilibili.com/v/popular/rank/guochuang", "www.bilibili.com/v/popular/rank/douga", "www.bilibili.com/v/popular/rank/music", "www.bilibili.com/v/popular/rank/dance", "www.bilibili.com/v/popular/rank/game", "www.bilibili.com/v/popular/rank/knowledge", "www.bilibili.com/v/popular/rank/tec", "www.bilibili.com/v/popular/rank/spor", "www.bilibili.com/v/popular/rank/car", "www.bilibili.com/v/popular/rank/life", "www.bilibili.com/v/popular/rank/food", "www.bilibili.com/v/popular/rank/animal", "www.bilibili.com/v/popular/rank/kichiku", "www.bilibili.com/v/popular/rank/fashion", "www.bilibili.com/v/popular/rank/en", "www.bilibili.com/v/popular/rank/cinephile" };
	array<uint> ids = { 0, 168, 1, 3, 129, 4, 36, 188, 234, 223, 160, 211, 217, 119, 155, 5, 181 };
	int pos = -1;
	for (uint i = 0; i < urls.size(); i++) {
		if (path.find(urls[i]) >= 0) {
			pos = i;
			break;
		}
	}
	if (pos < 0) {
		return videos;
	}

	JsonReader Reader;
	JsonValue Root;

	string res = apiPost("/x/web-interface/ranking/v2?rid=" + ids[pos]);
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
				video["author"] = item["owner"]["name"].asString();
				videos.insertLast(video);
			}
		}
	}
	return videos;
}

array<dictionary> Dynamic(uint tid) {
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;
	string res = apiPost("/x/web-interface/dynamic/region?pn=1&ps=50&rid=" + tid);
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
				video["author"] = item["owner"]["name"].asString();
				videos.insertLast(video);
			}
		}
	}
	return videos;
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

// type: meida_id/season_id/ep_id
array<dictionary> Banggumi(string id, string type) {
	log("============================Banggumi============================");
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;
	if (type == "media_id") {
		id = md2ss(id);
		if (id.empty()) {
			return videos;
		}
		type = "season_id";
	}
	string url = "/pgc/view/web/season?" + type + "=" + id;
	string res = apiPost(url);
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() != 0) {
			log("Banggumi code != 0", Root["code"].asInt());
			log("Banggumi message", Root["message"].asString());
			return videos;
		}
		JsonValue episodes = Root["result"]["episodes"];
		if (episodes.isArray()) {
			for (int i = 0; i < episodes.size(); i++) {
				JsonValue item = episodes[i];
				dictionary video;
				if (item["badge"].asString().empty()) {
					video["title"] = item["show_title"].asString();
				} else {
					video["title"] = "【" + item["badge"].asString() + "】" + item["show_title"].asString();
				}
				video["duration"] = item["duration"].asInt();
				video["url"] = "https://www.bilibili.com/video/" + item["bvid"].asString() + "?cid=" + item["cid"].asString();
				video["thumbnail"] = item["cover"].asString();
				if (item["ep_id"].asString() == id) video["current"] = "1";
				videos.insertLast(video);
			}
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
				if (item["author"].isString()) {
					audio["author"] = item["author"].asString();
				}
				audios.insertLast(audio);
			}
		}
	}
	return audios;
}

array<dictionary> Search(string path) {
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;
	string kw;
	if (path.find("?WithCaption") >= 0) {
		path.replace("?WithCaption", "");
		kw = HostUrlEncode(parse(path, "keyword"));
	} else {
		kw = parse(path, "keyword");
	}
	if (kw.empty()) {
		return videos;
	}
	string type = HostRegExpParse(path, "search.bilibili.com/([a-zA-Z0-9]+)");
	string url;
	if (type == "all") {
		url = "/x/web-interface/search/all/v2?keyword=" + kw;
	} else if (type == "video") {
		url = "/x/web-interface/search/type?search_type=video&keyword=" + kw;
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
				video["author"] = item["author"].asString();
				videos.insertLast(video);
		}
	}
	return videos;
}

array<dictionary> webDynamic(string path) {
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;
	string type = parse(path, "tab");
	if (type != "video") {
		type = "all";
	}
	int nums = 5;
	string offset;
	string baseurl ="/x/polymer/web-dynamic/v1/feed/all?timezone_offset=-480&type=" + type;
	for (int i = 1; i <= nums; i++) {
		string url = baseurl + "&page=" + i;
		if (!offset.empty()) {
			url += "&offset=" + offset;
		}
		string res = apiPost(url);
		if (Reader.parse(res, Root) && Root.isObject()) {
			if (Root["code"].asInt() != 0) {
				return videos;
			}
			JsonValue list = Root["data"]["items"];
			if (list.isArray()) {
				offset = Root["data"]["offset"].asString();
				for (int j = 0; j < list.size(); j++) {
					JsonValue dynamic = list[j]["modules"]["module_dynamic"];
					if (dynamic.isObject()) {
						JsonValue major = dynamic["major"];
						if (!major.isObject()) {
							continue;
						}
						string author = list[j]["modules"]["module_author"]["name"].asString();
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
				if (!Root["data"]["has_more"].asBool()) {
					break;
				}
			}
		}
	}
	return videos;
}

array<dictionary> Recommend(uint page) {
	array<dictionary> videos;
	JsonReader Reader;
	JsonValue Root;
	const uint nums = 5;
	string url = "/x/web-interface/wbi/index/top/feed/rcmd?y_num=3&fresh_type=4&feed_version=V8&fresh_idx_1h="+page+"&fetch_row="+(3*page+1)+"&fresh_idx="+page+"&brush="+page+"&homepage_ver=1&ps=12&last_y_num=4&outside_trigger=";
	string res = apiPost(url);
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() != 0) {
			return videos;
		}
		JsonValue list = Root["data"]["item"];
		if (list.isArray()) {
			for (int i = 0; i < list.size(); i++) {
				JsonValue item = list[i];
				if (item["bvid"].asString().empty()) {
					continue;
				}
				dictionary video;
				video["thumbnail"] = item["pic"].asString();
				video["author"] = item["owner"]["name"].asString();
				if (item["uri"].asString().find("live.bilibili.com") >= 0) {
					video["title"] = "直播 | " + item["title"].asString();
					video["url"] = item["uri"].asString();
				} else {
					video["title"] = item["title"].asString();
					video["duration"] = item["duration"].asInt() * 1000;
					video["url"] = item["uri"].asString();
				}
				videos.insertLast(video);
			}
		}
	}
	if (page < nums) {
		array<dictionary> videos2 = Recommend(page+1);
		for (uint i = 0; i < videos2.size(); i++) {
			videos.insertLast(videos2[i]);
		}
	}
	return videos;
}

int getItag(int qn) {
	array<int> qns = {10000, 400, 250, 150, 80};
	int idx = qns.find(qn);
	if (idx >= 0) {
		return idx;
	}
	return qn;
}


int getTrueItag(int itag) {
	array<int> itags = {1282,1283,1272,1273,1262,1263,1207,1212,1213,1167,1172,1173,1127,1132,1133,807,812,813,647,652,653,327,332,333,167,172,173,67,72,73};
	array<int> tis = {102,571,101,702,266,701,138,272,401,299,303,699,264,271,400,137,248,399,136,247,398,135,244,397,134,243,396,133,242,395};
	int idx = itags.find(itag);
	if (idx >= 0) {
		return tis[idx];
	}
	return itag;
}

int getAudioItag(int id) {
	// 增加 EC-3/E-AC3 和 flac 的 itag 映射，flac 没有对应的 itag，使用 AC3 替代
	array<int> ids = {30251, 30250, 30280, 30232, 30216};
	array<int> itags = {258, 328, 327, 256, 139};
	int idx = ids.find(id);
	if (idx >= 0) {
		return itags[idx];
	}
	return id;
}

uint getUniItag()
{
	uint itag = 1;
	while (HostExistITag(itag)) itag++;
	HostSetITag(itag);
	return itag;
}

string getVideoquality(JsonValue support_formats, int quality) {
	for (int i = 0; i <= support_formats.size(); i++) {
		if (support_formats[i]["quality"].asInt() == quality) return support_formats[i]["new_description"].asString();
	}
	return "未知";
}

string getCodec(int codecid) {
	array<int> codecids = {7, 12, 13};
	array<string> codec = {"avc", "hevc", "av1"};
	int idx = codecids.find(codecid);
	if (idx >= 0) {
		return codec[idx];
	}
	return "未知";
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

string Audio(const string &in path, dictionary &MetaData, array<dictionary> &QualityList) {
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
		if (data["author"].isString()) {
			MetaData["author"] = data["author"].asString();
		}
	}

	status = 6;
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

string Live(string id, const string &in path, dictionary &MetaData, array<dictionary> &QualityList) {
	log("==============================live==============================");
	string url;
	string res;

	res = post("https://api.live.bilibili.com/xlive/web-room/v1/index/getInfoByRoom?room_id=" + id);
	JsonReader Reader;
	JsonValue Root;
	if (!Reader.parse(res, Root) || !Root.isObject() || Root["code"].asInt() != 0) {
		return url;
	}

	JsonValue data = Root["data"]["room_info"];

	if (@MetaData !is null) {
		MetaData["title"] = data["title"].asString();
		MetaData["thumbnail"] = data["cover"].asString();
		MetaData["author"] = Root["data"]["anchor_info"]["base_info"]["uname"].asString();
		MetaData["content"] = data["description"].asString();
		MetaData["webUrl"] = makeWebUrl(path);
		MetaData["viewCount"] = Root["watched_show"]["num"].asString();
		MetaData["likeCount"] = Root["like_info_v3"]["like"].asString();
	}
	
	status = 6;
	
	array<int> accept_qns;
	string default_format;
	string room_id = data["room_id"].asInt();
	int qn = 30000;

	res = post("https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo?room_id=" + room_id + "&qn=" + qn + "&codec=0,1,2&format=0,1,2&mask=0&no_playurl=0&platform=web&protocol=0,1&eotf=0,1,2");
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
		if (streams[s]["protocol_name"].asString() != "http_hls") {
			continue;
		}

		JsonValue formats = streams[s]["format"];
		if (!formats.isArray()) {
			continue;
		}

		// 一些小主播不提供 fmp4，优先选择 fmp4，其次 ts
		for (int a = 0; a < formats.size(); a++) {
			string format_name_candidate = formats[a]["format_name"].asString();
			if (format_name_candidate == "fmp4") {
				default_format = "fmp4";
				break;
			}
			if (format_name_candidate == "ts") {
				default_format = "ts";
			}
		}
		if (default_format.empty()) {
			log("formats(fmp4 and ts) is not exists.");
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
	for (int i = 0; i < accept_qns.size(); i++) {
		if (best_qn < accept_qns[i]) {
			best_qn = accept_qns[i];
		}
	}

	for (int i = 0; i < accept_qns.size(); i++) {
		qn = accept_qns[i];
		res = post("https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo?room_id=" + room_id + "&qn=" + accept_qns[i] + "&codec=0,1,2&format=0,1,2&mask=0&no_playurl=0&platform=web&protocol=0,1&eotf=0,1,2");

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
			if (streams[s]["protocol_name"].asString() != "http_hls") {
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

					JsonValue url_infos = codec["url_info"];
					if (!url_infos.isArray() || url_infos.size() == 0) {
						continue;
					}

					dictionary qualityItemMain;
					dictionary qualityItemBackup;

					string codec_suffix;
					int codecOffset = 1;
					if (codec_name == "avc") {
						codec_suffix = " AVC";
						codecOffset = 1;
					} else if (codec_name == "hevc") {
						codec_suffix = " HEVC";
						codecOffset = 2;
					} else if (codec_name == "av1") {
						codec_suffix = " AV1";
						codecOffset = 3;
					} else {
						codec_suffix = " " + codec_name;
						codecOffset = 4;
					}


					JsonValue video_color_info = codec["video_color_info"];
					bool isHDR = false;
					if (codec["hdr_type"].asInt() == 1) {
						isHDR = true;
					}
					int bitrate = 0;
					string bitrateStr;

					string main_url = codec["url_info"][0]["host"].asString() + codec["base_url"].asString() + codec["url_info"][0]["extra"].asString();
					if (best_qn == codec["current_qn"].asInt() && url.empty()) url = main_url;
					qualityItemMain["url"] = main_url;
					qualityItemMain["quality"] = getLiveQuality(g_qn_desc, codec["current_qn"].asInt(), codec["hdr_type"].asInt(), video_color_info) + codec_suffix;
					// qualityItemMain["quality"] = getLiveQualityNew(g_qn_desc, codec["current_qn"].asInt(), codec["hdr_type"].asInt(), video_color_info);
					// qualityItemMain["format"] = codec_name;
					qualityItemMain["qualityDetail"] = qualityItemMain["quality"];
					qualityItemMain["itag"] = getUniItag();
					qualityItemMain["resolution"] = codec["width"].asInt() + "x" + codec["height"].asInt();
					qualityItemMain["isHDR"] = isHDR;
					bitrateStr = HostRegExpParse(main_url, "(?:[?&]origin_bitrate=)(\\d+)(?:&|$)");
					if (!bitrateStr.empty()) bitrate = HostString2UIntPtr(bitrateStr); 
					qualityItemMain["bitrate"] = bitrate * 1000;
					if (@QualityList !is null) QualityList.insertLast(qualityItemMain);

					if (url_infos.size() <= 1) {
						continue;
					}
					
					string backup_url = codec["url_info"][1]["host"].asString() + codec["base_url"].asString() + codec["url_info"][1]["extra"].asString();
					qualityItemBackup["url"] = backup_url;
					qualityItemBackup["quality"] =  "- " + getLiveQuality(g_qn_desc, codec["current_qn"].asInt(), codec["hdr_type"].asInt(), video_color_info) + codec_suffix + " 备份";
					// qualityItemBackup["quality"] =  "- " + getLiveQualityNew(g_qn_desc, codec["current_qn"].asInt(), codec["hdr_type"].asInt(), video_color_info) + " 备份";
					// qualityItemBackup["format"] = codec_name;
					qualityItemBackup["qualityDetail"] = qualityItemBackup["quality"];
					qualityItemBackup["itag"] = getUniItag();
					qualityItemBackup["resolution"] = codec["width"].asInt() + "x" + codec["height"].asInt();
					qualityItemBackup["isHDR"] = isHDR;
					bitrateStr = HostRegExpParse(url, "(?:[?&]origin_bitrate=)(\\d+)(?:&|$)");
					if (!bitrateStr.empty()) bitrate = HostString2UIntPtr(bitrateStr);
					qualityItemBackup["bitrate"] = bitrate * 1000;
					if (@QualityList !is null) QualityList.insertLast(qualityItemBackup);
				}
			}
		}
	}
	log("url", url);
	// log("Quality items", QualityList.length());
	// for (uint i = 0; i < QualityList.length(); i++) {
	//     log("QualityList[" + i + "] = " + string(QualityList[i]["quality"]) + " | " + int(QualityList[i]["itag"]) + " | " + string(QualityList[i]["url"]));
	// }
	return url;
}

bool isPlaylist(const string &in path) {
	string bvid = parseBVId(path);
	string aid = parseAVId(path);
	string params;
	if (!bvid.empty()) params += "bvid=" + bvid;
	if (!aid.empty()) params += "aid=" + aid;	
	if (bvid.empty() && aid.empty()) return false;

	string res = apiPost("/x/web-interface/wbi/view/detail?" + params + "&w_rid=" + encWbi(params));

	JsonReader Reader;
	JsonValue Root;
	if (Reader.parse(res, Root) && Root.isObject()) {
		if (Root["code"].asInt() == 0) {
			JsonValue redirect_url = Root["data"]["View"]["redirect_url"];
			if (redirect_url.isString() && redirect_url.asString().find("bangumi/play/ep") >= 0) {
				videoIsUGCorPGC.isPGC = true;
				videoIsUGCorPGC.pgcURL = redirect_url.asString();
				return true;
			}
			if (Root["data"]["View"]["ugc_season"].isObject()) {
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

bool PlayitemCheck(const string &in path) {
	log("PlayitemCheck - path", path);
	status = 1;	

	if (path.find("bilibili.com") < 0) {
		return false;
	}

	if (path.find("/video/BV") >= 0) {
		return true;
	}
	if (path.find("/video/av") >= 0) {
		return true;
	}

	if (path.find("live.bilibili.com") >= 0) {
		return true;
	}
	if (path.find("www.bilibili.com/audio/au") >= 0) {
		return true;
	}
	log("PlayitemCheck", "false");
	return false;
}

bool PlaylistCheck(const string &in path) {
	log("PlaylistCheck - path: ", path);
	status = 2;
	if (path.find("bilibili.com") < 0) {
		return false;
	}
	if (isPlaylist(path)) {
		return true;
	}
	if (!parseBVId(path).empty() || !parseAVId(path).empty()) {
		return true;
	}
	if (path.find("search.bilibili.com") >= 0) {
		return true;
	}
	if (path.find("/watchlater") >= 0) {
		return true;
	}
	if (path.find("/account/history") >= 0) {
		return true;
	}
	if (path.find("space.bilibili.com") >= 0) {
		if (path.find("/video") >= 0) {
			return true;
		}
		else if (path.find("/audio") >= 0) {
			return true;
		}
		else if (path.find("/favlist") >= 0) {
			return true;
		}
		else if (path.find("lists") >= 0) {
			return true;
		}
		else if (HostRegExpParse(path, "/([0-9]+)/[a-zA-Z0-9]").empty()) {
			return true;
		}
		else {
			return false;
		}
	}
	if (path.find("/medialist/detail/ml") >= 0) {
		return true;
	}
	if (path.find("link.bilibili.com") >= 0 && path.find("/user-center/follow") >= 0) {
		return true;
	}
	if(path.find("live.bilibili.com") >= 0){
		if(path.find("areaId") >= 0 || path.find("lol") >= 0 || path.find("hpjy") >= 0){
			return true;
		}
	}
	if (path.find("www.bilibili.com") >= 0 && HostRegExpParse(path, "www.bilibili.com/([a-zA-Z0-9]+)").empty()) {
		return true;
	}
	if (path.find("bangumi/media/md") >= 0) {
		return true;
	}
	if (path.find("bangumi/play/") >= 0) {
		log("PlaylistCheck - bangumi/play/");
		return true;
	}
	if (path.find("www.bilibili.com/v/popular/rank") >= 0) {
		return true;
	}
	if (path.find("www.bilibili.com/v/popular/history") >= 0) {
		return true;
	}
	if (path.find("www.bilibili.com/v/popular/weekly") >= 0) {
		return true;
	}
	if (gettid(path) > 0) {
		return true;
	}
	if (path.find("www.bilibili.com/audio/am") >= 0) {
		return true;
	}
	if (path.find("t.bilibili.com") >= 0) {
		return true;
	}

	log("PlaylistCheck", "false");
	return false;
}

array<dictionary> PlaylistParse(const string &in url) {
	string path = url;
	log("PlaylistParse - path", path);
	status = 3;
	array<dictionary> result;

	if (videoIsUGCorPGC.isPGC) path = videoIsUGCorPGC.pgcURL;
	if (videoIsUGCorPGC.isUGCSeason) return UGCSeason(path);

	string bvid = parseBVId(path);
	if (!bvid.empty()) {
		return RelatedVideos(path);
	}
	string avid = parseAVId(path);
	if (!avid.empty()) {
		return RelatedVideos(path);
	}
	if (path.find("/watchlater") >= 0) {
		return watchlater();
	}
	if (path.find("/account/history") >= 0) {
		return History();
	}
	if (path.find("search.bilibili.com") >= 0) {
		return Search(path);
	}
	if (path.find("space.bilibili.com") >= 0) {
		if (path.find("/video") >= 0) {
			return spaceVideo(path);
		}
		else if (path.find("/audio") >= 0) {
			return spaceAudio(path);
		}
		else if (path.find("/favlist") >= 0) {
			return FavList(path);
		}
		else if (path.find("lists") >= 0) {
			return Channel(path);
		}
		else if (HostRegExpParse(path, "/([0-9]+)/[a-zA-Z0-9]").empty()) {
			return spaceVideo(path);
		}
	}
	if (path.find("/medialist/detail/ml") >= 0) {
		return FavList(path);
	}
	if (path.find("link.bilibili.com") >= 0 && path.find("/user-center/follow") >= 0) {
		return followingLive(1);
	}
	if(path.find("live.bilibili.com") >= 0) {
		if(path.find("areaId") >= 0){
			return liveCategory(1,HostRegExpParse(path, "areaId=([0-9]+)"), HostRegExpParse(path, "parentAreaId=([0-9]+)"), 0);
		}
		if(path.find("lol") >= 0){
			return liveCategory(1,"86","2", 0);
		}
		if(path.find("hpjy") >= 0){
			return liveCategory(1,"256","3", 0);
		}
	}
	if (path.find("www.bilibili.com") >= 0 && HostRegExpParse(path, "www.bilibili.com/([a-zA-Z0-9]+)").empty()) {
		return Recommend(1);
	}
	if (path.find("bangumi/media/md") >= 0) {
		return Banggumi(HostRegExpParse(path, "bangumi/media/md([0-9]+)"), "media_id");
	}
	if (path.find("bangumi/play/ep") >= 0) {
		return Banggumi(HostRegExpParse(path, "bangumi/play/ep([0-9]+)"), "ep_id");
	}
	if (path.find("bangumi/play/ss") >= 0) {
		return Banggumi(HostRegExpParse(path, "bangumi/play/ss([0-9]+)"), "season_id");
	}
	if (path.find("www.bilibili.com/v/popular/rank") >= 0) {
		return Ranking(path);
	}
	if (path.find("www.bilibili.com/v/popular/history") >= 0) {
		return PopularHistory();
	}
	if (path.find("www.bilibili.com/v/popular/weekly") >= 0) {
		return PopularWeekly(path);
	}
	if (path.find("www.bilibili.com/audio/am") >= 0) {
		return AudioList(path);
	}
	uint tid = gettid(path);
	if (tid > 0) {
		return Dynamic(tid);
	}
	if (path.find("t.bilibili.com") >= 0) {
		return webDynamic(path);
	}

	return result;
}

string PlayitemParse(const string &in path, dictionary &MetaData, array<dictionary> &QualityList) {
	log("PlayitemParse - path", path);
	status = 4;

	if (path.find("/video/BV") >= 0 ) {
		string bvid = parseBVId(path);
		return Video(bvid, path, MetaData, QualityList);
	}
	if (path.find("/video/av") >= 0) {
		string aid = parseAVId(path);
		return Video(aid, path, MetaData, QualityList);
	}
	if (path.find("live.bilibili.com") >= 0) {
		string id = HostRegExpParse(path, "live.bilibili.com/([0-9]+)");
		if (!id.empty()) {
			return Live(id, path, MetaData, QualityList);
		}
	}
	if (path.find("www.bilibili.com/audio/au") >= 0) {
		return Audio(path, MetaData, QualityList);
	}

	return path;
}