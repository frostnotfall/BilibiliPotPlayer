// Test-only oracle: compile upstream similarity source without changing it.
#include <cstdint>
#include <algorithm>
#include "../vendor/pakku/similarity.cpp"
#pragma warning(push)
#pragma warning(disable:4244)
std::unordered_map<ushort, std::pair<uchar, uchar>> pinyin_dict = {
#include "../vendor/pakku/pinyin_dict.txt"
};
#pragma warning(pop)
extern "C" __declspec(dllexport) int PakkuCompare(const ushort* a, const ushort* b) {
    begin_chunk(const_cast<ushort*>(a), 5, 45, true, true);
    check_similar(1, 0);
    config.str_buf = const_cast<ushort*>(b);
    return check_similar(1, 0) != 0;
}
