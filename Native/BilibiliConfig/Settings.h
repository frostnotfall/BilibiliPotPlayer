#pragma once
#include "ConfigDocument.h"
#include <limits>

namespace bili {
enum class Widget { Check, Integer, Decimal, Text, Choice, Lines, Rules, Slider, Font, FontSize, ChatMode, ChatModePeer };
struct Choice { const wchar_t* label; const char* json; };
struct Setting {
    const char* path;
    int page;
    const wchar_t* group;
    const wchar_t* label;
    const wchar_t* hint;
    Widget widget;
    const char* fallback;
    double minimum = 0;
    double maximum = 1000000;
    std::vector<Choice> choices;
};
const std::vector<Setting>& settings();
enum Page { SubtitlesPage, VodPage, LivePage, PlaylistPage, AdvancedPage, PageCount };
extern const wchar_t* const PageNames[PageCount];
int sectionFor(const Setting& field);
Document defaultConfiguration();
std::wstring ruleLines(const std::string& json, int type);
std::string replaceRuleLines(const std::string& json, int type, const std::wstring& lines);
std::string compact(const Node& node);
std::wstring settingText(const Setting& field, const Document& document);
std::string settingJson(const Setting& field, const std::wstring& text);
void validateSetting(const Setting& field, const std::string& json);
}
