#include "Settings.h"
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <set>

namespace bili {
const wchar_t* const PageNames[PageCount] = { L"字幕与弹幕", L"点播", L"直播", L"播放列表", L"高级" };
const std::vector<Setting>& settings() {
    // Fallbacks match the playback script, not possibly stale template comments.
    static const std::vector<Setting> fields = {
        {"subtitle.enable",SubtitlesPage,L"视频字幕",L"启用视频字幕",L"优先使用视频自带字幕，缺少时尝试 AI 字幕。",Widget::Check,"false"},
        {"subtitle.server",SubtitlesPage,L"视频字幕",L"字幕服务器地址",L"留空使用内置解析；内置解析可能增加打开耗时。",Widget::Text,"\"\""},
        {"danmaku.enable",SubtitlesPage,L"视频弹幕",L"启用视频弹幕",L"与视频字幕同时开启时，弹幕作为次字幕显示。",Widget::Check,"false"},
        {"danmaku.server",SubtitlesPage,L"视频弹幕",L"弹幕服务器地址",L"留空使用内置解析；以下高级样式和过滤只支持内置解析。",Widget::Text,"\"\""},
        {"danmaku.font",SubtitlesPage,L"视频弹幕",L"弹幕字体",L"从本机已安装字体中选择；未安装的旧字体仅作为当前值保留。",Widget::Font,"\"微软雅黑 Light\""},
        {"danmaku.fontSize",SubtitlesPage,L"视频弹幕",L"弹幕字号",L"从下拉列表选择字号，单位：像素。",Widget::FontSize,"32",1,200},
        {"danmaku.opacity",SubtitlesPage,L"视频弹幕",L"不透明度",L"0 为完全透明，1 为完全不透明。",Widget::Slider,"0.85",0,1},
        {"danmaku.displayArea",SubtitlesPage,L"视频弹幕",L"显示区域",L"从画面顶部开始占用的高度比例。",Widget::Slider,"0.8",0.01,1},
        {"danmaku.stayTime",SubtitlesPage,L"视频弹幕",L"停留时间（秒）",L"滚动与固定弹幕的显示时长。",Widget::Decimal,"15",0.1,300},
        {"danmaku.bold",SubtitlesPage,L"字体效果（仅内置解析）",L"使用粗体",L"",Widget::Check,"true"},
        {"danmaku.fontEffect.type",SubtitlesPage,L"字体效果（仅内置解析）",L"字体效果",L"阴影、描边和重墨对应下方的独立参数。",Widget::Choice,"2",0,4,{{L"无特效","0"},{L"阴影","1"},{L"描边","2"},{L"重墨","3"},{L"描边 + 重墨","4"}}},
        {"danmaku.fontEffect.shadowDepth",SubtitlesPage,L"字体效果（仅内置解析）",L"阴影深度",L"单位：像素。",Widget::Decimal,"1",0,100},
        {"danmaku.fontEffect.outlineWidth",SubtitlesPage,L"字体效果（仅内置解析）",L"描边宽度",L"单位：像素。",Widget::Decimal,"1.5",0,100},
        {"danmaku.fontEffect.blurRadius",SubtitlesPage,L"字体效果（仅内置解析）",L"重墨模糊半径",L"单位：像素。",Widget::Decimal,"5",0,100},
        {"danmaku.blockTop",SubtitlesPage,L"弹幕过滤（仅内置解析）",L"屏蔽顶部固定弹幕",L"",Widget::Check,"false"},
        {"danmaku.blockBottom",SubtitlesPage,L"弹幕过滤（仅内置解析）",L"屏蔽底部固定弹幕",L"",Widget::Check,"false"},
        {"danmaku.blockColor",SubtitlesPage,L"弹幕过滤（仅内置解析）",L"屏蔽彩色弹幕",L"",Widget::Check,"false"},
        {"danmaku.mergeSameDanmaku",SubtitlesPage,L"弹幕过滤（仅内置解析）",L"合并相似弹幕",L"参考 pakku：合并 30 秒内相似、同音及刷屏内容，以“内容(n)”显示。",Widget::Check,"false"},
        {"danmaku.enlargeMergedDanmaku",SubtitlesPage,L"弹幕过滤（仅内置解析）",L"弹幕合并后增大字号",L"合并超过 5 条时，按 pakku 的对数比例增大字号；需开启合并相似弹幕。",Widget::Check,"false"},
        {"danmaku.autoShrinkDanmaku",SubtitlesPage,L"弹幕过滤（仅内置解析）",L"自动减小字号",L"瞬时弹幕密度超过 75 时按比例缩小，最小 16 号。",Widget::Check,"false"},
        {"danmaku.autoSelectDanmaku",SubtitlesPage,L"弹幕过滤（仅内置解析）",L"自动弹幕优选",L"默认开启；空间不足时优先保留合并弹幕。关闭后保留全部候选，弹幕可能重叠。",Widget::Check,"true"},
        {"danmaku.blockRepeatedUserDanmaku",SubtitlesPage,L"弹幕过滤（仅内置解析）",L"屏蔽同一用户重复发送的相同内容",L"",Widget::Check,"false"},
        {"danmaku.enableCloudBlockList",SubtitlesPage,L"弹幕过滤（仅内置解析）",L"使用云端屏蔽列表",L"正则规则需要 Extension\\Lib\\BilibiliRegex.dll。",Widget::Check,"false"},
        {"danmaku.blockRules",SubtitlesPage,L"本地屏蔽规则（仅内置解析）",L"屏蔽规则",L"每行一条。正则规则需要 BilibiliRegex.dll；用户 UID 只能填写数字。",Widget::Rules,"[]"},

        {"vod.showRecommendedVideos",VodPage,L"点播播放列表",L"打开单个视频时显示推荐视频",L"可从播放列表中继续选择其他推荐内容。",Widget::Check,"false"},
        {"vod.showUgcSeason",VodPage,L"点播播放列表",L"显示用户合集与全部分 P",L"视频属于合集或分 P 时列出其他内容。",Widget::Check,"true"},
        {"vod.showTrailer",VodPage,L"点播播放列表",L"显示番剧与电影预告片",L"",Widget::Check,"true"},
        {"vod.enableVodChatUrl",VodPage,L"侧边栏",L"显示点播网页评论区",L"观看视频时，在 PotPlayer 播放列表侧显示评论。",Widget::Check,"false"},
        {"vod.queryPlayPosition",VodPage,L"观看记录",L"从 B 站记录的播放进度继续",L"精准空降时不读取云端进度；开启会增加一次请求。",Widget::Check,"false"},
        {"vod.heartBeatInterval",VodPage,L"观看记录",L"心跳上报间隔（秒）",L"只在启用观看记录同步时生效，最小 15 秒。",Widget::Integer,"15",15,86400},

        {"live.useHttpStream",LivePage,L"播放方式",L"使用 HTTP-FLV 直播流",L"延迟更低，但 PK 时可能断开或被降画质；默认使用 HLS。",Widget::Check,"false"},
        {"live.parseM3u8RealUrl.enable",LivePage,L"M3U8 地址解析",L"解析真实 M3U8 地址",L"减少播放流名称被覆盖成 HLS 的情况；需要额外请求。",Widget::Check,"true"},
        {"live.parseM3u8RealUrl.fastMode",LivePage,L"M3U8 地址解析",L"启用快速模式",L"只解析下方列表中的重定向域名。",Widget::Check,"true"},
        {"live.parseM3u8RealUrl.m3u8RedirectDomains",LivePage,L"M3U8 地址解析",L"快速解析域名",L"每行一个域名，不包含协议或路径。",Widget::Lines,"[]"},
        {"live.liveChatUrl.useWebPage",LivePage,L"聊天窗口",L"直播聊天方式",L"选择一种聊天方式；自建弹幕姬需要先部署服务，并填写下方地址。",Widget::ChatMode,"true"},
        {"live.liveChatUrl.useBilibiliDanmuji",LivePage,L"聊天窗口",L"使用自建 Bilibili_Danmuji 服务",L"",Widget::ChatModePeer,"false"},
        {"live.liveChatUrl.bilibiliDanmujiServer",LivePage,L"聊天窗口",L"弹幕姬服务地址",L"使用自建服务时必须填写 http:// 或 https:// 地址。",Widget::Text,"\"\""},
        {"live.useKeyframe",LivePage,L"直播播放列表",L"使用直播关键帧缩略图",L"不存在关键帧时使用普通封面。",Widget::Check,"false"},
        {"live.showRecommendedLiveRooms",LivePage,L"直播播放列表",L"打开单个直播时显示推荐直播间",L"",Widget::Check,"false"},

        {"videoNums.webDynamicVideoNums",PlaylistPage,L"播放列表生成数量",L"我的动态",L"按视频数量统计；需要过滤非视频动态。",Widget::Integer,"50",1,10000},
        {"videoNums.recommendVideoNums",PlaylistPage,L"播放列表生成数量",L"首页推荐",L"最终数量可能略多；点击播放列表名称即可刷新。",Widget::Integer,"30",1,10000},
        {"videoNums.liveRecommendPage",PlaylistPage,L"播放列表生成数量",L"直播首页推荐页数",L"每页约 15 个直播间。",Widget::Integer,"1",1,500},
        {"videoNums.historyVideoNums",PlaylistPage,L"播放列表生成数量",L"历史记录",L"最终数量可能略多。",Widget::Integer,"30",1,10000},
        {"videoNums.popularAllPages",PlaylistPage,L"播放列表生成数量",L"综合热门页数",L"每页约 50 个视频。",Widget::Integer,"1",1,500},
        {"videoNums.spaceDynamicVideoNums",PlaylistPage,L"播放列表生成数量",L"个人空间动态",L"最终数量可能略多。",Widget::Integer,"30",1,10000},
        {"videoNums.maxliveroom",PlaylistPage,L"播放列表生成数量",L"直播分区最大房间数",L"接口每页返回约 20 个直播间。",Widget::Integer,"40",1,10000},

        {"blockP2PCDN",AdvancedPage,L"网络与缓存",L"屏蔽 P2P CDN",L"默认启用。",Widget::Check,"true"},
        {"cacheValidTime",AdvancedPage,L"网络与缓存",L"请求缓存时间（秒）",L"默认 300 秒；0 表示不保留缓存。",Widget::Integer,"300",0,86400},
        {"enableSponsorBlock",AdvancedPage,L"空降助手",L"启用空降助手",L"依赖外部服务；连接不稳定可能影响打开视频。",Widget::Check,"false"},
        {"sponsorBlockMirror",AdvancedPage,L"空降助手",L"镜像服务地址",L"留空使用默认服务；填写 http:// 或 https:// 地址。",Widget::Text,"\"\""},
        {"heartBeat",AdvancedPage,L"观看记录",L"同步观看记录到 B 站",L"需要登录 B 站；同时用于点播与直播历史记录。",Widget::Check,"false"},
        {"disableAVC",AdvancedPage,L"画质与编码",L"存在其他编码时禁用 AVC",L"仅影响点播；没有其他编码时仍保留 AVC。",Widget::Check,"false"},
        {"defaultCodec",AdvancedPage,L"画质与编码",L"编码优先顺序",L"从左到右依次尝试；不确定时保持原设置。",Widget::Choice,"[\"hevc\",\"avc\",\"av1\"]",0,0,{{L"HEVC → AVC → AV1","[\"hevc\",\"avc\",\"av1\"]"},{L"HEVC → AV1 → AVC","[\"hevc\",\"av1\",\"avc\"]"},{L"AV1 → HEVC → AVC","[\"av1\",\"hevc\",\"avc\"]"},{L"AV1 → AVC → HEVC","[\"av1\",\"avc\",\"hevc\"]"},{L"AVC → HEVC → AV1","[\"avc\",\"hevc\",\"av1\"]"},{L"AVC → AV1 → HEVC","[\"avc\",\"av1\",\"hevc\"]"}}},
        {"preferHDR",AdvancedPage,L"画质与编码",L"优先 HDR / 杜比视界",L"开启后，HDR / 杜比视界的优先级高于 8K 超高清。",Widget::Check,"false"},
        {"debug",AdvancedPage,L"调试",L"启用调试日志",L"用于排查问题，通常关闭。",Widget::Check,"false"}
    };
    return fields;
}
std::string compact(const Node& node) {
    if (node.kind == Kind::String) return quote(node.text);
    if (node.kind == Kind::Number || node.kind == Kind::Bool) return node.text;
    if (node.kind == Kind::Null) return "null";
    std::string result = node.kind == Kind::Object ? "{" : "[";
    for (size_t i = 0; i < node.children.size(); ++i) {
        if (i) result += ',';
        if (node.kind == Kind::Object) result += quote(node.keys[i]) + ':';
        result += compact(node.children[i]);
    }
    return result + (node.kind == Kind::Object ? '}' : ']');
}
int sectionFor(const Setting& field) {
    if (field.page != SubtitlesPage) return 0;
    std::string path = field.path;
    if (path == "danmaku.bold" || path.find("danmaku.fontEffect.") == 0) return 1;
    if (path.find("danmaku.block") == 0 || path == "danmaku.mergeSameDanmaku" || path == "danmaku.enlargeMergedDanmaku" || path == "danmaku.autoShrinkDanmaku" || path == "danmaku.autoSelectDanmaku" || path == "danmaku.enableCloudBlockList") return 2;
    return 0;
}
namespace {
std::string defaultObject(const Node& node, const std::string& path, int depth) {
    if (node.kind != Kind::Object) return compact(node);
    std::string indent(static_cast<size_t>(depth) * 4, ' '), result = "{\n";
    for (size_t i = 0; i < node.keys.size(); ++i) {
        std::string key = path.empty() ? node.keys[i] : path + "." + node.keys[i];
        for (const auto& field : settings()) if (key == field.path) { result += indent + "    // " + utf8(field.label) + "\n"; break; }
        result += indent + "    " + quote(node.keys[i]) + ": " + defaultObject(node.children[i], key, depth + 1);
        result += i + 1 == node.keys.size() ? "\n" : ",\n";
    }
    return result + indent + "}";
}
std::vector<std::string> splitRules(const std::wstring& text, int type) {
    std::vector<std::string> result;
    size_t start = 0;
    while (start < text.size()) {
        size_t end = text.find_first_of(L"\r\n", start);
        if (end == std::wstring::npos) end = text.size();
        std::wstring line = text.substr(start, end - start);
        if (type == 2) {
            size_t first = line.find_first_not_of(L" \t"), last = line.find_last_not_of(L" \t");
            line = first == std::wstring::npos ? L"" : line.substr(first, last - first + 1);
        }
        if (!line.empty()) result.push_back(utf8(line));
        start = end + 1;
    }
    return result;
}
}
Document defaultConfiguration() {
    Document result("{}");
    for (const auto& field : settings()) result.set(field.path, field.fallback);
    // Recommended values in the distributed configuration. Reading a sparse
    // existing file still uses the playback script's historical fallbacks.
    result.set("vod.enableVodChatUrl", "true");
    result.set("videoNums.maxliveroom", "100");
    result.set("live.parseM3u8RealUrl.m3u8RedirectDomains", "[\"gotcha204.bilivideo.com\",\"gotcha204b.bilivideo.com\"]");
    return Document("// BilibiliPotPlayer 默认配置\n// 使用 Bilibili_Config_Editor.exe 调整设置。\n" + defaultObject(result.root(), "", 0) + "\n");
}
std::wstring ruleLines(const std::string& json, int type) {
    Document list(json);
    std::wstring result;
    for (const auto& rule : list.root().children) {
        const Node* kind = rule.member("type"); const Node* filter = rule.member("filter");
        if (kind && filter && std::atoi(kind->text.c_str()) == type) {
            if (!result.empty()) result += L"\r\n";
            result += wide(filter->text);
        }
    }
    return result;
}
std::string replaceRuleLines(const std::string& json, int type, const std::wstring& lines) {
    Document list(json);
    auto replacements = splitRules(lines, type);
    std::vector<const Node*> old;
    for (const auto& rule : list.root().children) {
        auto kind = rule.member("type");
        if (kind && std::atoi(kind->text.c_str()) == type) old.push_back(&rule);
    }
    std::vector<bool> used(old.size(), false);
    std::vector<std::string> values;
    for (const auto& text : replacements) {
        std::string value;
        for (size_t i = 0; i < old.size(); ++i) {
            auto filter = old[i]->member("filter");
            if (!used[i] && filter && filter->text == text) { value = compact(*old[i]); used[i] = true; break; }
        }
        if (value.empty()) value = "{\"type\":" + std::to_string(type) + ",\"filter\":" + quote(text) + "}";
        values.push_back(std::move(value));
    }
    size_t next = 0;
    std::string result = "[";
    auto append = [&](const std::string& value) { if (result.size() > 1) result += ','; result += value; };
    for (const auto& rule : list.root().children) {
        auto kind = rule.member("type");
        if (!kind || std::atoi(kind->text.c_str()) != type) append(compact(rule));
        else if (next < values.size()) append(values[next++]);
    }
    while (next < values.size()) append(values[next++]);
    return result + ']';
}
std::wstring settingText(const Setting& field, const Document& document) {
    const Node* node = document.find(field.path);
    Document fallback(field.fallback);
    if (!node) node = &fallback.root();
    Kind expected = fallback.root().kind;
    if (node->kind != expected) throw Error(std::string(field.path) + " 的类型不正确，请先修复此配置项。");
    if (field.widget == Widget::Text || field.widget == Widget::Font) return wide(node->text);
    if (field.widget == Widget::Lines) {
        std::wstring result;
        for (const auto& child : node->children) {
            if (child.kind != Kind::String || child.text.find_first_of("\r\n\0",0,3) != std::string::npos)
                throw Error(std::string(field.path) + " 必须是域名字符串列表。");
            if (!result.empty()) result += L"\r\n";
            result += wide(child.text);
        }
        return result;
    }
    return wide(compact(*node));
}
std::string settingJson(const Setting& field, const std::wstring& text) {
    if (field.widget == Widget::Text || field.widget == Widget::Font) return quote(utf8(text));
    if (field.widget == Widget::Lines) {
        std::string result = "[";
        size_t start = 0;
        while (start < text.size()) {
            size_t end = text.find_first_of(L"\r\n", start);
            if (end == std::wstring::npos) end = text.size();
            std::wstring line = text.substr(start, end - start);
            auto first = line.find_first_not_of(L" \t");
            auto last = line.find_last_not_of(L" \t");
            if (first != std::wstring::npos) { if (result.size() > 1) result += ','; result += quote(utf8(line.substr(first, last - first + 1))); }
            start = end + 1;
        }
        return result + ']';
    }
    return utf8(text);
}
void validateSetting(const Setting& field, const std::string& json) {
    Document parsed(json);
    const auto& node = parsed.root();
    Document fallback(field.fallback);
    if (node.kind != fallback.root().kind) throw Error("配置值类型不正确。");
    if (node.kind == Kind::Number) {
        char* end = nullptr;
        double number = std::strtod(node.text.c_str(), &end);
        if (!end || *end || !std::isfinite(number) || number < field.minimum || number > field.maximum)
            throw Error("请输入 " + std::to_string(field.minimum) + " 到 " + std::to_string(field.maximum) + " 之间的数字。");
        if (field.widget == Widget::Integer && std::floor(number) != number) throw Error("此项必须填写整数。");
        // Playback uses asInt for integer fields, so avoid exponent/fraction
        // forms that can be interpreted differently by the host JSON library.
        if (field.widget == Widget::Integer && node.text.find_first_of(".eE") != std::string::npos) throw Error("整数请直接填写数字，不使用小数或科学计数法。");
    }
    if ((field.widget == Widget::Text && std::string(field.path).find("erver") != std::string::npos) || std::string(field.path) == "sponsorBlockMirror") {
        const auto& url = node.text;
        if (!url.empty()) {
            size_t prefix = url.compare(0,7,"http://") == 0 ? 7 : url.compare(0,8,"https://") == 0 ? 8 : 0;
            if (!prefix || prefix == url.size() || url[prefix] == '/' || url.find_first_of(" \t\r\n") != std::string::npos)
                throw Error("服务器地址必须以 http:// 或 https:// 开头，且不能包含空白。");
        }
    }
    if (field.widget == Widget::Lines) {
        for (const auto& item : node.children) {
            if (item.kind != Kind::String || item.text.empty() || item.text.find_first_of(" /\\:\t\r\n") != std::string::npos)
                throw Error("每行应是一个域名，不包含协议、空白或路径。");
        }
    }
    if (std::string(field.path) == "defaultCodec") {
        std::set<std::string> seen;
        if (node.children.empty()) throw Error("编码列表不能为空。");
        for (const auto& item : node.children) {
            if (item.kind != Kind::String || (item.text != "avc" && item.text != "hevc" && item.text != "av1") || !seen.insert(item.text).second)
                throw Error("编码列表只能包含不重复的 hevc、avc、av1。");
        }
    }
    if (field.widget == Widget::Rules) {
        for (const auto& rule : node.children) {
            const Node* type = rule.member("type"); const Node* filter = rule.member("filter");
            if (!type || type->kind != Kind::Number || (type->text != "0" && type->text != "1" && type->text != "2") ||
                !filter || filter->kind != Kind::String || filter->text.empty()) throw Error("屏蔽规则必须包含 type（0、1 或 2）和非空 filter 字符串。");
            if (type->text == "2" && filter->text.find_first_not_of("0123456789") != std::string::npos) throw Error("用户 UID 必须为数字。");
        }
    }
}
}
