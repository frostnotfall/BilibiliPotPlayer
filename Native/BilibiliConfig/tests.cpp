#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include "Settings.h"
#include <cstdio>
#include <functional>
#include <set>

using namespace bili;
namespace {
int checks=0;
void require(bool pass,const char* name){++checks;if(!pass)throw Error(std::string("FAILED: ")+name);}
void rejects(const std::function<void()>& action,const char* name){bool failed=false;try{action();}catch(const Error&){failed=true;}require(failed,name);}
void write(const std::wstring& path,const std::string& text){HANDLE file=CreateFileW(path.c_str(),GENERIC_WRITE,0,nullptr,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);if(file==INVALID_HANDLE_VALUE)throw Error("test file open failed");DWORD written=0;BOOL okay=WriteFile(file,text.data(),static_cast<DWORD>(text.size()),&written,nullptr);CloseHandle(file);require(okay&&written==text.size(),"fixture write");}
const Setting& field(const char* path){for(const auto& f:settings())if(std::string(f.path)==path)return f;throw Error("field not found");}
void leafCoverage(const Node& node,const std::string& path,const std::set<std::string>& known){if(node.kind!=Kind::Object){require(known.count(path)!=0,"every shipped field has a control");return;}for(size_t i=0;i<node.keys.size();++i)leafCoverage(node.children[i],path.empty()?node.keys[i]:path+"."+node.keys[i],known);}
}
int wmain(int argc,wchar_t** argv){
 try{
    if(argc!=3)throw Error("usage: tests.exe config.json test-directory");
    std::string source=readFile(argv[1]);Document shipped(source);
    require(shipped.source()==source,"no-op byte preservation");
    std::set<std::string> paths;
    for(const auto& f:settings()){
        require(paths.insert(f.path).second,"unique setting path");
        auto text=settingText(f,shipped);validateSetting(f,settingJson(f,text));
        Document minimal("{}");auto fallback=settingText(f,minimal);validateSetting(f,settingJson(f,fallback));
        Document added("{}");added.set(f.path,settingJson(f,text));
        require(added.find(f.path)!=nullptr,"insert nested setting");
    }
    leafCoverage(shipped.root(),"",paths);
    require(settings().size()==52,"all 52 active settings covered");
    require(paths.count("bili_jct")==0,"legacy CSRF setting removed");
    require(field("danmaku.font").widget==Widget::Font&&field("danmaku.fontSize").widget==Widget::FontSize,"font and size selection widgets");
    require(field("danmaku.blockRules").page==field("subtitle.enable").page,"subtitle and filters share page");
    require(sectionFor(field("danmaku.blockRules"))==2&&sectionFor(field("danmaku.fontEffect.type"))==1,"danmaku section mapping");
    require(field("live.parseM3u8RealUrl.fastMode").page==field("live.parseM3u8RealUrl.m3u8RedirectDomains").page,"fast mode and domains share page");
    require(std::wstring(field("live.parseM3u8RealUrl.fastMode").group)==field("live.parseM3u8RealUrl.m3u8RedirectDomains").group,"fast mode and domains share group");
    Document defaults=defaultConfiguration();
    require(!defaults.find("bili_jct"),"initialized defaults omit legacy token");
    for(const auto& f:settings()){require(defaults.find(f.path)!=nullptr,"initialized defaults complete");validateSetting(f,settingJson(f,settingText(f,defaults)));}
    require(defaults.find("danmaku.fontSize")->text=="32","initial font size");
    require(defaults.find("danmaku.opacity")->text=="0.85","initial opacity");
    require(defaults.find("live.parseM3u8RealUrl.m3u8RedirectDomains")->children.size()==2,"initial fast mode domains");
    std::string typed="[{\"type\":0,\"filter\":\"关键词\",\"future\":true},{\"type\":1,\"filter\":\".*正则.*\"},{\"type\":2,\"filter\":\"123456\"}]";
    require(ruleLines(typed,0)==L"关键词"&&ruleLines(typed,1)==L".*正则.*"&&ruleLines(typed,2)==L"123456","split rules by type");
    typed=replaceRuleLines(typed,0,L"关键词\r\n另一个\n 带空格 ");
    require(ruleLines(typed,0)==L"关键词\r\n另一个\r\n 带空格 ","multiline keywords preserve spaces");
    require(Document(typed).root().children.front().member("future")->text=="true","unchanged rules preserve unknown attributes");
    require(ruleLines(typed,1)==L".*正则.*"&&ruleLines(typed,2)==L"123456","editing one type preserves others");
    typed=replaceRuleLines(typed,1,L"\\d+\r\n.*示例.*");
    require(ruleLines(typed,1)==L"\\d+\r\n.*示例.*","regex backslashes preserved");
    typed=replaceRuleLines(typed,2,L" 123456 \r\n\n10086\n");
    require(ruleLines(typed,2)==L"123456\r\n10086","UID whitespace trimmed");
    validateSetting(field("danmaku.blockRules"),typed);
    typed=replaceRuleLines(typed,1,L"");require(ruleLines(typed,1).empty()&&!ruleLines(typed,0).empty(),"clearing one rule type preserves others");
    typed=replaceRuleLines(typed,0,L"相同\n相同");require(ruleLines(typed,0)==L"相同\r\n相同","duplicate rules retained");
    typed=replaceRuleLines(typed,2,L"字母");rejects([&]{validateSetting(field("danmaku.blockRules"),typed);},"multiline UID validation");
    Document one(source);const auto* old=one.find("danmaku.fontSize");size_t start=old->begin,end=old->end;
    one.set("danmaku.fontSize","36");
    require(one.source()==source.substr(0,start)+"36"+source.substr(end),"only changed token is replaced");
    Document unknown("\xEF\xBB\xBF{\r\n // 用户注释\r\n \"unknown\": {\"x\": [1,\"http://a//b\"]}, // 保留\r\n \"danmaku\": {\"enable\":false /*尾注*/}\r\n}\r\n");
    unknown.set("danmaku.fontEffect.type","4");unknown.set("new.nested.enable","true");unknown.set("unknown.x","[2]");
    require(unknown.source().compare(0,3,"\xEF\xBB\xBF")==0,"BOM preserved");
    require(unknown.source().find("// 用户注释\r\n")!=std::string::npos,"CRLF comment preserved");
    require(unknown.source().find("// 保留")!=std::string::npos&&unknown.source().find("/*尾注*/")!=std::string::npos,"inline comments preserved on insertion");
    require(unknown.find("new.nested.enable")->text=="true","multi-level insertion");
    Document commented("\xEF\xBB\xBF// 文件头\r\n{\r\n\"list\": [ // 规则示例\r\n// {\"type\":0,\"filter\":\"关键词\"}\r\n{\"url\":\"https://host/*string*/\", /* 重复注释 */ \"id\":1},\r\n/* 重复注释 */ 2 // 尾项\r\n],\r\n\"unknown\":true // 未管理项\r\n}\r\n// 文件尾\r\n");
    auto unchanged=commented.source();commented.set("list","[{\"url\":\"https://host/*string*/\",\"id\":1},2]");
    require(commented.source()==unchanged,"equal list values preserve exact bytes including comments");
    commented.set("list","[]");
    require(commented.find("list")->children.empty(),"commented list resets to empty");
    for(const char* comment:{"// 文件头","// 规则示例","// {\"type\":0,\"filter\":\"关键词\"}","// 尾项","// 未管理项","// 文件尾"})require(commented.source().find(comment)!=std::string::npos,"list replacement retains all comments");
    auto first=commented.source().find("/* 重复注释 */");
    require(first!=std::string::npos&&commented.source().find("/* 重复注释 */",first+1)!=std::string::npos,"duplicate comment occurrences retained");
    require(commented.source().find("/*string*/")==std::string::npos,"comment-like text inside strings is not retained as a comment");
    unchanged=commented.source();commented.set("list","[]");require(commented.source()==unchanged,"repeated initialization does not duplicate comments");
    Document partial("{\"list\":[{/* kept */\"id\":1},{/* removed */\"id\":2}]}");
    partial.set("list","[{/* kept */\"id\":1}]");
    require(partial.source().find("/* kept */")==partial.source().rfind("/* kept */")&&partial.source().find("/* removed */")!=std::string::npos,"retained raw entries do not duplicate existing comments");
    for(auto fixture:{"{}","{\"a\":1}","{\"a\":1 //comment\n}","{\n //empty\n}","{\"a\":{/*keep*/}}"}){Document d(fixture);d.set("b.c","\"中文😀\"");require(d.find("b.c")->text=="中文😀","comment-aware insertion");}
    Document unicode("{\"s\":\"\\ud83d\\ude00\\u4e2d\\n\\u0000\",\"url\":\"http://a/*x*/\"}");
    require(unicode.find("s")->text==std::string("😀中\n\0",9),"surrogates and embedded NUL");
    require(Document(quote(unicode.find("s")->text)).root().text==unicode.find("s")->text,"string escaping roundtrip");
    for(auto bad:{"", "{", "{\"a\":}","{\"a\":1,}","[1,]","{\"a\":1 \"b\":2}","{\"a\":1,\"a\":2}","{\"x\":01}","{\"x\":1.}","{\"x\":1e}","{\"x\":NaN}","{\"x\":\"\\ud800\"}","{\"x\":\"\\udc00\"}","{\"x\":\"\\q\"}","{/*oops}","{} garbage"})rejects([&]{Document d(bad);},"invalid JSON rejected");
    rejects([]{Document d(std::string("{\"a\":\"")+"\xFF"+"\"}");},"invalid UTF8 rejected");
    rejects([]{Document d(std::string(66,'[')+"0"+std::string(66,']'));},"depth bounded");
    rejects([]{Document d("{\"a\":1}");d.set("a.b","true");},"nonobject parent protected");
    rejects([]{Document d("{}");d.set("x","true,false");},"replacement must be one value");
    rejects([]{validateSetting(field("danmaku.opacity"),"1.1");},"opacity range");
    rejects([]{validateSetting(field("danmaku.fontSize"),"-1");},"font size range");
    rejects([]{validateSetting(field("vod.heartBeatInterval"),"14");},"minimum heartbeat interval");
    rejects([]{validateSetting(field("cacheValidTime"),"3.5");},"integer validation");
    rejects([]{validateSetting(field("cacheValidTime"),"3e1");},"integer JSON representation");
    rejects([]{validateSetting(field("danmaku.opacity"),"1e999");},"infinity rejected");
    rejects([]{validateSetting(field("subtitle.server"),"\"file:///x\"");},"server protocol validation");
    rejects([]{validateSetting(field("defaultCodec"),"[\"hevc\",\"hevc\"]");},"duplicate codec validation");
    rejects([]{validateSetting(field("defaultCodec"),"[]");},"empty codec validation");
    rejects([]{validateSetting(field("danmaku.blockRules"),"[{\"type\":2,\"filter\":\"abc\"}]");},"UID validation");
    rejects([]{validateSetting(field("danmaku.blockRules"),"[{\"type\":0,\"filter\":\"\"}]");},"empty rule validation");
    auto domains=settingJson(field("live.parseM3u8RealUrl.m3u8RedirectDomains"),L" a.example.com \r\n\r\nb.example.com\n");
    require(domains=="[\"a.example.com\",\"b.example.com\"]","domain list normalization");
    validateSetting(field("live.parseM3u8RealUrl.m3u8RedirectDomains"),domains);
    rejects([]{validateSetting(field("live.parseM3u8RealUrl.m3u8RedirectDomains"),"[\"https://bad/a\"]");},"domain list validation");
    std::wstring fixture=std::wstring(argv[2])+L"\\配置保存测试.json";write(fixture,source);
    saveFile(fixture,one.source());require(readFile(fixture)==one.source(),"atomic save roundtrip");
    write(fixture,"{\"external\":true}");saveFile(fixture,source);require(readFile(fixture)==source,"save directly replaces current file without external check");
    WIN32_FIND_DATAW found{};HANDLE search=FindFirstFileW((fixture+L".*.bak").c_str(),&found);require(search==INVALID_HANDLE_VALUE,"no backup created");if(search!=INVALID_HANDLE_VALUE)FindClose(search);
    SetFileAttributesW(fixture.c_str(),FILE_ATTRIBUTE_READONLY);
    rejects([&]{saveFile(fixture,one.source());},"read-only save failure");
    SetFileAttributesW(fixture.c_str(),FILE_ATTRIBUTE_NORMAL);require(readFile(fixture)==source,"failed save leaves original intact");
    HANDLE locked=CreateFileW(fixture.c_str(),GENERIC_READ,0,nullptr,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,nullptr);
    require(locked!=INVALID_HANDLE_VALUE,"lock fixture");rejects([&]{saveFile(fixture,one.source());},"locked file save failure");CloseHandle(locked);
    require(readFile(fixture)==source,"locked save leaves original intact");
    std::wstring ui=std::wstring(argv[2])+L"\\ui-fixture.json";write(ui,source);
    printf("PASS: %d checks; %zu settings; parser, preservation, validation, file saves\n",checks,settings().size());return 0;
 }catch(const std::exception& e){fprintf(stderr,"%s\n",e.what());return 1;}
}
