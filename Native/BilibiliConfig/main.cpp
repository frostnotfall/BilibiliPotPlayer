#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#define _WIN32_WINNT 0x0A00
#include <windows.h>
#include <commctrl.h>
#include <commdlg.h>
#include <shellapi.h>
#include <windowsx.h>
#include "Settings.h"
#include "Preview.h"
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <memory>
#include <array>
#include <set>

using namespace bili;
namespace {
constexpr int OpenId = 100, TabId = 101, ApplyId = 102, ResetAllId = 103, ResetPageId = 104, SectionId = 105, ChatOffId = 106, FieldBase = 1000;
constexpr wchar_t WindowClass[] = L"BilibiliConfigEditor";
constexpr wchar_t PaneClass[] = L"BilibiliConfigPane";
constexpr wchar_t PreviewClass[] = L"BilibiliConfigPreview";
HINSTANCE instance;
struct App;
LRESULT CALLBACK WindowProc(HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK PaneProc(HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK PreviewProc(HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK FocusProc(HWND, UINT, WPARAM, LPARAM, UINT_PTR, DWORD_PTR);

std::wstring textOf(HWND window) {
    int size = GetWindowTextLengthW(window);
    std::wstring text(static_cast<size_t>(size) + 1, L'\0');
    GetWindowTextW(window, text.data(), size + 1); text.resize(size); return text;
}
void message(HWND owner, const std::string& error) {
    MessageBoxW(owner, wide(error).c_str(), L"BilibiliPotPlayer 配置", MB_OK | MB_ICONERROR);
}
std::wstring fullPath(const std::wstring& path) {
    DWORD length = GetFullPathNameW(path.c_str(), 0, nullptr, nullptr);
    if (!length) throw Error("无法解析配置文件路径。");
    std::wstring result(length, L'\0');
    DWORD actual = GetFullPathNameW(path.c_str(), length, result.data(), nullptr);
    if (!actual || actual >= length) throw Error("配置文件路径过长。");
    result.resize(actual); return result;
}
std::wstring defaultPath() {
    std::wstring module(32768, L'\0');
    DWORD size = GetModuleFileNameW(nullptr, module.data(), static_cast<DWORD>(module.size()));
    module.resize(size);
    std::wstring beside = module.substr(0, module.find_last_of(L"\\/") + 1) + L"Bilibili_Config.json";
    if (GetFileAttributesW(beside.c_str()) != INVALID_FILE_ATTRIBUTES) return beside;
    std::wstring repository = fullPath(L"Extension\\Media\\PlayParse\\Bilibili_Config.json");
    return GetFileAttributesW(repository.c_str()) != INVALID_FILE_ATTRIBUTES ? repository : beside;
}
struct Binding { HWND control = nullptr, output = nullptr; int y = 0; std::vector<std::string> options; std::array<HWND,3> ruleEditors{}; };
std::vector<std::wstring> installedFonts() {
    std::vector<std::wstring> names;
    HDC dc = GetDC(nullptr); LOGFONTW query{}; query.lfCharSet = DEFAULT_CHARSET;
    EnumFontFamiliesExW(dc,&query,[](const LOGFONTW* font,const TEXTMETRICW*,DWORD,LPARAM data)->int {
        if(font->lfFaceName[0] && font->lfFaceName[0] != L'@') reinterpret_cast<std::vector<std::wstring>*>(data)->emplace_back(font->lfFaceName);
        return 1;
    },reinterpret_cast<LPARAM>(&names),0);
    ReleaseDC(nullptr,dc);
    std::sort(names.begin(),names.end());names.erase(std::unique(names.begin(),names.end()),names.end());return names;
}

struct App {
    HWND window = nullptr, pathControl = nullptr, openButton = nullptr, tab = nullptr, pane = nullptr,
        preview = nullptr, status = nullptr, ok = nullptr, cancel = nullptr, apply = nullptr,
        resetAll = nullptr, resetPage = nullptr, sections = nullptr, chatOff = nullptr;
    HFONT font = nullptr;
    int dpi = 96, page = SubtitlesPage, section = 0, contentHeight = 0, scroll[PageCount + 2] = {};
    bool building = false, initializingAll = false;
    std::wstring path;
    std::unique_ptr<Document> document;
    std::vector<std::wstring> initial, draft;
    std::vector<Binding> bindings;
    std::vector<bool> initialized;
    std::vector<std::wstring> fonts;
    int scrollIndex() const { return page == SubtitlesPage ? PageCount - 1 + section : page - 1; }
    int px(int n) const { return MulDiv(n, dpi, 96); }
    size_t fieldIndex(const char* name) const {for(size_t i=0;i<settings().size();++i)if(std::string(settings()[i].path)==name)return i;throw Error("配置项不存在。");}
    int chatMode() const {return value("live.liveChatUrl.useBilibiliDanmuji")==L"true"?2:value("live.liveChatUrl.useWebPage")==L"true"?1:0;}
    void syncChat(){
        int mode=chatMode();
        if(chatOff)Button_SetCheck(chatOff,mode==0?BST_CHECKED:BST_UNCHECKED);
        HWND web=bindings[fieldIndex("live.liveChatUrl.useWebPage")].control,custom=bindings[fieldIndex("live.liveChatUrl.useBilibiliDanmuji")].control;
        if(web)Button_SetCheck(web,mode==1?BST_CHECKED:BST_UNCHECKED);
        if(custom)Button_SetCheck(custom,mode==2?BST_CHECKED:BST_UNCHECKED);
        HWND server=bindings[fieldIndex("live.liveChatUrl.bilibiliDanmujiServer")].control;if(server)EnableWindow(server,mode==2);
    }
    void selectChat(int mode){
        draft[fieldIndex("live.liveChatUrl.useWebPage")]=mode==1?L"true":L"false";
        draft[fieldIndex("live.liveChatUrl.useBilibiliDanmuji")]=mode==2?L"true":L"false";
        syncChat();updateDirty();SetWindowTextW(status,dirty()?L"聊天方式已修改，尚未保存。":L"设置未改动。");
    }
    HWND add(HWND parent, const wchar_t* cls, const wchar_t* title, DWORD style, int x, int y, int w, int h, int id = 0, DWORD ex = 0) {
        HWND child = CreateWindowExW(ex, cls, title, WS_CHILD | WS_VISIBLE | style, x, y, w, h, parent,
            reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)), instance, nullptr);
        if (!child) throw Error("创建窗口控件失败。");
        SendMessageW(child, WM_SETFONT, reinterpret_cast<WPARAM>(font), TRUE); return child;
    }
    int comboContentWidth(HWND combo) const {
        HDC dc = GetDC(combo);
        HGDIOBJ previous = SelectObject(dc, reinterpret_cast<HFONT>(SendMessageW(combo, WM_GETFONT, 0, 0)));
        int textWidth = 0;
        int count = static_cast<int>(SendMessageW(combo, CB_GETCOUNT, 0, 0));
        for (int i = 0; i < count; ++i) {
            int length = static_cast<int>(SendMessageW(combo, CB_GETLBTEXTLEN, i, 0));
            if (length == CB_ERR) continue;
            std::wstring label(static_cast<size_t>(length) + 1, L'\0');
            SendMessageW(combo, CB_GETLBTEXT, i, reinterpret_cast<LPARAM>(label.data()));
            SIZE size{}; GetTextExtentPoint32W(dc, label.data(), length, &size);
            textWidth = std::max(textWidth, static_cast<int>(size.cx));
        }
        SelectObject(dc, previous); ReleaseDC(combo, dc);
        // Allow for the arrow/scrollbar, borders and text padding at the current DPI.
        return std::max(px(64), textWidth + GetSystemMetricsForDpi(SM_CXVSCROLL, dpi) + px(16));
    }
    void create(HWND hwnd) {
        window = hwnd; dpi = GetDpiForWindow(hwnd);
        font = CreateFontW(-MulDiv(9, dpi, 72), 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
            OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, DEFAULT_PITCH, L"Microsoft YaHei UI");
        pathControl = add(hwnd, L"EDIT", L"", ES_READONLY | ES_AUTOHSCROLL, 0,0,0,0,0, WS_EX_CLIENTEDGE);
        openButton = add(hwnd, WC_BUTTONW, L"打开…", WS_TABSTOP, 0,0,0,0, OpenId);
        tab = add(hwnd, WC_TABCONTROLW, L"", WS_TABSTOP | WS_CLIPSIBLINGS, 0,0,0,0,TabId);
        for (int i = 0; i < PageCount; ++i) { TCITEMW item{}; item.mask = TCIF_TEXT; item.pszText = const_cast<wchar_t*>(PageNames[i]); TabCtrl_InsertItem(tab, i, &item); }
        sections = add(hwnd,WC_TABCONTROLW,L"",WS_TABSTOP|WS_CLIPSIBLINGS,0,0,0,0,SectionId);
        int position = 0;
        for (auto title : {L"字幕与样式",L"弹幕字体效果",L"弹幕过滤"}) { TCITEMW item{};item.mask=TCIF_TEXT;item.pszText=const_cast<wchar_t*>(title);TabCtrl_InsertItem(sections,position++,&item); }
        pane = add(hwnd, PaneClass, L"", WS_VSCROLL | WS_CLIPSIBLINGS, 0,0,0,0,0,WS_EX_CONTROLPARENT);
        SetWindowLongPtrW(pane, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
        preview = add(hwnd, PreviewClass, L"", WS_CLIPSIBLINGS,0,0,0,0);
        SetWindowLongPtrW(preview, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
        status = add(hwnd, L"STATIC", L"请打开 Bilibili_Config.json。", SS_LEFT,0,0,0,0);
        ok = add(hwnd, WC_BUTTONW, L"确定", BS_DEFPUSHBUTTON | WS_TABSTOP,0,0,0,0,IDOK);
        cancel = add(hwnd, WC_BUTTONW, L"取消", WS_TABSTOP,0,0,0,0,IDCANCEL);
        apply = add(hwnd, WC_BUTTONW, L"应用", WS_TABSTOP,0,0,0,0,ApplyId);
        resetAll = add(hwnd,WC_BUTTONW,L"初始化全部配置",WS_TABSTOP,0,0,0,0,ResetAllId);
        resetPage = add(hwnd,WC_BUTTONW,L"初始化本页",WS_TABSTOP,0,0,0,0,ResetPageId);
        fonts = installedFonts(); initialized.resize(settings().size(),false);
        bindings.resize(settings().size()); layout(); updateDirty();
    }
    bool dirty() const { return document && (initializingAll || initial != draft || std::any_of(initialized.begin(),initialized.end(),[](bool flag){return flag;})); }
    void updateDirty() {
        EnableWindow(apply, dirty()); EnableWindow(ok, document != nullptr);
        EnableWindow(resetPage,document != nullptr);
        SetWindowTextW(window, dirty() ? L"BilibiliPotPlayer 设置 *" : L"BilibiliPotPlayer 设置");
    }
    void load(const std::wstring& filename) {
        auto newDocument = std::make_unique<Document>(readFile(filename));
        if (newDocument->root().kind != Kind::Object) throw Error("配置最外层必须使用 { } 对象。");
        std::vector<std::wstring> values;
        for (const auto& field : settings()) {
            // Refuse ambiguous parent types instead of silently replacing them.
            std::string fieldPath = field.path;
            for (size_t dot = fieldPath.find('.'); dot != std::string::npos; dot = fieldPath.find('.', dot + 1)) {
                auto parent = newDocument->find(fieldPath.substr(0, dot));
                if (parent && parent->kind != Kind::Object) throw Error(fieldPath.substr(0,dot) + " 应为对象。");
            }
            values.push_back(settingText(field, *newDocument));
            if (field.widget == Widget::Rules) validateSetting(field, settingJson(field, values.back()));
        }
        document = std::move(newDocument); draft = initial = std::move(values); path = fullPath(filename);
        initializingAll = false; initialized.assign(settings().size(),false);
        SetWindowTextW(pathControl, path.c_str());
        SetWindowTextW(status, L"已加载配置。修改后点击“应用”或“确定”保存。");
        std::fill(std::begin(scroll), std::end(scroll), 0); layout(); updateDirty();
    }
    void layout() {
        if (!window || !pane) return;
        RECT r{}; GetClientRect(window, &r); int w = r.right, h = r.bottom;
        building = true;
        MoveWindow(pathControl, px(16),px(14),std::max(px(100),w-px(124)),px(27),TRUE);
        MoveWindow(openButton,w-px(96),px(14),px(80),px(27),TRUE);
        MoveWindow(tab,px(16),px(54),std::max(px(200),w-px(32)),std::max(px(100),h-px(136)),TRUE);
        RECT panel{}; GetClientRect(tab, &panel); TabCtrl_AdjustRect(tab, FALSE, &panel);
        MapWindowPoints(tab,window,reinterpret_cast<POINT*>(&panel),2);
        int previewWidth = page == SubtitlesPage && document ? px(285) : 0;
        int innerWidth = std::max(px(200), static_cast<int>(panel.right-panel.left)-px(4));
        int formWidth = innerWidth-(previewWidth?previewWidth+px(12):0), sectionHeight = page==SubtitlesPage?px(31):0;
        ShowWindow(sections,page==SubtitlesPage&&document?SW_SHOW:SW_HIDE);
        if(page==SubtitlesPage) SetWindowPos(sections,HWND_TOP,panel.left+px(10),panel.top+px(5),formWidth-px(16),px(27),SWP_NOACTIVATE);
        // Page surfaces are siblings of the tab; keep them above its themed background.
        SetWindowPos(pane,HWND_TOP,panel.left+px(2),panel.top+px(2)+sectionHeight,formWidth,std::max(px(80),static_cast<int>(panel.bottom-panel.top)-px(4)-sectionHeight),SWP_NOACTIVATE);
        ShowWindow(preview,previewWidth?SW_SHOW:SW_HIDE);
        if (previewWidth) SetWindowPos(preview,HWND_TOP,panel.right-previewWidth-px(5),panel.top+px(14),previewWidth,static_cast<int>(panel.bottom-panel.top)-px(24),SWP_NOACTIVATE);
        MoveWindow(status,px(18),h-px(70),w-px(36),px(23),TRUE);
        MoveWindow(ok,w-px(280),h-px(40),px(80),px(27),TRUE);
        MoveWindow(cancel,w-px(188),h-px(40),px(80),px(27),TRUE);
        MoveWindow(apply,w-px(96),h-px(40),px(80),px(27),TRUE);
        MoveWindow(resetAll,px(18),h-px(40),px(122),px(27),TRUE);
        MoveWindow(resetPage,px(152),h-px(40),px(100),px(27),TRUE);
        building = false; buildPage();
        // Resizing can preserve pixels from the old child positions. Repaint the
        // entire hierarchy after layout, including the footer outside the pane.
        RedrawWindow(window,nullptr,nullptr,RDW_INVALIDATE|RDW_ERASE|RDW_ALLCHILDREN|RDW_UPDATENOW);
    }
    void setScroll(int next) {
        RECT client{}; GetClientRect(pane,&client);
        next = std::clamp(next,0,std::max(0,contentHeight-static_cast<int>(client.bottom)));
        int delta = scroll[scrollIndex()]-next; scroll[scrollIndex()] = next;
        ScrollWindowEx(pane,0,delta,nullptr,nullptr,nullptr,nullptr,SW_SCROLLCHILDREN|SW_INVALIDATE|SW_ERASE);
        SCROLLINFO si{sizeof(si),SIF_POS}; si.nPos=next; SetScrollInfo(pane,SB_VERT,&si,TRUE);
    }
    void buildPage() {
        if (building || !pane) return;
        building=true;
        SendMessageW(pane,WM_SETREDRAW,FALSE,0);
        while (HWND child=GetWindow(pane,GW_CHILD)) DestroyWindow(child);
        chatOff=nullptr;
        bindings.assign(settings().size(),{});
        RECT r{};GetClientRect(pane,&r);int width=r.right;
        int y=px(12), origin=scroll[scrollIndex()];
        auto make=[&](const wchar_t* cls,const wchar_t* title,DWORD style,int x,int top,int w,int h,int id=0,DWORD ex=0){
            return add(pane,cls,title,style,x,top-origin,w,h,id,ex);
        };
        HWND group=nullptr;int groupY=0;std::wstring groupName;
        auto finishGroup=[&](){if(group){MoveWindow(group,px(10),groupY-origin,width-px(20),y-groupY+px(10),TRUE);y+=px(22);}};
        if (!document) make(L"STATIC",L"打开配置文件后，可在这里调整设置。",0,px(22),y,width-px(44),px(40));
        for(size_t i=0;document && i<settings().size();++i){
            const auto& f=settings()[i];if(f.page!=page||(page==SubtitlesPage&&sectionFor(f)!=section))continue;
            if(f.widget==Widget::ChatModePeer)continue;
            if(groupName!=f.group){finishGroup();groupName=f.group;groupY=y;group=make(WC_BUTTONW,f.group,BS_GROUPBOX,px(10),y,width-px(20),px(100));y+=px(26);}
            auto& b=bindings[i];b.y=y;int id=FieldBase+static_cast<int>(i)*4;
            int labelWidth=px(126),controlX=px(26)+labelWidth,controlWidth=std::max(px(80),width-controlX-px(28));
            if(f.widget==Widget::ChatMode){
                chatOff=make(WC_BUTTONW,L"不显示聊天窗口",BS_AUTORADIOBUTTON|WS_GROUP|WS_TABSTOP,px(26),y,width-px(52),px(25),ChatOffId);y+=px(31);
                b.control=make(WC_BUTTONW,L"官方网页聊天窗口",BS_AUTORADIOBUTTON,px(26),y,width-px(52),px(25),id);y+=px(31);
                size_t peer=fieldIndex("live.liveChatUrl.useBilibiliDanmuji");auto& other=bindings[peer];other.y=y;
                other.control=make(WC_BUTTONW,L"自建 Bilibili_Danmuji 服务",BS_AUTORADIOBUTTON,px(26),y,width-px(52),px(25),FieldBase+static_cast<int>(peer)*4);y+=px(31);
                SetWindowSubclass(chatOff,FocusProc,1,reinterpret_cast<DWORD_PTR>(this));SetWindowSubclass(other.control,FocusProc,1,reinterpret_cast<DWORD_PTR>(this));
            }else if(f.widget==Widget::Check){
                b.control=make(WC_BUTTONW,f.label,BS_AUTOCHECKBOX|WS_TABSTOP|BS_MULTILINE,px(26),y,width-px(52),px(25),id);
                Button_SetCheck(b.control,draft[i]==L"true"?BST_CHECKED:BST_UNCHECKED);y+=px(29);
            } else if(f.widget==Widget::Rules){
                const wchar_t* labels[]={L"关键词屏蔽（每行一条）",L"JavaScript 正则屏蔽（每行一条）",L"用户 UID 屏蔽（每行一个）"};
                for(int type=0;type<3;++type){
                    make(L"STATIC",labels[type],0,px(26),y,width-px(52),px(22));y+=px(25);
                    auto value=ruleLines(utf8(draft[i]),type);
                    b.ruleEditors[type]=make(L"EDIT",value.c_str(),WS_TABSTOP|ES_MULTILINE|ES_WANTRETURN|ES_AUTOVSCROLL|WS_VSCROLL,px(26),y,width-px(52),px(110),id+type,WS_EX_CLIENTEDGE);
                    SendMessageW(b.ruleEditors[type],EM_SETLIMITTEXT,65536,0);SetWindowSubclass(b.ruleEditors[type],FocusProc,1,reinterpret_cast<DWORD_PTR>(this));y+=px(125);
                }
                b.control=b.ruleEditors[0];
            } else if(f.widget==Widget::Lines){
                make(L"STATIC",f.label,0,px(26),y,width-px(52),px(22));y+=px(25);
                b.control=make(L"EDIT",draft[i].c_str(),WS_TABSTOP|ES_MULTILINE|ES_WANTRETURN|ES_AUTOVSCROLL|WS_VSCROLL,px(26),y,width-px(52),px(90),id,WS_EX_CLIENTEDGE);
                SendMessageW(b.control,EM_SETLIMITTEXT,65536,0);y+=px(98);
            } else {
                make(L"STATIC",f.label,0,px(26),y+px(4),labelWidth-px(8),px(32));
                if(f.widget==Widget::Choice||f.widget==Widget::Font||f.widget==Widget::FontSize){
                    b.control=make(WC_COMBOBOXW,L"",CBS_DROPDOWNLIST|WS_VSCROLL|WS_TABSTOP,controlX,y,controlWidth,px(220),id);
                    int selected=-1;
                    if(f.widget==Widget::Font){
                        SendMessageW(b.control,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(L"默认字体"));b.options.push_back("\"\"");if(draft[i].empty())selected=0;
                        for(const auto& face:fonts){int n=static_cast<int>(SendMessageW(b.control,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(face.c_str())));b.options.push_back(quote(utf8(face)));if(CompareStringOrdinal(face.c_str(),-1,draft[i].c_str(),-1,TRUE)==CSTR_EQUAL)selected=n;}
                    } else if(f.widget==Widget::FontSize){
                        for(int size:{8,9,10,11,12,14,16,18,20,22,24,26,28,30,32,36,40,44,48,54,60,64,72,80,96,100,120,144,160,180,200}){
                            auto label=std::to_wstring(size);int n=static_cast<int>(SendMessageW(b.control,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(label.c_str())));b.options.push_back(std::to_string(size));if(std::wcstod(draft[i].c_str(),nullptr)==size)selected=n;
                        }
                    } else for(size_t j=0;j<f.choices.size();++j){
                        SendMessageW(b.control,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(f.choices[j].label));
                        b.options.push_back(f.choices[j].json);
                        if(draft[i]==wide(f.choices[j].json))selected=static_cast<int>(j);
                    }
                    if(selected<0){std::wstring custom=(f.widget==Widget::Font?L"当前字体（未安装）：":L"当前自定义值：")+draft[i];SendMessageW(b.control,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(custom.c_str()));b.options.push_back(settingJson(f,draft[i]));selected=static_cast<int>(b.options.size()-1);}
                    SendMessageW(b.control,CB_SETCURSEL,selected,0);
                    SendMessageW(b.control,CB_SETMINVISIBLE,12,0);
                    int fittedWidth=comboContentWidth(b.control);
                    MoveWindow(b.control,controlX,y-origin,std::min(controlWidth,fittedWidth),px(220),TRUE);
                    SendMessageW(b.control,CB_SETDROPPEDWIDTH,fittedWidth,0);
                } else if(f.widget==Widget::Slider){
                    b.control=make(TRACKBAR_CLASSW,L"",WS_TABSTOP|TBS_HORZ|TBS_AUTOTICKS,controlX,y,controlWidth-px(54),px(29),id);
                    SendMessageW(b.control,TBM_SETRANGE,TRUE,MAKELPARAM(static_cast<int>(f.minimum*100),100));SendMessageW(b.control,TBM_SETTICFREQ,10,0);
                    SendMessageW(b.control,TBM_SETPOS,TRUE,static_cast<int>(std::round(std::wcstod(draft[i].c_str(),nullptr)*100)));
                    wchar_t value[40];swprintf_s(value,L"%.1f%%",std::wcstod(draft[i].c_str(),nullptr)*100);
                    b.output=make(L"STATIC",value,SS_RIGHT,controlX+controlWidth-px(52),y+px(4),px(52),px(24));
                } else {
                    int cw=f.widget==Widget::Text?controlWidth:std::min(controlWidth,px(110));
                    b.control=make(L"EDIT",draft[i].c_str(),WS_TABSTOP|ES_AUTOHSCROLL,controlX,y,cw,px(27),id,WS_EX_CLIENTEDGE);
                    SendMessageW(b.control,EM_SETLIMITTEXT,f.widget==Widget::Text?65536:64,0);
                }
                y+=px(35);
            }
            if(*f.hint){std::wstring hint=f.widget==Widget::Font?L"系统可用字体："+std::to_wstring(fonts.size())+L" 种，可滚动选择。":f.hint;make(L"STATIC",hint.c_str(),0,px(26),y,width-px(52),px(35));y+=px(39);}
            SetWindowSubclass(b.control,FocusProc,1,reinterpret_cast<DWORD_PTR>(this));
            y+=px(7);
        }
        finishGroup();contentHeight=y+px(10);
        if(document)syncChat();
        int old=scroll[scrollIndex()];scroll[scrollIndex()]=std::clamp(old,0,std::max(0,contentHeight-static_cast<int>(r.bottom)));
        if(old!=scroll[scrollIndex()])ScrollWindowEx(pane,0,old-scroll[scrollIndex()],nullptr,nullptr,nullptr,nullptr,SW_SCROLLCHILDREN);
        SCROLLINFO si{sizeof(si),SIF_RANGE|SIF_PAGE|SIF_POS};si.nMin=0;si.nMax=std::max(0,contentHeight-1);si.nPage=static_cast<UINT>(r.bottom);si.nPos=scroll[scrollIndex()];SetScrollInfo(pane,SB_VERT,&si,TRUE);
        SendMessageW(pane,WM_SETREDRAW,TRUE,0);RedrawWindow(pane,nullptr,nullptr,RDW_INVALIDATE|RDW_ERASE|RDW_ALLCHILDREN|RDW_UPDATENOW);
        InvalidateRect(preview,nullptr,FALSE);building=false;
    }
    void changed(size_t index) {
        if(building||index>=settings().size())return;
        const auto& f=settings()[index];const auto& b=bindings[index];
        if(!b.control)return;
        if(f.widget==Widget::ChatMode||f.widget==Widget::ChatModePeer){selectChat(f.widget==Widget::ChatMode?1:2);return;}
        if(f.widget==Widget::Check)draft[index]=Button_GetCheck(b.control)==BST_CHECKED?L"true":L"false";
        else if(f.widget==Widget::Choice||f.widget==Widget::Font||f.widget==Widget::FontSize){int n=static_cast<int>(SendMessageW(b.control,CB_GETCURSEL,0,0));if(n>=0&&n<static_cast<int>(b.options.size())){Document value(b.options[n]);draft[index]=f.widget==Widget::Font?wide(value.root().text):wide(b.options[n]);}}
        else if(f.widget==Widget::Slider){int n=static_cast<int>(SendMessageW(b.control,TBM_GETPOS,0,0));wchar_t value[40];swprintf_s(value,L"%.2f",n/100.0);draft[index]=value;swprintf_s(value,L"%d%%",n);SetWindowTextW(b.output,value);}
        else if(f.widget!=Widget::Rules)draft[index]=textOf(b.control);
        updateDirty();SetWindowTextW(status,dirty()?L"设置已修改，尚未保存。":L"设置未改动。");InvalidateRect(preview,nullptr,FALSE);
    }
    void changedRules(size_t index,int type){
        if(building||type<0||type>2)return;
        draft[index]=wide(replaceRuleLines(utf8(draft[index]),type,textOf(bindings[index].ruleEditors[type])));
        updateDirty();SetWindowTextW(status,L"屏蔽规则已修改，尚未保存。");InvalidateRect(preview,nullptr,FALSE);
    }
    void initialize(bool all){
        if(!all&&!document)return;
        Document defaults=defaultConfiguration();
        if(!document){
            if(path.empty())path=defaultPath();
            document=std::make_unique<Document>(defaultConfiguration());
            initial.clear();for(const auto& field:settings())initial.push_back(settingText(field,*document));
            draft=initial;initialized.assign(settings().size(),false);
            SetWindowTextW(pathControl,path.c_str());
        }
        for(size_t i=0;i<settings().size();++i)if(all||settings()[i].page==page){draft[i]=settingText(settings()[i],defaults);initialized[i]=true;}
        if(all)initializingAll=true;
        layout();updateDirty();
        std::wstring notice=all?L"已初始化全部配置。点击“应用”保存；“取消”放弃。":std::wstring(L"已初始化“")+PageNames[page]+L"”整页。点击“应用”保存。";
        SetWindowTextW(status,notice.c_str());
    }
    void command(WPARAM wp,LPARAM lp){
        int id=LOWORD(wp),notification=HIWORD(wp);
        if(id>=FieldBase){size_t index=(id-FieldBase)/4;int action=(id-FieldBase)%4;if(index>=settings().size())return;
            if(settings()[index].widget==Widget::Rules){if(notification==EN_CHANGE)changedRules(index,action);}
            else if(notification==EN_CHANGE||notification==CBN_SELCHANGE||notification==BN_CLICKED)changed(index);
            return;
        }
        if(id==OpenId){open();return;}
        if(id==ChatOffId){selectChat(0);return;}
        if(id==ResetAllId){initialize(true);return;}
        if(id==ResetPageId){initialize(false);return;}
        if(id==ApplyId){save();return;}
        if(id==IDOK){if(save())DestroyWindow(window);return;}
        if(id==IDCANCEL){DestroyWindow(window);return;}
        (void)lp;
    }
    void focusField(size_t index){
        page=settings()[index].page;section=sectionFor(settings()[index]);TabCtrl_SetCurSel(tab,page);TabCtrl_SetCurSel(sections,section);layout();setScroll(bindings[index].y-px(20));SetFocus(bindings[index].control);
    }
    bool save(){
        if(!document)return false;
        if(!dirty())return true;
        size_t checking=0;
        try{
            Document output(document->source());
            for(size_t i=0;i<settings().size();++i){checking=i;auto json=settingJson(settings()[i],draft[i]);validateSetting(settings()[i],json);if(initializingAll||initialized[i]||draft[i]!=initial[i])output.set(settings()[i].path,json);}
            auto enabled=std::find_if(settings().begin(),settings().end(),[](const Setting& f){return std::string(f.path)=="live.liveChatUrl.useBilibiliDanmuji";});
            auto server=std::find_if(settings().begin(),settings().end(),[](const Setting& f){return std::string(f.path)=="live.liveChatUrl.bilibiliDanmujiServer";});
            size_t en=enabled-settings().begin(),sv=server-settings().begin();
            if(draft[en]==L"true"&&draft[sv].empty()){checking=sv;throw Error("启用自建弹幕姬时，请填写服务地址。");}
            checking=settings().size();saveFile(path,output.source());document=std::make_unique<Document>(std::move(output));initial=draft;initializingAll=false;initialized.assign(settings().size(),false);updateDirty();
            SetWindowTextW(status,L"已保存。请重新加载插件或重启 PotPlayer 使设置生效。");return true;
        }catch(const std::exception& e){if(checking<settings().size()){focusField(checking);message(window,utf8(settings()[checking].label)+"\n"+settings()[checking].path+"\n\n"+e.what());}else message(window,e.what());return false;}
    }
    bool resolveDirty(){
        if(!dirty())return true;
        int result=MessageBoxW(window,L"当前设置尚未保存，是否保存？",L"BilibiliPotPlayer 配置",MB_YESNOCANCEL|MB_ICONQUESTION);
        return result==IDYES?save():result==IDNO;
    }
    void open(){
        if(!resolveDirty())return;
        std::wstring buffer(32768,L'\0');OPENFILENAMEW file{sizeof(file)};file.hwndOwner=window;file.lpstrFile=buffer.data();file.nMaxFile=static_cast<DWORD>(buffer.size());
        file.lpstrFilter=L"JSON 配置文件\0*.json;*.jsonc\0所有文件\0*.*\0";file.lpstrTitle=L"打开 Bilibili_Config.json";
        file.Flags=OFN_FILEMUSTEXIST|OFN_PATHMUSTEXIST|OFN_NOCHANGEDIR|OFN_EXPLORER;
        if(GetOpenFileNameW(&file)){buffer.resize(wcslen(buffer.c_str()));try{load(buffer);}catch(const std::exception& e){message(window,e.what());}}
    }
    double number(const char* fieldPath,double fallback) const {for(size_t i=0;i<settings().size();++i)if(std::string(settings()[i].path)==fieldPath){wchar_t* end=nullptr;double result=std::wcstod(draft[i].c_str(),&end);if(end!=draft[i].c_str()&&!*end&&std::isfinite(result))return result;break;}return fallback;}
    std::wstring value(const char* fieldPath) const {for(size_t i=0;i<settings().size();++i)if(std::string(settings()[i].path)==fieldPath)return draft.empty()?L"":draft[i];return L"";}
    ~App(){if(font)DeleteObject(font);}
};

LRESULT CALLBACK PaneProc(HWND hwnd,UINT msg,WPARAM wp,LPARAM lp){
    auto* app=reinterpret_cast<App*>(GetWindowLongPtrW(hwnd,GWLP_USERDATA));
    if(!app)return DefWindowProcW(hwnd,msg,wp,lp);
    try {
    if(msg==WM_COMMAND){app->command(wp,lp);return 0;}
    if(msg==WM_HSCROLL&&lp){int id=GetDlgCtrlID(reinterpret_cast<HWND>(lp));if(id>=FieldBase)app->changed((id-FieldBase)/4);return 0;}
    if(msg==WM_VSCROLL){SCROLLINFO si{sizeof(si),SIF_ALL};GetScrollInfo(hwnd,SB_VERT,&si);int next=si.nPos;switch(LOWORD(wp)){case SB_LINEUP:next-=app->px(35);break;case SB_LINEDOWN:next+=app->px(35);break;case SB_PAGEUP:next-=si.nPage;break;case SB_PAGEDOWN:next+=si.nPage;break;case SB_THUMBTRACK:case SB_THUMBPOSITION:next=si.nTrackPos;break;case SB_TOP:next=0;break;case SB_BOTTOM:next=si.nMax;break;}app->setScroll(next);return 0;}
    if(msg==WM_MOUSEWHEEL){app->setScroll(app->scroll[app->scrollIndex()]-GET_WHEEL_DELTA_WPARAM(wp)*app->px(75)/WHEEL_DELTA);return 0;}
    if(msg==WM_CTLCOLORSTATIC||msg==WM_CTLCOLORBTN){HDC dc=reinterpret_cast<HDC>(wp);SetBkMode(dc,TRANSPARENT);return reinterpret_cast<LRESULT>(GetSysColorBrush(COLOR_WINDOW));}
    } catch(const std::exception& e) {message(app->window,e.what());return 0;}
    return DefWindowProcW(hwnd,msg,wp,lp);
}
LRESULT CALLBACK FocusProc(HWND hwnd,UINT msg,WPARAM wp,LPARAM lp,UINT_PTR id,DWORD_PTR data){
    auto* app=reinterpret_cast<App*>(data);
    if(msg==WM_MOUSEWHEEL){
        int controlId=GetDlgCtrlID(hwnd);
        if(controlId>=FieldBase){
            size_t field=static_cast<size_t>((controlId-FieldBase)/4);
            if(field<settings().size()){
                auto widget=settings()[field].widget;
                bool combo=widget==Widget::Choice||widget==Widget::Font||widget==Widget::FontSize;
                if(widget==Widget::Slider||(combo&&!SendMessageW(hwnd,CB_GETDROPPEDSTATE,0,0)))
                    return SendMessageW(app->pane,WM_MOUSEWHEEL,wp,lp);
            }
        }
    }
    if(msg==WM_SETFOCUS&&!app->building){RECT item{},client{};GetWindowRect(hwnd,&item);MapWindowPoints(nullptr,app->pane,reinterpret_cast<POINT*>(&item),2);GetClientRect(app->pane,&client);if(item.top<0)app->setScroll(app->scroll[app->scrollIndex()]+item.top-app->px(8));else if(item.bottom>client.bottom)app->setScroll(app->scroll[app->scrollIndex()]+item.bottom-client.bottom+app->px(8));}
    if(msg==WM_NCDESTROY)RemoveWindowSubclass(hwnd,FocusProc,id);
    return DefSubclassProc(hwnd,msg,wp,lp);
}
LRESULT CALLBACK PreviewProc(HWND hwnd,UINT msg,WPARAM wp,LPARAM lp){
    auto* app=reinterpret_cast<App*>(GetWindowLongPtrW(hwnd,GWLP_USERDATA));
    if((msg!=WM_PAINT&&msg!=WM_PRINTCLIENT)||!app)return DefWindowProcW(hwnd,msg,wp,lp);
    PAINTSTRUCT paint{};HDC target=msg==WM_PAINT?BeginPaint(hwnd,&paint):reinterpret_cast<HDC>(wp);RECT r{};GetClientRect(hwnd,&r);
    PreviewSettings style;
    style.font=app->value("danmaku.font");style.size=app->number("danmaku.fontSize",32);style.opacity=app->number("danmaku.opacity",.85);style.area=app->number("danmaku.displayArea",.8);
    style.effect=static_cast<int>(app->number("danmaku.fontEffect.type",2));style.shadow=app->number("danmaku.fontEffect.shadowDepth",1);style.outline=app->number("danmaku.fontEffect.outlineWidth",1.5);style.blur=app->number("danmaku.fontEffect.blurRadius",5);
    style.enabled=app->value("danmaku.enable")==L"true";style.subtitle=app->value("subtitle.enable")==L"true";style.bold=app->value("danmaku.bold")==L"true";
    style.blockTop=app->value("danmaku.blockTop")==L"true";style.blockBottom=app->value("danmaku.blockBottom")==L"true";style.blockColor=app->value("danmaku.blockColor")==L"true";
    style.merge=app->value("danmaku.mergeSameDanmaku")==L"true";style.repeated=app->value("danmaku.blockRepeatedUserDanmaku")==L"true";
    style.enlarge=app->value("danmaku.enlargeMergedDanmaku")==L"true";style.shrink=app->value("danmaku.autoShrinkDanmaku")==L"true";
    auto rules=app->value("danmaku.blockRules");style.rules=rules.empty()?"[]":utf8(rules);
    paintPreview(target,r,app->font,app->dpi,style);
    if(msg==WM_PAINT)EndPaint(hwnd,&paint);return 0;
}

LRESULT CALLBACK WindowProc(HWND hwnd,UINT msg,WPARAM wp,LPARAM lp){
    auto* app=reinterpret_cast<App*>(GetWindowLongPtrW(hwnd,GWLP_USERDATA));
    if(msg==WM_NCCREATE){app=static_cast<App*>(reinterpret_cast<CREATESTRUCTW*>(lp)->lpCreateParams);SetWindowLongPtrW(hwnd,GWLP_USERDATA,reinterpret_cast<LONG_PTR>(app));}
    if(!app)return DefWindowProcW(hwnd,msg,wp,lp);
    try{
        if(msg==WM_CREATE){app->create(hwnd);return 0;}
        if(msg==WM_SIZE){if(wp!=SIZE_MINIMIZED)app->layout();return 0;}
        if(msg==WM_GETMINMAXINFO){auto* info=reinterpret_cast<MINMAXINFO*>(lp);info->ptMinTrackSize={app->px(880),app->px(620)};return 0;}
        if(msg==WM_COMMAND){app->command(wp,lp);return 0;}
        if(msg==WM_NOTIFY&&reinterpret_cast<NMHDR*>(lp)->idFrom==TabId&&reinterpret_cast<NMHDR*>(lp)->code==TCN_SELCHANGE){app->page=TabCtrl_GetCurSel(app->tab);app->layout();return 0;}
        if(msg==WM_NOTIFY&&reinterpret_cast<NMHDR*>(lp)->idFrom==SectionId&&reinterpret_cast<NMHDR*>(lp)->code==TCN_SELCHANGE){app->section=TabCtrl_GetCurSel(app->sections);app->layout();return 0;}
        if(msg==WM_DPICHANGED){app->dpi=HIWORD(wp);HFONT previous=app->font;app->font=CreateFontW(-MulDiv(9,app->dpi,72),0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,CLEARTYPE_QUALITY,DEFAULT_PITCH,L"Microsoft YaHei UI");EnumChildWindows(hwnd,[](HWND child,LPARAM value)->BOOL{SendMessageW(child,WM_SETFONT,value,TRUE);return TRUE;},reinterpret_cast<LPARAM>(app->font));RECT* r=reinterpret_cast<RECT*>(lp);SetWindowPos(hwnd,nullptr,r->left,r->top,r->right-r->left,r->bottom-r->top,SWP_NOZORDER|SWP_NOACTIVATE);DeleteObject(previous);app->layout();return 0;}
        if(msg==WM_CLOSE){if(app->resolveDirty())DestroyWindow(hwnd);return 0;}
        if(msg==WM_DESTROY){PostQuitMessage(0);return 0;}
    }catch(const std::exception& e){message(hwnd,e.what());if(msg==WM_CREATE)return -1;return 0;}
    return DefWindowProcW(hwnd,msg,wp,lp);
}

#ifdef BILI_UI_TEST
uint64_t previewFingerprint(const PreviewSettings& style,HFONT font){
    const int width=285,height=500;BITMAPINFO info{};info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);info.bmiHeader.biWidth=width;info.bmiHeader.biHeight=-height;info.bmiHeader.biPlanes=1;info.bmiHeader.biBitCount=32;
    HDC reference=GetDC(nullptr),dc=CreateCompatibleDC(reference);void* bytes=nullptr;HBITMAP bitmap=CreateDIBSection(reference,&info,DIB_RGB_COLORS,&bytes,nullptr,0);HGDIOBJ previous=SelectObject(dc,bitmap);RECT rect{0,0,width,height};paintPreview(dc,rect,font,96,style);GdiFlush();
    auto* pixels=static_cast<unsigned char*>(bytes);uint64_t hash=1469598103934665603ULL;for(int i=0;i<width*height*4;++i)if(i%4!=3){hash^=pixels[i];hash*=1099511628211ULL;}
    SelectObject(dc,previous);DeleteObject(bitmap);DeleteDC(dc);ReleaseDC(nullptr,reference);return hash;
}
void capture(HWND window,const std::wstring& filename){
    RECT rect{};GetWindowRect(window,&rect);int width=rect.right-rect.left,height=rect.bottom-rect.top;
    BITMAPINFO info{};info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);info.bmiHeader.biWidth=width;info.bmiHeader.biHeight=-height;info.bmiHeader.biPlanes=1;info.bmiHeader.biBitCount=32;info.bmiHeader.biCompression=BI_RGB;
    HDC dc=GetDC(window),memory=CreateCompatibleDC(dc);void* pixels=nullptr;HBITMAP bitmap=CreateDIBSection(dc,&info,DIB_RGB_COLORS,&pixels,nullptr,0);HGDIOBJ previous=SelectObject(memory,bitmap);
    SendMessageW(window,WM_PRINT,reinterpret_cast<WPARAM>(memory),PRF_CLIENT|PRF_NONCLIENT|PRF_ERASEBKGND|PRF_CHILDREN);GdiFlush();
    BITMAPFILEHEADER header{};header.bfType=0x4d42;header.bfOffBits=sizeof(header)+sizeof(info.bmiHeader);header.bfSize=header.bfOffBits+width*height*4;
    HANDLE file=CreateFileW(filename.c_str(),GENERIC_WRITE,0,nullptr,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);DWORD written=0;WriteFile(file,&header,sizeof(header),&written,nullptr);WriteFile(file,&info.bmiHeader,sizeof(info.bmiHeader),&written,nullptr);WriteFile(file,pixels,width*height*4,&written,nullptr);CloseHandle(file);
    SelectObject(memory,previous);DeleteObject(bitmap);DeleteDC(memory);ReleaseDC(window,dc);
}
int smokeTest(App& app,const std::wstring& filename){
    auto require=[](bool condition,const char* name){if(!condition)throw Error(name);};
    auto indexOf=[](const char* path){for(size_t i=0;i<settings().size();++i)if(std::string(settings()[i].path)==path)return i;throw Error("field missing");};
    PreviewSettings probe;probe.font=L"微软雅黑 Light";std::set<uint64_t> effects;
    for(int type=0;type<5;++type){probe.effect=type;effects.insert(previewFingerprint(probe,app.font));}
    require(effects.size()==5,"five effects must render differently");
    probe.effect=2;auto unfiltered=previewFingerprint(probe,app.font);probe.blockTop=true;require(previewFingerprint(probe,app.font)!=unfiltered,"top filter preview");probe.blockTop=false;
    probe.blockColor=true;require(previewFingerprint(probe,app.font)!=unfiltered,"color filter preview");probe.blockColor=false;
    probe.shrink=true;require(previewFingerprint(probe,app.font)!=unfiltered,"standalone auto shrink preview");probe.shrink=false;
    probe.merge=true;auto merged=previewFingerprint(probe,app.font);probe.enlarge=true;require(previewFingerprint(probe,app.font)!=merged,"merged enlargement preview");probe.enlarge=false;probe.merge=false;
    probe.rules="[{\"type\":0,\"filter\":\"这一段\"}]";auto keyword=previewFingerprint(probe,app.font);require(keyword!=unfiltered,"keyword preview");
    probe.rules="[{\"type\":2,\"filter\":\"10086\"}]";require(previewFingerprint(probe,app.font)==keyword,"UID preview");
    probe.rules="[{\"type\":1,\"filter\":\".*这一段.*\"}]";require(previewFingerprint(probe,app.font)==keyword,"JavaScript regex preview");
    app.load(filename);require(!app.fonts.empty(),"system font enumeration");
    for(int page=0;page<PageCount;++page){
        app.page=page;TabCtrl_SetCurSel(app.tab,page);
        for(int section=0;section<(page==SubtitlesPage?3:1);++section){
            app.section=section;TabCtrl_SetCurSel(app.sections,section);app.layout();
            require(((GetWindowLongPtrW(app.preview,GWL_STYLE)&WS_VISIBLE)!=0)==(page==SubtitlesPage),"preview appears only on subtitles page");
            if(page==SubtitlesPage){RECT item{};TabCtrl_GetItemRect(app.sections,0,&item);POINT point{item.left+4,item.top+4};MapWindowPoints(app.sections,app.window,&point,1);require(ChildWindowFromPointEx(app.window,point,CWP_SKIPINVISIBLE|CWP_SKIPDISABLED)==app.sections,"section tabs must be above main tab surface");}
            for(size_t i=0;i<settings().size();++i)if(settings()[i].page==page&&(page!=SubtitlesPage||sectionFor(settings()[i])==section))require(IsWindow(app.bindings[i].control)!=FALSE,"UI field missing");
            for(size_t i=0;i<settings().size();++i){
                auto widget=settings()[i].widget;
                if(settings()[i].page!=page||(page==SubtitlesPage&&sectionFor(settings()[i])!=section)||(widget!=Widget::Choice&&widget!=Widget::Font&&widget!=Widget::FontSize))continue;
                HWND combo=app.bindings[i].control;auto before=app.draft;
                LRESULT selected=SendMessageW(combo,CB_GETCURSEL,0,0);
                RECT client{};GetClientRect(app.pane,&client);int maxScroll=std::max(0,app.contentHeight-static_cast<int>(client.bottom));
                for(bool focused:{false,true}){
                    SetFocus(focused?combo:app.tab);app.setScroll(app.px(100));
                    for(int delta:{-WHEEL_DELTA,WHEEL_DELTA}){
                        int expected=std::clamp(app.scroll[app.scrollIndex()]-delta*app.px(75)/WHEEL_DELTA,0,maxScroll);
                        SendMessageW(combo,WM_MOUSEWHEEL,MAKEWPARAM(0,static_cast<WORD>(delta)),0);
                        require(app.scroll[app.scrollIndex()]==expected,"closed combo wheel scrolls page exactly once");
                        require(SendMessageW(combo,CB_GETCURSEL,0,0)==selected&&app.draft==before&&!app.dirty(),"closed combo wheel leaves selection and dirty state unchanged");
                    }
                }
                int key=selected+1<SendMessageW(combo,CB_GETCOUNT,0,0)?VK_DOWN:VK_UP;
                SendMessageW(combo,WM_KEYDOWN,key,0);SendMessageW(combo,WM_KEYUP,key,0);
                require(SendMessageW(combo,CB_GETCURSEL,0,0)!=selected&&app.draft[i]!=before[i],"combo arrow keys still select options");
                SendMessageW(combo,CB_SETCURSEL,selected,0);app.draft=before;app.updateDirty();
            }
            app.setScroll(100000);app.setScroll(0);
        }
    }
    app.page=LivePage;TabCtrl_SetCurSel(app.tab,LivePage);app.layout();
    auto beforeChat=app.draft;size_t web=indexOf("live.liveChatUrl.useWebPage"),custom=indexOf("live.liveChatUrl.useBilibiliDanmuji"),server=indexOf("live.liveChatUrl.bilibiliDanmujiServer");
    for(int mode:{1,2,0}){
        HWND button=mode==0?app.chatOff:app.bindings[mode==1?web:custom].control;
        SendMessageW(button,BM_CLICK,0,0);
        require(app.chatMode()==mode&&app.draft[web]==(mode==1?L"true":L"false")&&app.draft[custom]==(mode==2?L"true":L"false"),"chat mode is mutually exclusive");
        int checked=(Button_GetCheck(app.chatOff)==BST_CHECKED)+(Button_GetCheck(app.bindings[web].control)==BST_CHECKED)+(Button_GetCheck(app.bindings[custom].control)==BST_CHECKED);
        require(checked==1,"exactly one chat radio is checked");
        require((IsWindowEnabled(app.bindings[server].control)!=FALSE)==(mode==2),"chat server enabled only for custom service");
    }
    app.draft[web]=app.draft[custom]=L"true";app.buildPage();
    require(Button_GetCheck(app.bindings[custom].control)==BST_CHECKED&&Button_GetCheck(app.bindings[web].control)==BST_UNCHECKED,"legacy dual-enabled chat resolves to custom service");
    app.draft=beforeChat;app.syncChat();app.updateDirty();
    app.page=SubtitlesPage;app.section=0;TabCtrl_SetCurSel(app.tab,SubtitlesPage);TabCtrl_SetCurSel(app.sections,0);app.layout();
    for(const char* path:{"danmaku.opacity","danmaku.displayArea"}){
        size_t field=indexOf(path);HWND slider=app.bindings[field].control;
        auto before=app.draft;int position=static_cast<int>(SendMessageW(slider,TBM_GETPOS,0,0));
        for(bool focused:{false,true}){
            SetFocus(focused?slider:app.tab);app.setScroll(app.px(100));
            int originalScroll=app.scroll[app.scrollIndex()];
            SendMessageW(slider,WM_MOUSEWHEEL,MAKEWPARAM(0,static_cast<WORD>(-WHEEL_DELTA)),0);
            require(app.scroll[app.scrollIndex()]==originalScroll+app.px(75),"wheel over slider scrolls page exactly once");
            SendMessageW(slider,WM_MOUSEWHEEL,MAKEWPARAM(0,WHEEL_DELTA),0);
            require(app.scroll[app.scrollIndex()]==originalScroll,"reverse wheel over slider scrolls page back");
            require(SendMessageW(slider,TBM_GETPOS,0,0)==position&&app.draft==before&&!app.dirty(),"wheel does not change slider value or dirty state");
        }
        SendMessageW(slider,WM_KEYDOWN,VK_RIGHT,0);SendMessageW(slider,WM_KEYUP,VK_RIGHT,0);
        require(SendMessageW(slider,TBM_GETPOS,0,0)==position+1&&app.draft[field]!=before[field],"slider arrow keys still change value");
        SendMessageW(slider,TBM_SETPOS,TRUE,position);app.draft=before;app.updateDirty();
    }
    app.setScroll(0);
    size_t size=indexOf("danmaku.fontSize"),face=indexOf("danmaku.font"),rules=indexOf("danmaku.blockRules"),heart=indexOf("heartBeat"),effect=indexOf("danmaku.fontEffect.type");
    require((GetWindowLongPtrW(app.bindings[face].control,GWL_STYLE)&3)==CBS_DROPDOWNLIST,"font is selection only");
    COMBOBOXINFO fontList{sizeof(fontList)};GetComboBoxInfo(app.bindings[face].control,&fontList);
    require((GetWindowLongPtrW(fontList.hwndList,GWL_STYLE)&WS_VSCROLL)!=0,"font list exposes vertical scrollbar");
    require(SendMessageW(app.bindings[face].control,CB_GETCOUNT,0,0)>=static_cast<LRESULT>(app.fonts.size()),"font list contains all enumerated families");
    require((GetWindowLongPtrW(app.bindings[size].control,GWL_STYLE)&3)==CBS_DROPDOWNLIST,"size is selection only");
    auto& values=app.bindings[size].options;int selected=static_cast<int>(std::find(values.begin(),values.end(),"36")-values.begin());
    SendMessageW(app.bindings[size].control,CB_SETCURSEL,selected,0);SendMessageW(app.pane,WM_COMMAND,MAKEWPARAM(FieldBase+static_cast<int>(size)*4,CBN_SELCHANGE),reinterpret_cast<LPARAM>(app.bindings[size].control));
    require(app.draft[size]==L"36"&&app.dirty(),"size selection binding");require(app.save()&&!app.dirty(),"UI save failed");
    require(Document(readFile(filename)).find("danmaku.fontSize")->text=="36","UI roundtrip failed");
    app.draft[rules]=L"[{\"type\":0,\"filter\":\"关键词\",\"future\":true}]";app.section=2;TabCtrl_SetCurSel(app.sections,2);app.layout();
    size_t autoSelect=indexOf("danmaku.autoSelectDanmaku");
    require(SendMessageW(app.bindings[autoSelect].control,BM_GETCHECK,0,0)==BST_CHECKED,"automatic selection starts checked");
    SendMessageW(app.bindings[autoSelect].control,BM_CLICK,0,0);
    require(app.draft[autoSelect]==L"false"&&app.dirty(),"automatic selection checkbox binding");
    require(app.save()&&Document(readFile(filename)).find("danmaku.autoSelectDanmaku")->text=="false","automatic selection disabled roundtrip");
    app.load(filename);app.layout();
    require(SendMessageW(app.bindings[autoSelect].control,BM_GETCHECK,0,0)==BST_UNCHECKED,"automatic selection stays unchecked after reload");
    SetWindowTextW(app.bindings[rules].ruleEditors[0],L"关键词\r\n另一个");
    SendMessageW(app.pane,WM_COMMAND,MAKEWPARAM(FieldBase+static_cast<int>(rules)*4,EN_CHANGE),reinterpret_cast<LPARAM>(app.bindings[rules].ruleEditors[0]));
    SetWindowTextW(app.bindings[rules].ruleEditors[1],L".*示例.*");
    SendMessageW(app.pane,WM_COMMAND,MAKEWPARAM(FieldBase+static_cast<int>(rules)*4+1,EN_CHANGE),reinterpret_cast<LPARAM>(app.bindings[rules].ruleEditors[1]));
    SetWindowTextW(app.bindings[rules].ruleEditors[2],L"10086\r\n123456");
    SendMessageW(app.pane,WM_COMMAND,MAKEWPARAM(FieldBase+static_cast<int>(rules)*4+2,EN_CHANGE),reinterpret_cast<LPARAM>(app.bindings[rules].ruleEditors[2]));
    require(ruleLines(utf8(app.draft[rules]),2)==L"10086\r\n123456","typed rule binding");
    require(Document(utf8(app.draft[rules])).root().children.front().member("future")!=nullptr,"rule extra fields preserved");
    require(app.save(),"rule text save");
    std::string commented=app.document->source();
    commented.insert(app.document->find("danmaku.blockRules")->begin+1,"\n// 初始化保留规则示例\n// {\"type\":0,\"filter\":\"关键词\"}\n/* 保留列表内注释 */\n");
    commented="// 保留文件头\n"+commented+"\n// 保留文件尾\n";
    app.document=std::make_unique<Document>(commented);
    app.draft[heart]=L"true";app.initialize(false);
    require(app.draft[autoSelect]==L"true","page initialization restores automatic selection");
    require(app.draft[size]==L"32"&&app.draft[rules]==L"[]"&&app.draft[heart]==L"true","page initialization scope");
    require(app.initialized[rules]&&!app.initialized[heart],"page initialization write scope");
    require(app.save(),"page initialization save");
    for(const char* comment:{"// 初始化保留规则示例","// {\"type\":0,\"filter\":\"关键词\"}","/* 保留列表内注释 */","// 保留文件头","// 保留文件尾"})require(readFile(filename).find(comment)!=std::string::npos,"page initialization retains all comment locations");
    app.document->set("customUnknown","true");app.document->set("bili_jct","\"legacy\"");app.initialize(true);
    require(app.dirty()&&app.initializingAll,"global initialization dirty");require(app.save(),"global initialization save");
    Document reset(readFile(filename));require(reset.find("bili_jct")&&reset.find("customUnknown"),"global initialization preserves unmanaged fields");
    for(const char* comment:{"// 初始化保留规则示例","// {\"type\":0,\"filter\":\"关键词\"}","/* 保留列表内注释 */","// 保留文件头","// 保留文件尾"})require(reset.source().find(comment)!=std::string::npos,"global initialization retains all comment locations");
    for(const auto& f:settings())require(reset.find(f.path)!=nullptr,"global initialization complete");
    saveFile(filename,"{\"unknown\":true}");app.load(filename);app.page=LivePage;TabCtrl_SetCurSel(app.tab,LivePage);app.initialize(false);require(app.save(),"sparse page initialization");
    Document sparse(readFile(filename));require(sparse.find("unknown")&&!sparse.find("subtitle"),"page initialization preserves other pages");require(sparse.find("live.parseM3u8RealUrl.m3u8RedirectDomains")->children.size()==2,"live page initialization domains");
    app.document.reset();app.path=filename+L".new."+std::to_wstring(GetCurrentProcessId())+L".json";app.initialize(true);require(app.save(),"initialize missing configuration");require(Document(readFile(app.path)).find("danmaku.fontSize")!=nullptr,"new file initialized");
    app.page=SubtitlesPage;app.section=1;TabCtrl_SetCurSel(app.tab,SubtitlesPage);TabCtrl_SetCurSel(app.sections,1);app.layout();
    for(int type=0;type<5;++type){app.draft[effect]=std::to_wstring(type);InvalidateRect(app.preview,nullptr,FALSE);capture(app.window,filename+L".effect."+std::to_wstring(type)+L".bmp");}
    app.draft=app.initial;
    for(int dpi:{96,144,192}){RECT next{0,0,MulDiv(1020,dpi,96),MulDiv(740,dpi,96)};SendMessageW(app.window,WM_DPICHANGED,MAKELPARAM(dpi,dpi),reinterpret_cast<LPARAM>(&next));app.setScroll(100000);app.setScroll(0);capture(app.window,filename+L"."+std::to_wstring(dpi)+L".bmp");}
    return 0;
}
#endif
}

int WINAPI wWinMain(HINSTANCE inst,HINSTANCE,LPWSTR,int show){
    instance=inst;INITCOMMONCONTROLSEX controls{sizeof(controls),ICC_TAB_CLASSES|ICC_BAR_CLASSES|ICC_LISTVIEW_CLASSES};InitCommonControlsEx(&controls);
    WNDCLASSEXW cls{sizeof(cls)};cls.hInstance=instance;cls.hCursor=LoadCursorW(nullptr,IDC_ARROW);cls.hIcon=LoadIconW(nullptr,IDI_APPLICATION);cls.hIconSm=cls.hIcon;cls.hbrBackground=GetSysColorBrush(COLOR_BTNFACE);cls.lpfnWndProc=WindowProc;cls.lpszClassName=WindowClass;RegisterClassExW(&cls);
    cls.lpfnWndProc=PaneProc;cls.lpszClassName=PaneClass;cls.hbrBackground=GetSysColorBrush(COLOR_WINDOW);RegisterClassExW(&cls);
    cls.lpfnWndProc=PreviewProc;cls.lpszClassName=PreviewClass;RegisterClassExW(&cls);
    App app;app.dpi=GetDpiForSystem();HWND hwnd=CreateWindowExW(WS_EX_CONTROLPARENT,WindowClass,L"BilibiliPotPlayer 设置",WS_OVERLAPPEDWINDOW|WS_CLIPCHILDREN,CW_USEDEFAULT,CW_USEDEFAULT,app.px(1020),app.px(740),nullptr,nullptr,instance,&app);
    if(!hwnd)return 1;
    int argc=0;LPWSTR* argv=CommandLineToArgvW(GetCommandLineW(),&argc);
    std::wstring file;
    try{file=argc>1?fullPath(argv[1]):defaultPath();}catch(const std::exception& e){message(hwnd,e.what());}
    if(argv)LocalFree(argv);
#ifdef BILI_UI_TEST
    (void)show;
    try{return smokeTest(app,file);}catch(const std::exception& e){
        HANDLE report=CreateFileW((file+L".error.txt").c_str(),GENERIC_WRITE,0,nullptr,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr);
        if(report!=INVALID_HANDLE_VALUE){DWORD written=0;WriteFile(report,e.what(),static_cast<DWORD>(strlen(e.what())),&written,nullptr);CloseHandle(report);}return 2;
    }
#else
    ShowWindow(hwnd,show);UpdateWindow(hwnd);
    try{
        if(!file.empty()){
            app.path=file;SetWindowTextW(app.pathControl,file.c_str());
            if(GetFileAttributesW(file.c_str())==INVALID_FILE_ATTRIBUTES)
                SetWindowTextW(app.status,L"未找到配置文件。点击“初始化全部配置”创建，或点击“打开”选择文件。");
            else app.load(file);
        }
    }catch(const std::exception& e){message(hwnd,e.what());SetWindowTextW(app.status,L"配置无法读取。可打开其他文件，或初始化全部配置后保存。");}
    MSG msg{};while(GetMessageW(&msg,nullptr,0,0)>0){
        if(msg.message==WM_KEYDOWN&&(GetKeyState(VK_CONTROL)&0x8000)){
            if(msg.wParam=='S'){app.save();continue;}if(msg.wParam=='O'){app.open();continue;}
        }
        if(!IsDialogMessageW(hwnd,&msg)){TranslateMessage(&msg);DispatchMessageW(&msg);}
    }
    return static_cast<int>(msg.wParam);
#endif
}
