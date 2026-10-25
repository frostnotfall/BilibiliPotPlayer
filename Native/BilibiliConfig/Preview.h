#pragma once
#include <windows.h>
#include <string>

namespace bili {
struct PreviewSettings {
    std::wstring font;
    double size = 32, opacity = .85, area = .8, shadow = 1, outline = 1.5, blur = 5;
    int effect = 2;
    bool bold = true, enabled = false, subtitle = false, blockTop = false, blockBottom = false,
        blockColor = false, merge = false, repeated = false, enlarge = false, shrink = false;
    std::string rules = "[]";
};
void paintPreview(HDC target, RECT rect, HFONT uiFont, int dpi, const PreviewSettings& style);
}
