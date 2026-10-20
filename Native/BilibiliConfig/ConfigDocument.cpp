#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include "ConfigDocument.h"
#include <algorithm>
#include <cstdio>
#include <memory>

namespace bili {
namespace {
constexpr size_t MaxBytes = 4 * 1024 * 1024;
struct Handle {
    HANDLE h = INVALID_HANDLE_VALUE;
    explicit Handle(HANDLE handle) : h(handle) {}
    ~Handle() { if (h != INVALID_HANDLE_VALUE) CloseHandle(h); }
    Handle(const Handle&) = delete;
    Handle& operator=(const Handle&) = delete;
};
std::string systemError(const char* action) {
    DWORD code = GetLastError();
    wchar_t* buffer = nullptr;
    FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
        FORMAT_MESSAGE_IGNORE_INSERTS, nullptr, code, 0,
        reinterpret_cast<LPWSTR>(&buffer), 0, nullptr);
    std::string result = action;
    result += "（Windows 错误 " + std::to_string(code) + "）";
    if (buffer) { result += "\n" + utf8(buffer); LocalFree(buffer); }
    return result;
}
std::string readHandle(HANDLE h) {
    LARGE_INTEGER size{};
    if (!GetFileSizeEx(h, &size)) throw Error(systemError("无法读取文件大小"));
    if (size.QuadPart < 0 || size.QuadPart > MaxBytes) throw Error("配置文件不能大于 4 MB。");
    std::string bytes(static_cast<size_t>(size.QuadPart), '\0');
    size_t total = 0;
    while (total < bytes.size()) {
        DWORD count = 0;
        if (!ReadFile(h, bytes.data() + total, static_cast<DWORD>(bytes.size() - total), &count, nullptr))
            throw Error(systemError("读取配置文件失败"));
        if (!count) throw Error("读取配置文件时内容发生变化，请重新打开。");
        total += count;
    }
    return bytes;
}
class Parser {
public:
    explicit Parser(const std::string& text) : s(text) {}
    Node run() {
        if (s.size() > MaxBytes) throw Error("配置文件不能大于 4 MB。");
        wide(s); // Reject invalid UTF-8 before interpreting any byte spans.
        if (s.compare(0, 3, "\xEF\xBB\xBF") == 0) pos = 3;
        Node result = value(0);
        skip();
        if (pos != s.size()) fail("配置末尾存在多余内容");
        return result;
    }
private:
    const std::string& s;
    size_t pos = 0;
    [[noreturn]] void fail(const char* reason) const {
        size_t line = 1, column = 1;
        for (size_t i = 0; i < pos && i < s.size(); ++i) {
            if (s[i] == '\n') { ++line; column = 1; }
            else if ((static_cast<unsigned char>(s[i]) & 0xC0) != 0x80) ++column;
        }
        throw Error("第 " + std::to_string(line) + " 行，第 " + std::to_string(column) + " 列：" + reason);
    }
    void skip() {
        for (;;) {
            while (pos < s.size() && (s[pos] == ' ' || s[pos] == '\r' || s[pos] == '\n' || s[pos] == '\t')) ++pos;
            if (s.compare(pos, 2, "//") == 0) {
                while (pos < s.size() && s[pos] != '\n') ++pos;
            } else if (s.compare(pos, 2, "/*") == 0) {
                size_t end = s.find("*/", pos + 2);
                if (end == std::string::npos) fail("块注释没有结束");
                pos = end + 2;
            } else break;
        }
    }
    unsigned hex4() {
        unsigned result = 0;
        for (int i = 0; i < 4; ++i) {
            if (pos == s.size()) fail("Unicode 转义不完整");
            unsigned char c = s[pos++];
            unsigned n = c >= '0' && c <= '9' ? c - '0' : c >= 'a' && c <= 'f' ? c - 'a' + 10 : c >= 'A' && c <= 'F' ? c - 'A' + 10 : 16;
            if (n > 15) fail("Unicode 转义包含非十六进制字符");
            result = result * 16 + n;
        }
        return result;
    }
    static void appendCodepoint(std::string& out, unsigned c) {
        if (c < 0x80) out += static_cast<char>(c);
        else if (c < 0x800) { out += static_cast<char>(0xC0 | (c >> 6)); out += static_cast<char>(0x80 | (c & 63)); }
        else if (c < 0x10000) { out += static_cast<char>(0xE0 | (c >> 12)); out += static_cast<char>(0x80 | ((c >> 6) & 63)); out += static_cast<char>(0x80 | (c & 63)); }
        else { out += static_cast<char>(0xF0 | (c >> 18)); out += static_cast<char>(0x80 | ((c >> 12) & 63)); out += static_cast<char>(0x80 | ((c >> 6) & 63)); out += static_cast<char>(0x80 | (c & 63)); }
    }
    std::string string() {
        if (pos == s.size() || s[pos++] != '"') fail("此处应为双引号字符串");
        std::string result;
        while (pos < s.size()) {
            unsigned char c = s[pos++];
            if (c == '"') return result;
            if (c < 0x20) fail("字符串中不能直接包含换行或控制字符");
            if (c != '\\') { result += static_cast<char>(c); continue; }
            if (pos == s.size()) fail("字符串转义不完整");
            switch (s[pos++]) {
            case '"': result += '"'; break;
            case '\\': result += '\\'; break;
            case '/': result += '/'; break;
            case 'b': result += '\b'; break;
            case 'f': result += '\f'; break;
            case 'n': result += '\n'; break;
            case 'r': result += '\r'; break;
            case 't': result += '\t'; break;
            case 'u': {
                unsigned code = hex4();
                if (code >= 0xD800 && code <= 0xDBFF) {
                    if (s.compare(pos, 2, "\\u") != 0) fail("Unicode 高代理项缺少低代理项");
                    pos += 2;
                    unsigned low = hex4();
                    if (low < 0xDC00 || low > 0xDFFF) fail("Unicode 代理项无效");
                    code = 0x10000 + ((code - 0xD800) << 10) + low - 0xDC00;
                } else if (code >= 0xDC00 && code <= 0xDFFF) fail("Unicode 低代理项缺少高代理项");
                appendCodepoint(result, code); break;
            }
            default: fail("字符串转义无效");
            }
        }
        fail("字符串没有结束");
    }
    bool digit() const { return pos < s.size() && s[pos] >= '0' && s[pos] <= '9'; }
    Node value(int depth) {
        if (depth > 64) fail("嵌套层数超过 64");
        skip();
        if (pos == s.size()) fail("此处缺少配置值");
        Node n; n.begin = pos;
        char c = s[pos];
        if (c == '{' || c == '[') {
            n.kind = c == '{' ? Kind::Object : Kind::Array;
            char closing = c == '{' ? '}' : ']';
            ++pos; skip();
            if (pos < s.size() && s[pos] == closing) { n.close = pos++; n.end = pos; return n; }
            for (;;) {
                if (n.kind == Kind::Object) {
                    skip(); auto key = string();
                    if (std::find(n.keys.begin(), n.keys.end(), key) != n.keys.end()) fail("存在重复的配置项名称");
                    n.keys.push_back(std::move(key)); skip();
                    if (pos == s.size() || s[pos++] != ':') fail("配置项名称后缺少冒号");
                }
                n.children.push_back(value(depth + 1)); skip();
                if (pos < s.size() && s[pos] == closing) { n.close = pos++; break; }
                if (pos == s.size() || s[pos++] != ',') fail("配置项之间缺少逗号或结束括号");
            }
        } else if (c == '"') { n.kind = Kind::String; n.text = string(); }
        else if (c == '-' || digit()) {
            n.kind = Kind::Number;
            if (c == '-') ++pos;
            if (!digit()) fail("数字格式无效");
            if (s[pos] == '0') ++pos;
            else while (digit()) ++pos;
            if (pos < s.size() && s[pos] == '.') {
                ++pos; if (!digit()) fail("小数点后缺少数字"); while (digit()) ++pos;
            }
            if (pos < s.size() && (s[pos] == 'e' || s[pos] == 'E')) {
                ++pos;
                if (pos < s.size() && (s[pos] == '+' || s[pos] == '-')) ++pos;
                if (!digit()) fail("指数后缺少数字"); while (digit()) ++pos;
            }
            n.text = s.substr(n.begin, pos - n.begin);
        } else if (s.compare(pos, 4, "true") == 0) { n.kind = Kind::Bool; n.text = "true"; pos += 4; }
        else if (s.compare(pos, 5, "false") == 0) { n.kind = Kind::Bool; n.text = "false"; pos += 5; }
        else if (s.compare(pos, 4, "null") == 0) { n.kind = Kind::Null; pos += 4; }
        else fail("无法识别此处的配置值");
        n.end = pos;
        return n;
    }
};
bool sameValue(const Node& left, const Node& right) {
    if (left.kind != right.kind || left.text != right.text || left.keys != right.keys || left.children.size() != right.children.size()) return false;
    for (size_t i = 0; i < left.children.size(); ++i) if (!sameValue(left.children[i], right.children[i])) return false;
    return true;
}
std::vector<std::string> commentsIn(const std::string& json) {
    std::vector<std::string> result;
    for (size_t i = 0; i < json.size();) {
        if (json[i] == '"') {
            ++i;
            while (i < json.size()) {
                if (json[i] == '\\') i += 2;
                else if (json[i++] == '"') break;
            }
        } else if (json.compare(i, 2, "//") == 0) {
            size_t end = json.find_first_of("\r\n", i);
            if (end == std::string::npos) end = json.size();
            result.push_back(json.substr(i, end - i)); i = end;
        } else if (json.compare(i, 2, "/*") == 0) {
            size_t end = json.find("*/", i + 2) + 2;
            result.push_back(json.substr(i, end - i)); i = end;
        } else ++i;
    }
    return result;
}
}
std::wstring wide(const std::string& text) {
    if (text.empty()) return {};
    int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), nullptr, 0);
    if (!length) throw Error("文件不是有效的 UTF-8 编码，请先将配置另存为 UTF-8。");
    std::wstring result(length, 0);
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), result.data(), length);
    return result;
}
std::string utf8(const std::wstring& text) {
    if (text.empty()) return {};
    int length = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), nullptr, 0, nullptr, nullptr);
    if (!length) throw Error("文字包含无效的 Unicode 字符。");
    std::string result(length, 0);
    WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), result.data(), length, nullptr, nullptr);
    return result;
}
std::string quote(const std::string& text) {
    std::string result = "\"";
    const char* hex = "0123456789abcdef";
    for (unsigned char c : text) {
        if (c == '"' || c == '\\') { result += '\\'; result += c; }
        else if (c < 0x20) { result += "\\u00"; result += hex[c >> 4]; result += hex[c & 15]; }
        else result += c;
    }
    return result + '"';
}
const Node* Node::member(const std::string& key) const {
    if (kind != Kind::Object) return nullptr;
    for (size_t i = 0; i < keys.size(); ++i) if (keys[i] == key) return &children[i];
    return nullptr;
}
Document::Document(std::string source) : source_(std::move(source)) { parse(); }
void Document::parse() { root_ = Parser(source_).run(); }
const Node* Document::find(const std::string& path) const {
    const Node* result = &root_;
    size_t pos = 0;
    do {
        size_t dot = path.find('.', pos);
        result = result->member(path.substr(pos, dot - pos));
        if (!result || dot == std::string::npos) return result;
        pos = dot + 1;
    } while (true);
}
std::string Document::raw(const Node& node) const { return source_.substr(node.begin, node.end - node.begin); }
void Document::set(const std::string& path, const std::string& json) {
    Node replacement = Parser(json).run(); // Only accept a complete, valid replacement value.
    if (const Node* existing = find(path)) {
        if (sameValue(*existing, replacement)) return;
        // A replaced list/object can contain comments, including disabled examples.
        // Keep every original occurrence; raw rule entries may already carry some.
        auto retained = commentsIn(json);
        std::string missing, newline = source_.find("\r\n") == std::string::npos ? "\n" : "\r\n";
        for (const auto& comment : commentsIn(raw(*existing))) {
            auto found = std::find(retained.begin(), retained.end(), comment);
            if (found != retained.end()) retained.erase(found);
            else missing += comment + newline;
        }
        std::string value = json;
        if (!missing.empty()) {
            if (replacement.kind == Kind::Array || replacement.kind == Kind::Object)
                value.insert(replacement.begin + 1, newline + missing);
            else value.insert(0, missing);
        }
        auto updated = source_; updated.replace(existing->begin, existing->end - existing->begin, value);
        Document checked(std::move(updated)); *this = std::move(checked); return;
    }
    size_t dot = path.rfind('.');
    std::string parentPath = dot == std::string::npos ? "" : path.substr(0, dot);
    std::string key = dot == std::string::npos ? path : path.substr(dot + 1);
    if (!parentPath.empty() && !find(parentPath)) set(parentPath, "{}");
    const Node* parent = parentPath.empty() ? &root_ : find(parentPath);
    if (!parent || parent->kind != Kind::Object) throw Error(parentPath + " 应为对象，不能在其中添加配置项。");
    size_t close = parent->close;
    size_t last = parent->children.empty() ? std::string::npos : parent->children.back().end;
    size_t lineStart = source_.rfind('\n', close);
    lineStart = lineStart == std::string::npos ? 0 : lineStart + 1;
    bool ownLine = source_.find_first_not_of(" \t", lineStart) == close;
    std::string indent = ownLine ? source_.substr(lineStart, close - lineStart) : std::string(parentPath.empty() ? 0 : 4 * (1 + std::count(parentPath.begin(), parentPath.end(), '.')), ' ');
    std::string newline = source_.find("\r\n") == std::string::npos ? "\n" : "\r\n";
    std::string insertion = (ownLine ? "" : newline) + indent + "    " + quote(key) + ": " + json + newline + (ownLine ? "" : indent);
    auto updated = source_;
    updated.insert(ownLine ? lineStart : close, insertion);
    if (last != std::string::npos) updated.insert(last, ",");
    Document checked(std::move(updated)); *this = std::move(checked);
}
std::string readFile(const std::wstring& path) {
    Handle file(CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr));
    if (file.h == INVALID_HANDLE_VALUE) throw Error(systemError("无法打开配置文件"));
    return readHandle(file.h);
}
void saveFile(const std::wstring& path, const std::string& replacement) {
    Document validation(replacement);
    if (validation.root().kind != Kind::Object) throw Error("配置最外层必须是对象。");
    std::wstring suffix = L"." + std::to_wstring(GetCurrentProcessId()) + L"." + std::to_wstring(GetTickCount64());
    std::wstring tempPath = path + suffix + L".tmp";
    {
        Handle temp(CreateFileW(tempPath.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr));
        if (temp.h == INVALID_HANDLE_VALUE) throw Error(systemError("无法创建临时配置文件，请检查目录写入权限"));
        try {
            DWORD written = 0;
            if (!WriteFile(temp.h, replacement.data(), static_cast<DWORD>(replacement.size()), &written, nullptr) || written != replacement.size())
                throw Error(systemError("写入临时配置失败"));
            if (!FlushFileBuffers(temp.h)) throw Error(systemError("刷新临时配置失败"));
        } catch (...) {
            CloseHandle(temp.h); temp.h = INVALID_HANDLE_VALUE; DeleteFileW(tempPath.c_str()); throw;
        }
    }
    if (!ReplaceFileW(path.c_str(), tempPath.c_str(), nullptr, 0, nullptr, nullptr)) {
        if(GetLastError()==ERROR_FILE_NOT_FOUND&&MoveFileExW(tempPath.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH))return;
        auto error = systemError("保存失败，当前编辑内容仍保留在窗口中");
        DeleteFileW(tempPath.c_str());
        throw Error(error);
    }
}
}
