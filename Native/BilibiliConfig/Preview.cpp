#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include "Preview.h"
#include "Settings.h"
#include "../BilibiliRegex/BilibiliRegex.h"
#include <algorithm>
#include <cmath>
#include <vector>

namespace bili {
namespace {
void fill(HDC dc,RECT rect,COLORREF color){HBRUSH brush=CreateSolidBrush(color);FillRect(dc,&rect,brush);DeleteObject(brush);}
void mountain(HDC dc,const POINT* points,int count,COLORREF color){HBRUSH brush=CreateSolidBrush(color);HGDIOBJ oldBrush=SelectObject(dc,brush),oldPen=SelectObject(dc,GetStockObject(NULL_PEN));Polygon(dc,points,count);SelectObject(dc,oldPen);SelectObject(dc,oldBrush);DeleteObject(brush);}

// The preview can reuse the same optional regexp engine as the plugin. The
// executable remains usable by itself; no DLL is loaded for keyword/UID rules.
class RegexPreview {
    HMODULE module = nullptr;
    decltype(&BiliRegexCompileRule) compile = nullptr;
    decltype(&BiliRegexTest) test = nullptr;
    decltype(&BiliRegexFree) release = nullptr;
    std::string cached;
    std::vector<uintptr_t> handles;
    bool attempted = false;
    void clear(){if(release)for(auto h:handles)release(h);handles.clear();}
public:
    bool incomplete = false;
    ~RegexPreview(){clear();if(module)FreeLibrary(module);}
    void prepare(const std::string& rules){
        if(rules==cached)return;
        clear();cached=rules;incomplete=false;
        Document list(rules);
        size_t count=0;
        for(const auto& rule:list.root().children){
            auto type=rule.member("type"),filter=rule.member("filter");
            if(!type||!filter||type->text!="1")continue;
            if(++count>16){incomplete=true;continue;}
            if(!attempted){
                attempted=true;
                std::wstring path(32768,L'\0');path.resize(GetModuleFileNameW(nullptr,path.data(),static_cast<DWORD>(path.size())));path.resize(path.find_last_of(L"\\/")+1);
#ifdef BILI_UI_TEST
                path+=L"..\\..\\..\\..\\Extension\\Lib\\BilibiliRegex.dll";
#else
                path+=L"..\\..\\Lib\\BilibiliRegex.dll";
#endif
                module=LoadLibraryExW(path.c_str(),nullptr,LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR|LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
                if(module){compile=reinterpret_cast<decltype(compile)>(GetProcAddress(module,"BiliRegexCompileRule"));test=reinterpret_cast<decltype(test)>(GetProcAddress(module,"BiliRegexTest"));release=reinterpret_cast<decltype(release)>(GetProcAddress(module,"BiliRegexFree"));}
            }
            if(!compile||!test||!release){incomplete=true;continue;}
            uintptr_t handle=compile(filter->text.data(),static_cast<uint32_t>(filter->text.size()),10);
            if(handle)handles.push_back(handle);else incomplete=true;
        }
    }
    bool matches(const std::string& text){
        if(!test)return false;
        for(auto handle:handles){int result=test(handle,text.data(),static_cast<uint32_t>(text.size()),10);if(result==1)return true;if(result<0)incomplete=true;}
        return false;
    }
};

void blurMask(std::vector<unsigned char>& mask,int width,int height,int radius){
    if(radius<1)return;
    std::vector<unsigned char> temp(mask.size());
    for(int pass=0;pass<2;++pass){
        for(int y=0;y<height;++y){
            int sum=0;for(int x=0;x<=radius&&x<width;++x)sum+=mask[y*width+x];
            for(int x=0;x<width;++x){temp[y*width+x]=static_cast<unsigned char>(sum/(radius*2+1));if(x-radius>=0)sum-=mask[y*width+x-radius];if(x+radius+1<width)sum+=mask[y*width+x+radius+1];}
        }
        for(int x=0;x<width;++x){
            int sum=0;for(int y=0;y<=radius&&y<height;++y)sum+=temp[y*width+x];
            for(int y=0;y<height;++y){mask[y*width+x]=static_cast<unsigned char>(sum/(radius*2+1));if(y-radius>=0)sum-=temp[(y-radius)*width+x];if(y+radius+1<height)sum+=temp[(y+radius+1)*width+x];}
        }
    }
}
void heavyInk(HDC target,const std::wstring& text,int x,int y,int radius){
    SIZE extent{};GetTextExtentPoint32W(target,text.c_str(),static_cast<int>(text.size()),&extent);
    int pad=radius*3+2,width=extent.cx+pad*2,height=extent.cy+pad*2;
    if(width<=0||height<=0)return;
    BITMAPINFO info{};info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);info.bmiHeader.biWidth=width;info.bmiHeader.biHeight=-height;info.bmiHeader.biPlanes=1;info.bmiHeader.biBitCount=32;
    HDC dc=CreateCompatibleDC(target);void* bits=nullptr;HBITMAP bitmap=CreateDIBSection(target,&info,DIB_RGB_COLORS,&bits,nullptr,0);HGDIOBJ previous=SelectObject(dc,bitmap),oldFont=SelectObject(dc,GetCurrentObject(target,OBJ_FONT));
    RECT rect{0,0,width,height};fill(dc,rect,RGB(0,0,0));SetBkMode(dc,TRANSPARENT);SetTextColor(dc,RGB(255,255,255));TextOutW(dc,pad,pad,text.c_str(),static_cast<int>(text.size()));GdiFlush();
    auto* pixels=static_cast<unsigned char*>(bits);std::vector<unsigned char> mask(static_cast<size_t>(width)*height);
    for(size_t i=0;i<mask.size();++i)mask[i]=std::max({pixels[i*4],pixels[i*4+1],pixels[i*4+2]});
    blurMask(mask,width,height,radius);
    for(size_t i=0;i<mask.size();++i){pixels[i*4]=pixels[i*4+1]=pixels[i*4+2]=0;pixels[i*4+3]=mask[i];}
    BLENDFUNCTION blend{AC_SRC_OVER,0,255,AC_SRC_ALPHA};AlphaBlend(target,x-pad,y-pad,width,height,dc,0,0,width,height,blend);
    SelectObject(dc,oldFont);SelectObject(dc,previous);DeleteObject(bitmap);DeleteDC(dc);
}
void effectText(HDC dc,const std::wstring& text,int x,int y,int effect,const PreviewSettings& style,int dpi,COLORREF color){
    auto px=[&](double n){return static_cast<int>(std::round(n*dpi/96));};
    if(effect>=3)heavyInk(dc,text,x,y,std::clamp(px(style.blur*.65),0,32));
    if(effect==1){int offset=px(style.shadow*.65);SetTextColor(dc,RGB(0,0,0));TextOutW(dc,x+offset,y+offset,text.c_str(),static_cast<int>(text.size()));}
    if((effect==2||effect==4)&&style.outline>0){
        BeginPath(dc);TextOutW(dc,x,y,text.c_str(),static_cast<int>(text.size()));EndPath(dc);
        LOGBRUSH black{BS_SOLID,RGB(0,0,0),0};HPEN pen=ExtCreatePen(PS_GEOMETRIC|PS_SOLID|PS_JOIN_ROUND|PS_ENDCAP_ROUND,std::max(1,px(style.outline*1.3)),&black,0,nullptr);HBRUSH brush=CreateSolidBrush(color);
        HGDIOBJ oldPen=SelectObject(dc,pen),oldBrush=SelectObject(dc,brush);StrokeAndFillPath(dc);SelectObject(dc,oldPen);SelectObject(dc,oldBrush);DeleteObject(pen);DeleteObject(brush);
        SetTextColor(dc,color);TextOutW(dc,x,y,text.c_str(),static_cast<int>(text.size()));
    }else{SetTextColor(dc,color);TextOutW(dc,x,y,text.c_str(),static_cast<int>(text.size()));}
}
}
void paintPreview(HDC target,RECT r,HFONT uiFont,int dpi,const PreviewSettings& style){
    auto px=[&](int n){return MulDiv(n,dpi,96);};
    HDC dc=CreateCompatibleDC(target);HBITMAP bitmap=CreateCompatibleBitmap(target,std::max(1,static_cast<int>(r.right)),std::max(1,static_cast<int>(r.bottom)));HGDIOBJ oldBitmap=SelectObject(dc,bitmap);
    FillRect(dc,&r,GetSysColorBrush(COLOR_WINDOW));SetBkMode(dc,TRANSPARENT);SetTextColor(dc,GetSysColor(COLOR_WINDOWTEXT));HGDIOBJ oldFont=SelectObject(dc,uiFont);
    RECT title{0,0,r.right,px(25)};DrawTextW(dc,L"弹幕效果示例",-1,&title,DT_LEFT|DT_SINGLELINE);
    RECT scene{0,px(29),r.right,px(29)+r.right*11/16};fill(dc,scene,RGB(209,223,237));
    int w=r.right,h=scene.bottom-scene.top,top=scene.top;
    POINT farPoints[]={{0,top+h},{0,top+h*7/10},{w*4/10,top+h*2/10},{w*7/10,top+h*7/10},{w*9/10,top+h*4/10},{w,top+h*7/10},{w,top+h}};mountain(dc,farPoints,7,RGB(152,179,203));
    POINT nearPoints[]={{0,top+h},{0,top+h*9/10},{w*3/10,top+h/2},{w*6/10,top+h*9/10},{w*8/10,top+h*6/10},{w,top+h*9/10},{w,top+h}};mountain(dc,nearPoints,7,RGB(97,133,165));
    std::wstring face=style.font.empty()?L"微软雅黑 Light":style.font;
    HFONT font=CreateFontW(-px(static_cast<int>(std::clamp(style.size*.65,8.0,65.0))),0,0,0,style.bold?FW_BOLD:FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,ANTIALIASED_QUALITY,DEFAULT_PITCH,face.c_str());
    HDC overlay=CreateCompatibleDC(dc);HBITMAP layer=CreateCompatibleBitmap(dc,w,h);HGDIOBJ oldLayer=SelectObject(overlay,layer),oldOverlayFont=SelectObject(overlay,font);BitBlt(overlay,0,0,w,h,dc,0,top,SRCCOPY);SetBkMode(overlay,TRANSPARENT);
    int area=static_cast<int>(h*std::clamp(style.area,.0,1.0));IntersectClipRect(overlay,0,0,w,area);
    Document rules(style.rules);static RegexPreview regex;regex.prepare(style.rules);
    auto blocked=[&](const std::wstring& text,const char* uid){
        std::string encoded=utf8(text);
        for(const auto& rule:rules.root().children){auto type=rule.member("type"),filter=rule.member("filter");if(!type||!filter)continue;if(type->text=="0"&&encoded.find(filter->text)!=std::string::npos)return true;if(type->text=="2"&&filter->text==uid)return true;}
        return regex.matches(encoded);
    };
    auto sample=[&](const std::wstring& text,const char* uid,int x,int y,COLORREF color=RGB(255,255,255)){if(!blocked(text,uid))effectText(overlay,text,x,y,style.effect,style,dpi,color);};
    int line=std::max(px(17),static_cast<int>(std::clamp(style.size*.65,8.0,65.0))*dpi/96+px(5));
    if(!style.blockTop)sample(L"顶部固定弹幕","10001",w/4,px(4));
    sample(L"这一段拍得真好","10086",w/16,line+px(4));
    if(!style.blockColor)sample(L"彩色弹幕示例","10002",w/3,line*2+px(4),RGB(255,219,88));
    if(style.merge)sample(style.repeated?L"重复内容(2)":L"重复内容(3)","10003",w/6,line*3+px(4));
    else{sample(L"重复内容","10003",w/6,line*3+px(4));if(!style.repeated)sample(L"重复内容","10003",w/4,line*4+px(4));}
    if(!style.blockBottom)sample(L"底部固定弹幕","10004",w/4,std::max(0,area-line));
    BLENDFUNCTION blend{AC_SRC_OVER,0,static_cast<BYTE>(255*std::clamp(style.opacity,.0,1.0)),0};AlphaBlend(dc,0,top,w,h,overlay,0,0,w,h,blend);
    SelectObject(overlay,oldOverlayFont);SelectObject(overlay,oldLayer);DeleteObject(layer);DeleteDC(overlay);DeleteObject(font);
    if(style.subtitle){RECT subtitle{0,scene.bottom-px(22),w,scene.bottom};SetTextColor(dc,RGB(20,39,59));DrawTextW(dc,L"沿着山路，去看看远方。",-1,&subtitle,DT_CENTER|DT_SINGLELINE);}
    int next=scene.bottom+px(9);RECT status{0,next,w,next+px(36)};SetTextColor(dc,GetSysColor(COLOR_GRAYTEXT));DrawTextW(dc,style.enabled?L"已启用弹幕 · 示例随设置更新":L"弹幕未启用 · 仍可预览样式",-1,&status,DT_WORDBREAK);next+=px(30);
    RECT heading{0,next,w,next+px(23)};SetTextColor(dc,GetSysColor(COLOR_WINDOWTEXT));DrawTextW(dc,L"字体效果对照",-1,&heading,DT_SINGLELINE);next+=px(26);
    HFONT exampleFont=CreateFontW(-px(17),0,0,0,style.bold?FW_BOLD:FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,ANTIALIASED_QUALITY,DEFAULT_PITCH,face.c_str());
    const wchar_t* labels[]={L"无特效",L"阴影",L"描边",L"重墨",L"描边 + 重墨"};
    for(int effect=0;effect<5;++effect){
        RECT row{0,next,w,next+px(28)};fill(dc,row,RGB(155,179,201));SelectObject(dc,uiFont);SetTextColor(dc,RGB(20,35,50));RECT label{px(6),next+px(4),px(104),next+px(26)};std::wstring name=labels[effect];if(effect==style.effect)name+=L" ✓";DrawTextW(dc,name.c_str(),-1,&label,DT_SINGLELINE);SelectObject(dc,exampleFont);int saved=SaveDC(dc);IntersectClipRect(dc,px(107),next,w,next+px(28));effectText(dc,L"弹幕示例",px(114),next+px(3),effect,style,dpi,RGB(255,255,255));RestoreDC(dc,saved);next+=px(31);
    }
    SelectObject(dc,uiFont);DeleteObject(exampleFont);SetTextColor(dc,GetSysColor(COLOR_GRAYTEXT));
    RECT note{0,next+px(5),w,r.bottom};std::wstring notes=L"示例 UID：10086；关键词：这一段\n字体效果由 GDI 示意，实播以 ASS 为准。";if(regex.incomplete)notes+=L"\n正则预览不可用或部分规则无效。";DrawTextW(dc,notes.c_str(),-1,&note,DT_WORDBREAK);
    SelectObject(dc,oldFont);BitBlt(target,0,0,r.right,r.bottom,dc,0,0,SRCCOPY);SelectObject(dc,oldBitmap);DeleteObject(bitmap);DeleteDC(dc);
}
}
