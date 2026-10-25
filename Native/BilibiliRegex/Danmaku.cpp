// SPDX-License-Identifier: GPL-3.0-only
// pakku-compatible similarity, adapted from xmcp/pakku.js (see vendor/pakku).
// Each handle belongs to one chronological stream. No global mutable caches.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <algorithm>
#include <array>
#include <bitset>
#include <cmath>
#include <cstdint>
#include <deque>
#include <map>
#include <memory>
#include <string>
#include <stdexcept>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace {
using Histogram = std::vector<std::pair<uint32_t, int>>;
struct PinyinEntry { uint16_t character; std::pair<int, int> sound; };
constexpr PinyinEntry pinyinTable[] = {
#include "vendor/pakku/pinyin_dict.txt"
};
constexpr auto makePinyin() {
    std::array<uint16_t, 65536> table{};
    for (auto entry : pinyinTable) table[entry.character] = uint16_t(entry.sound.first | (entry.sound.second << 8));
    return table;
}
constexpr auto pinyin = makePinyin();
bool ending(wchar_t c) { return std::wstring_view(L".。,，/?？!！…~～@^、+=-_♂♀ ").find(c) != std::wstring_view::npos; }
bool cjk(wchar_t c) { return (c >= 0x3000 && c <= 0x9fff) || (c >= 0xff00 && c <= 0xffef); }
std::wstring normalize(const char* text, uint32_t bytes) {
    int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text, bytes, nullptr, 0);
    if (size <= 0) throw std::runtime_error("UTF-8");
    std::wstring s(size, 0);
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text, bytes, s.data(), size);
    size_t end = s.size();
    while (end && ending(s[end - 1])) --end;
    if (end) s.resize(end); // All-punctuation messages remain meaningful.
    std::wstring result;
    result.reserve(s.size());
    for (size_t i = 0; i < s.size(); ++i) {
        wchar_t c = s[i];
        if (c == 0x3000 || c == 0) c = ' ';
        else if (c >= 0xff01 && c <= 0xff5e) c -= 0xfee0;
        if (c == '!') c = L'！'; else if (c == '?') c = L'？';
        else if (c == ';') c = L'；'; else if (c == ':') c = L'：'; else if (c == ',') c = L'，';
        if (c == ' ' && !result.empty()) {
            if (result.back() == ' ') continue;
        }
        result += c;
    }
    for (size_t i = 1; i + 1 < result.size();) {
        if (result[i] == ' ' && cjk(result[i - 1]) && cjk(result[i + 1])) result.erase(i, 1);
        else ++i;
    }
    if (result.size() >= 3 && result[0] == '2' && result.find_first_not_of('3', 1) == std::wstring::npos) result = L"23333";
    if (result.size() >= 3 && result.find_first_not_of('6') == std::wstring::npos) result = L"66666";
    return result;
}
std::string utf8(const std::wstring& s) {
    int n = WideCharToMultiByte(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), nullptr, 0, nullptr, nullptr);
    std::string out(n, 0);
    WideCharToMultiByte(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), out.data(), n, nullptr, nullptr);
    return out;
}
Histogram histogram(std::vector<uint32_t> chars) {
    std::sort(chars.begin(), chars.end());
    Histogram h;
    h.reserve(chars.size());
    for (auto c : chars) {
        if (!h.empty() && h.back().first == c) ++h.back().second;
        else h.emplace_back(c, 1);
    }
    return h;
}
using Signature = std::array<uint64_t, 4>;
unsigned population(uint64_t bits) {
    // Baseline x64 CPUs need not support POPCNT.
    bits -= (bits >> 1) & UINT64_C(0x5555555555555555);
    bits = (bits & UINT64_C(0x3333333333333333)) + ((bits >> 2) & UINT64_C(0x3333333333333333));
    bits = (bits + (bits >> 4)) & UINT64_C(0x0f0f0f0f0f0f0f0f);
    return unsigned((bits * UINT64_C(0x0101010101010101)) >> 56);
}
unsigned signatureDistance(const Signature& a, const Signature& b) {
    unsigned difference = 0;
    for (size_t i = 0; i < a.size(); ++i) difference += population(a[i] ^ b[i]);
    return difference;
}
struct Features {
    Histogram chars, sounds, grams;
    int size = 0, soundSize = 0;
    double gramNorm = 0;
    Signature charSignature{}, soundSignature{}, gramSignature{};
    uint32_t maxGramBucket = 0;
    explicit Features(const std::wstring& s) : size(static_cast<int>(s.size())) {
        std::vector<uint32_t> c, p, g;
        c.reserve(s.size()); p.reserve(s.size() * 2); g.reserve(s.size());
        uint32_t last = s.back() % 1007;
        for (uint16_t ch : s) {
            c.push_back(ch);
            auto sound = pinyin[ch];
            if (!sound) p.push_back(ch >= 'A' && ch <= 'Z' ? ch + 'a' - 'A' : ch);
            else {
                p.push_back(0xe000 + (sound & 255));
                if (sound >> 8) p.push_back(0xe000 + (sound >> 8));
            }
            uint32_t current = ch % 1007;
            g.push_back(last * 1007 + current); last = current;
        }
        soundSize = static_cast<int>(p.size());
        chars = histogram(std::move(c)); sounds = histogram(std::move(p)); grams = histogram(std::move(g));
        for (auto v : chars) { uint32_t bucket = v.first & 255; charSignature[bucket >> 6] |= UINT64_C(1) << (bucket & 63); }
        for (auto v : sounds) { uint32_t bucket = v.first & 255; soundSignature[bucket >> 6] |= UINT64_C(1) << (bucket & 63); }
        std::array<uint32_t, 256> buckets{};
        for (auto v : grams) {
            gramNorm += double(v.second) * v.second;
            // Multiplication mixes the two characters before reducing to 8 bits.
            uint32_t bucket = ((v.first * 2654435761u) >> 24);
            gramSignature[bucket >> 6] |= UINT64_C(1) << (bucket & 63);
            buckets[bucket] += v.second;
            maxGramBucket = std::max(maxGramBucket, buckets[bucket]);
        }
    }
};
int distance(const Histogram& a, const Histogram& b) {
    size_t i = 0, j = 0; int diff = 0;
    while (i < a.size() || j < b.size()) {
        if (j == b.size() || (i < a.size() && a[i].first < b[j].first)) diff += a[i++].second;
        else if (i == a.size() || b[j].first < a[i].first) diff += b[j++].second;
        else { diff += std::abs(a[i++].second - b[j++].second); }
    }
    return diff;
}
bool similar(const Features& a, const Features& b) {
    int sum = a.size + b.size;
    int limit = sum < 10 ? 5 * sum / 10 - 1 : 5;
    bool closeLength = std::abs(a.size - b.size) <= 5;
    bool comparedChars = false;
    int diff = sum;
    // Each differing presence bit accounts for at least one L1 difference.
    // Hash collisions only weaken this lower bound, never reject a match.
    if (closeLength && signatureDistance(a.charSignature, b.charSignature) <= unsigned(limit)) {
        diff = distance(a.chars, b.chars); comparedChars = true;
        if (diff <= limit) return true;
    }
    if (std::abs(a.soundSize - b.soundSize) <= 5 &&
        signatureDistance(a.soundSignature, b.soundSignature) <= unsigned(limit)) {
        int py = distance(a.sounds, b.sounds);
        if (py <= limit) return true;
    }
    unsigned shared = 0;
    for (size_t i = 0; i < a.gramSignature.size(); ++i) shared += population(a.gramSignature[i] & b.gramSignature[i]);
    // Every common bucket contributes at most maxBucketA * maxBucketB.
    // This is an upper bound on the exact dot product, including collisions.
    double upperDot = double(shared) * a.maxGramBucket * b.maxGramBucket;
    if (100 * upperDot * upperDot < 45 * a.gramNorm * b.gramNorm) return false;
    if (closeLength) {
        if (!comparedChars) diff = distance(a.chars, b.chars);
        if (diff >= sum) return false;
    }
    double dot = 0;
    size_t i = 0, j = 0;
    while (i < a.grams.size() && j < b.grams.size()) {
        if (a.grams[i].first < b.grams[j].first) ++i;
        else if (a.grams[i].first > b.grams[j].first) ++j;
        else { dot += double(a.grams[i++].second) * b.grams[j++].second; }
    }
    return a.gramNorm > 0 && b.gramNorm > 0 && 100 * dot * dot >= 45 * a.gramNorm * b.gramNorm;
}
struct Group {
    uint32_t id, time;
    Features features;
    std::map<std::wstring, uint32_t> variants;
    Group(uint32_t id, uint32_t time, const std::wstring& text, Features&& cached) : id(id), time(time), features(std::move(cached)) { variants[text] = 1; }
};
struct LayoutEvent {
    uint32_t start, mode, width, height, x, y;
};
struct Layout {
    uint32_t area, pitch, duration;
    std::vector<LayoutEvent> events;
    using Timeline = std::map<uint32_t, std::vector<uint32_t>>;
    Timeline timeline;
    std::unordered_map<uint64_t,std::pair<uint64_t,uint64_t>> topFull;
    Layout(uint32_t area, uint32_t pitch, uint32_t duration) : area(area), pitch(pitch), duration(duration) {}
    static bool scrolling(uint32_t mode) { return mode == 1 || mode == 6; }
    static bool softPair(uint32_t a, uint32_t b) { return (a == 5 && scrolling(b)) || (b == 5 && scrolling(a)); }
    double left(const LayoutEvent& e, double time) const {
        if (!scrolling(e.mode)) return e.x;
        double travel=(1920.0+e.width)*(time-e.start)/duration;
        return e.mode==6 ? -double(e.width)+travel : 1920.0-travel;
    }
    bool horizontalCollision(const LayoutEvent& a,const LayoutEvent& b) const {
        double begin=std::max(a.start,b.start);
        double end=static_cast<double>(std::min(uint64_t(a.start)+duration,uint64_t(b.start)+duration));
        if(begin>=end)return false;
        double a0=left(a,begin),a1=left(a,end),b0=left(b,begin),b1=left(b,end);
        return !((a0+a.width+2<=b0 && a1+a.width+2<=b1) || (b0+b.width+2<=a0 && b1+b.width+2<=a1));
    }
    using Interval=std::pair<int,int>;
    static void centerFirst(std::vector<uint32_t>& xs,uint32_t width) {
        std::sort(xs.begin(),xs.end(),[width](uint32_t a,uint32_t b){
            int da=std::abs(int(2*a+width)-1920),db=std::abs(int(2*b+width)-1920);
            return da!=db?da<db:a<b;
        });
    }
    uint32_t gap(std::vector<Interval>& occupied,uint32_t height,uint32_t step) const {
        if(height>area)return area+1;
        std::sort(occupied.begin(),occupied.end());
        uint32_t y=0;
        for(auto band:occupied){
            if(band.second<=int(y) || band.first>=int(area))continue;
            if(int64_t(y)+height<=band.first)return y;
            y=uint32_t(band.second);
            y=((y+step-1)/step)*step;
            if(uint64_t(y)+height>area)return area+1;
        }
        return uint64_t(y)+height<=area?y:area+1;
    }
    uintptr_t place(uint32_t start,uint32_t mode,uint32_t width,uint32_t height) {
        if(height>area)return 0;
        LayoutEvent candidate{start,mode,width,height,0,0};
        if(!scrolling(mode)){candidate.width=std::min(width,1920u);candidate.x=(1920-candidate.width)/2;}
        uint64_t key=(uint64_t(candidate.width)<<32)|height;
        if(mode==5){
            auto cached=topFull.find(key);
            if(cached!=topFull.end() && start>=cached->second.first && start<cached->second.second)return 0;
        }
        std::vector<const LayoutEvent*> overlap;
        uint32_t first=start>duration?start-duration:0;
        for(auto it=timeline.lower_bound(first);it!=timeline.end() && uint64_t(it->first)<uint64_t(start)+duration;++it)
            for(auto id:it->second)if(uint64_t(events[id].start)+duration>start){
                // Fixed top and moving comments have independent capacity.
                if(!softPair(mode,events[id].mode))overlap.push_back(&events[id]);
            }
        {
            std::vector<Interval> occupied;occupied.reserve(overlap.size());
            auto findY=[&](){
                occupied.clear();
                for(auto event:overlap){
                    if(!horizontalCollision(candidate,*event))continue;
                    int low=int(event->y),high=int(event->y+event->height);
                    if(mode==4){low=1080-int(event->y+event->height);high=1080-int(event->y);}
                    occupied.emplace_back(low,high);
                }
                return gap(occupied,height,mode==5?1:pitch);
            };
            // Normal rows need no horizontal candidate generation or sorting.
            uint32_t best=findY(),bestX=candidate.x;
            if(mode==5 && best>area){
                std::vector<uint32_t> xs;
                std::bitset<1921> seen;
                seen.set(candidate.x);
                auto addX=[&](int x){if(x>=0 && uint64_t(x)+candidate.width<=1920 && !seen[size_t(x)]){seen.set(size_t(x));xs.push_back(uint32_t(x));}};
                addX(0);addX(int(1920-candidate.width));
                for(auto event:overlap){
                    addX(int(event->x+event->width+2));
                    addX(int(event->x)-int(candidate.width)-2);
                }
                // A nearest legal X is either centered or on a collision
                // boundary. Search only those deduplicated pixels, center out.
                centerFirst(xs,candidate.width);
                // Only fixed comments constrain top capacity. Sort their Y
                // bands once and reuse that order for every candidate X.
                std::sort(overlap.begin(),overlap.end(),[](auto a,auto b){return a->y<b->y;});
                for(auto x:xs){
                    uint32_t y=0;
                    for(auto event:overlap){
                        if(event->y+event->height<=y || x+candidate.width+2<=event->x || event->x+event->width+2<=x)continue;
                        if(uint64_t(y)+height<=event->y)break;
                        y=event->y+event->height;
                        if(uint64_t(y)+height>area)break;
                    }
                    if(uint64_t(y)+height>area)continue;
                    if(y<=area){best=y;bestX=x;break;}
                }
            }
            if(best<=area){
                candidate.x=bestX;
                candidate.y=mode==4?1080-best-height:best;
                uint32_t id=static_cast<uint32_t>(events.size());events.push_back(candidate);timeline[start].push_back(id);
                if(!scrolling(mode))topFull.clear();
                return 1+(mode==5?(uint64_t(candidate.x+candidate.width/2)<<32):0)+best;
            }
        }
        if(mode==5){
            uint64_t until=uint64_t(UINT32_MAX)+1;
            auto departure=timeline.lower_bound(first);
            while(departure!=timeline.end() && uint64_t(departure->first)+duration<=start)++departure;
            if(departure!=timeline.end())until=std::min(until,uint64_t(departure->first)+duration);
            if(uint64_t(start)+duration<=UINT32_MAX){auto arrival=timeline.lower_bound(start+duration);if(arrival!=timeline.end())until=std::min(until,uint64_t(arrival->first)-duration+1);}
            if(topFull.size()>=4096)topFull.clear();topFull[key]={start,until};
        }
        return 0;
    }
    // Capacity decisions are complete before this pass. Refine only overflow
    // top positions, using every accepted moving reservation (including ones
    // placed later by merge priority). A clear rectangle wins over overlap;
    // if none exists, retain the legal top-only placement without dropping it.
    uintptr_t refineTop(uint32_t start,uint32_t centerX,uint32_t y) {
        auto at=timeline.find(start);
        if(at==timeline.end())return UINTPTR_MAX;
        LayoutEvent* current=nullptr;
        for(auto id:at->second){
            auto& event=events[id];
            if(event.mode==5 && event.x+event.width/2==centerX && event.y==y){current=&event;break;}
        }
        if(!current)return UINTPTR_MAX;
        auto encode=[&](){return uintptr_t(1+(uint64_t(current->x+current->width/2)<<32)+current->y);};
        if(current->x==(1920-current->width)/2)return encode();
        // Against fixed top text, a moving comment is exactly its swept
        // horizontal interval over the shared lifetime. Compute it once,
        // instead of four trajectory evaluations for every candidate X.
        // Candidate X is an integer pixel. Store the exact inclusive range of
        // blocked X positions, so equal vertical bands can be unioned once.
        struct Obstacle { uint32_t left,right,low,high; };
        std::vector<Obstacle> obstacles;
        std::vector<uint32_t> xs;
        std::bitset<1921> seen;
        auto addX=[&](int x){if(x>=0 && uint64_t(x)+current->width<=1920 && !seen[size_t(x)]){seen.set(size_t(x));xs.push_back(uint32_t(x));}};
        addX(int((1920-current->width)/2));addX(int(current->x));addX(0);addX(int(1920-current->width));
        uint32_t maxX = 1920-current->width;
        uint32_t first=start>duration?start-duration:0;
        for(auto it=timeline.lower_bound(first);it!=timeline.end() && uint64_t(it->first)<uint64_t(start)+duration;++it)
            for(auto id:it->second){
                const auto& event=events[id];
                if(&event==current || uint64_t(event.start)+duration<=start)continue;
                double begin=std::max(start,event.start);
                double end=static_cast<double>(std::min(uint64_t(start)+duration,uint64_t(event.start)+duration));
                double l0=left(event,begin),l1=left(event,end);
                double low=std::min(l0,l1),high=std::max(l0,l1)+event.width;
                addX(int(std::ceil(high+2)));
                addX(int(std::floor(low-current->width-2)));
                double lower=low-current->width-2.0,upper=high+2.0;
                if(lower>=maxX || upper<=0)continue;
                uint32_t leftBound=lower<0?0:uint32_t(std::floor(lower))+1;
                uint32_t rightBound=upper>maxX?maxX:uint32_t(std::ceil(upper))-1;
                if(leftBound<=rightBound)obstacles.push_back({leftBound,rightBound,event.y,event.y+event.height});
            }
        std::sort(obstacles.begin(),obstacles.end(),[](const auto& a,const auto& b){
            if(a.low!=b.low)return a.low<b.low;
            if(a.high!=b.high)return a.high<b.high;
            return a.left<b.left;
        });
        size_t bands=0;
        for(auto obstacle:obstacles){
            if(bands && obstacles[bands-1].low==obstacle.low && obstacles[bands-1].high==obstacle.high &&
                obstacle.left<=obstacles[bands-1].right+1){
                obstacles[bands-1].right=std::max(obstacles[bands-1].right,obstacle.right);
            }else obstacles[bands++]=obstacle;
        }
        obstacles.resize(bands);
        // All X candidates traverse the same Y ordering. No per-X allocation
        // or interval sorting. Full-width blockers also give an exact lower
        // bound: if they fill the area, no horizontal search can succeed.
        auto findGap=[&](uint32_t x,uint32_t y,bool commonOnly){
            for(const auto& obstacle:obstacles){
                if(obstacle.high<=y)continue;
                if(commonOnly ? (obstacle.left!=0 || obstacle.right!=maxX) :
                    (x<obstacle.left || x>obstacle.right))continue;
                if(uint64_t(y)+current->height<=obstacle.low)return y;
                y=obstacle.high;
                if(uint64_t(y)+current->height>area)return area+1;
            }
            return uint64_t(y)+current->height<=area?y:area+1;
        };
        uint32_t minimum=findGap(0,0,true);
        if(minimum>area)return encode();
        centerFirst(xs,current->width);
        uint32_t best=area+1,bestX=current->x;
        for(auto x:xs){
            uint32_t next=findGap(x,minimum,false);
            // Clear space wins over allowed moving overlap; among clear
            // rectangles choose the one nearest the horizontal center first.
            if(next<=area){best=next;bestX=x;break;}
        }
        if(best<=area){current->x=bestX;current->y=best;}
        return encode();
    }
};
struct Merger {
    uint32_t window;
    std::deque<std::unique_ptr<Group>> active;
    std::unordered_map<std::wstring, Group*> exact;
    std::vector<std::string> chosen;
    std::deque<std::pair<uint64_t, double>> densityQueue;
    double density = 0;
    bool pending = false;
    uint32_t pendingTime = 0;
    double pendingDensity = 0;
    std::unique_ptr<Layout> layout;
    HDC dc = nullptr;
    HFONT font = nullptr;
    HGDIOBJ oldFont = nullptr;
    int metricHeight = 0;
    std::unordered_map<std::string, int> widthCache;
    explicit Merger(uint32_t window) : window(window) {}
    ~Merger() {
        if (dc && oldFont) SelectObject(dc, oldFont);
        if (font) DeleteObject(font);
        if (dc) DeleteDC(dc);
    }
    void finish(Group& group) {
        uint32_t most = 0;
        std::vector<const std::wstring*> candidates;
        for (auto& v : group.variants) {
            exact.erase(v.first);
            if (v.second > most) { most = v.second; candidates.clear(); }
            if (v.second == most) candidates.push_back(&v.first);
        }
        std::stable_sort(candidates.begin(), candidates.end(), [](auto a, auto b) { return a->size() < b->size(); });
        chosen[group.id] = utf8(*candidates[candidates.size() / 2]);
    }
    int feed(const char* text, uint32_t bytes, uint32_t time) {
        while (!active.empty() && uint64_t(active.front()->time) + window < time) {
            finish(*active.front()); active.pop_front();
        }
        auto normalized = normalize(text, bytes);
        auto found = exact.find(normalized);
        if (found != exact.end()) { ++found->second->variants[normalized]; return static_cast<int>(found->second->id); }
        Features f(normalized);
        for (auto& group : active) if (similar(f, group->features)) {
            ++group->variants[normalized]; exact[normalized] = group.get(); return static_cast<int>(group->id);
        }
        uint32_t id = static_cast<uint32_t>(chosen.size());
        auto group = std::make_unique<Group>(id, time, normalized, std::move(f));
        exact[normalized] = group.get(); active.push_back(std::move(group)); chosen.emplace_back();
        return static_cast<int>(id);
    }
};
}
extern "C" {
uintptr_t BiliDanmakuCreate(uint32_t window_ms) { try { return reinterpret_cast<uintptr_t>(new Merger(window_ms)); } catch (...) { return 0; } }
int BiliDanmakuFeed(uintptr_t handle, const char* text, uint32_t bytes, uint32_t time_ms) {
    if (!handle || !text || !bytes || bytes > 1024 * 1024) return -1;
    try { return reinterpret_cast<Merger*>(handle)->feed(text, bytes, time_ms); } catch (...) { return -1; }
}
const char* BiliDanmakuText(uintptr_t handle, uint32_t group) {
    if (!handle) return nullptr;
    try {
        auto& m = *reinterpret_cast<Merger*>(handle);
        if (group >= m.chosen.size()) return nullptr;
        if (m.chosen[group].empty()) for (auto& g : m.active) if (g->id == group) { m.finish(*g); break; }
        return m.chosen[group].c_str(); // Read after the final Feed; valid until Free.
    } catch (...) { return nullptr; }
}
int BiliDanmakuFree(uintptr_t handle) { delete reinterpret_cast<Merger*>(handle); return 0; }
int BiliDanmakuFont(uintptr_t handle, const char* face, uint32_t bytes, uint32_t bold) {
    if (!handle || !face || !bytes || bytes > 1024) return -1;
    try {
        auto& m = *reinterpret_cast<Merger*>(handle);
        int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, face, bytes, nullptr, 0);
        if (n <= 0 || m.dc) return -1;
        std::wstring name(n, 0); MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, face, bytes, name.data(), n);
        m.dc = CreateCompatibleDC(nullptr);
        m.font = CreateFontW(-1000, 0, 0, 0, bold ? FW_BOLD : FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY, DEFAULT_PITCH, name.c_str());
        if (!m.dc || !m.font) return -1;
        m.oldFont = SelectObject(m.dc, m.font);
        TEXTMETRICW metric{};
        if (!GetTextMetricsW(m.dc, &metric)) return -1;
        m.metricHeight = metric.tmHeight;
        return m.metricHeight > 0 ? 0 : -1;
    } catch (...) { return -1; }
}
int BiliDanmakuMeasure(uintptr_t handle, const char* text, uint32_t bytes, uint32_t size) {
    if (!handle || !text || !bytes || bytes > 1024 * 1024 || !size || size > 4095) return -1;
    try {
        auto& m = *reinterpret_cast<Merger*>(handle);
        if (!m.metricHeight) return -1;
        std::string key(text, bytes);
        auto found = m.widthCache.find(key);
        int width;
        if (found != m.widthCache.end()) width = found->second;
        else {
            int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text, bytes, nullptr, 0);
            if (n <= 0) return -1;
            std::wstring wide(n, 0); MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text, bytes, wide.data(), n);
            SIZE extent{};
            if (!GetTextExtentPoint32W(m.dc, wide.data(), n, &extent)) return -1;
            width = extent.cx;
            if (bytes <= 384) {
                if (m.widthCache.size() >= 4096) m.widthCache.clear();
                m.widthCache.emplace(std::move(key), width);
            }
        }
        // ASS fontsize denotes the line's ascender+descender height. GDI's
        // negative font height denotes the em, so normalize by tmHeight.
        return static_cast<int>(std::ceil(double(width) * size / m.metricHeight)) + 2;
    } catch (...) { return -1; }
}
int BiliDanmakuWeight(uintptr_t handle, uint32_t weight, uint32_t count) {
    (void)count; // Compatibility with the former density preference interface.
    if (!handle || weight < 1 || weight > 11) return -1;
    return 0;
}
// packed: size in low 12 bits, weight in bits 12..15, enlarge/shrink bits 16/17.
// Prepare fontsize without selecting or occupying the density window. The
// caller may discard a candidate (e.g. no top space) simply by preparing next.
int BiliDanmakuPrepare(uintptr_t handle, const char* text, uint32_t bytes, uint32_t time, uint32_t packed, uint32_t peers) {
    if (!handle) return -1;
    auto& m = *reinterpret_cast<Merger*>(handle);
    m.pending = false;
    if (!text || !bytes || bytes > 1024 * 1024) return -1;
    try {
        while (!m.densityQueue.empty() && m.densityQueue.front().first < time) {
            m.density -= m.densityQueue.front().second; m.densityQueue.pop_front();
        }
        int base = packed & 4095;
        if (base == 0 || peers == 0) return -1;
        double size = base;
        if ((packed & (1 << 16)) && peers > 5) size = std::ceil(size * std::log(double(peers)) / std::log(5.0));
        if (!(packed & (1 << 17))) {
            m.pendingTime=time;m.pendingDensity=0;m.pending=true;
            return std::clamp(int(std::ceil(size)),1,4095);
        }
        double length = 0;
        for (uint32_t i = 0; i < bytes; ++i) {
            uint8_t c = uint8_t(text[i]);
            if ((c & 0xc0) != 0x80) length += c >= 0x20 && c <= 0x7e ? .5 : 1;
        }
        double dv = std::sqrt(length) * std::pow(std::clamp(size / 25, .7, 2.5), 1.5);
        if (packed & (1 << 17)) {
            double candidateDensity = m.density + dv;
            if (candidateDensity > 75) size /= std::min(std::pow(candidateDensity / 75, .35), 1.732);
            size = std::max(16.0, size);
        }
        int finalSize = std::clamp(int(std::ceil(size)), 1, 4095);
        m.pendingTime = time;
        m.pendingDensity = std::sqrt(length) * std::pow(std::clamp(finalSize / 25.0, .7, 2.5), 1.5);
        m.pending = true;
        return finalSize;
    } catch (...) { return -1; }
}
// Density is exclusively for automatic shrink. Never delete for density.
int BiliDanmakuCommit(uintptr_t handle) {
    if (!handle) return -1;
    auto& m = *reinterpret_cast<Merger*>(handle);
    if (!m.pending) return -1;
    m.pending = false;
    if(m.pendingDensity==0)return 1;
    try {
        m.densityQueue.emplace_back(uint64_t(m.pendingTime) + 5000, m.pendingDensity);
        m.density += m.pendingDensity;
        return 1;
    } catch (...) { return -1; }
}
int BiliDanmakuLayoutInit(uintptr_t handle, uint32_t area, uint32_t pitch, uint32_t duration) {
    if(!handle || !pitch || pitch>4096 || area<pitch || area>1080 || !duration)return -1;
    try{reinterpret_cast<Merger*>(handle)->layout=std::make_unique<Layout>(area,pitch,duration);return 0;}catch(...){return -1;}
}
// Caller places merged groups first, then unmerged groups, retaining original
// timestamps. The timeline index checks both earlier and later reservations.
// 0=no space; UINTPTR_MAX=error; otherwise 1+(centerX<<32)+topY.
uintptr_t BiliDanmakuPlace(uintptr_t handle,uint32_t start,uint32_t mode,uint32_t width,uint32_t height){
    if(!handle || !width || !height || (mode!=1&&mode!=4&&mode!=5&&mode!=6))return UINTPTR_MAX;
    try{auto& m=*reinterpret_cast<Merger*>(handle);return m.layout?m.layout->place(start,mode,width,height):UINTPTR_MAX;}catch(...){return UINTPTR_MAX;}
}
uintptr_t BiliDanmakuRefineTop(uintptr_t handle,uint32_t start,uint32_t centerX,uint32_t y){
    if(!handle)return UINTPTR_MAX;
    try{auto& m=*reinterpret_cast<Merger*>(handle);return m.layout?m.layout->refineTop(start,centerX,y):UINTPTR_MAX;}catch(...){return UINTPTR_MAX;}
}
// Retained for clients of the initial combined interface.
int BiliDanmakuSelect(uintptr_t handle, const char* text, uint32_t bytes, uint32_t time, uint32_t packed, uint32_t peers) {
    int size = BiliDanmakuPrepare(handle, text, bytes, time, packed, peers);
    if (size < 0) return size;
    int selected = BiliDanmakuCommit(handle);
    return selected > 0 ? size : selected;
}
}
