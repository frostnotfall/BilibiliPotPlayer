#pragma once
#include <string>
#include <vector>
#include <stdexcept>

namespace bili {
enum class Kind { Object, Array, String, Number, Bool, Null };
struct Node {
    Kind kind = Kind::Null;
    size_t begin = 0, end = 0, close = 0;
    std::string text;
    std::vector<std::string> keys;
    std::vector<Node> children;
    const Node* member(const std::string& key) const;
};
struct Error : std::runtime_error { using std::runtime_error::runtime_error; };
std::wstring wide(const std::string& utf8);
std::string utf8(const std::wstring& text);
std::string quote(const std::string& text);

// Token spans refer to the original UTF-8 bytes, including a possible BOM.
// Comments and unknown members survive edits. Comments inside replaced containers
// are retained at the start of the new value when their old entries are removed.
class Document {
public:
    explicit Document(std::string source);
    const std::string& source() const { return source_; }
    const Node& root() const { return root_; }
    const Node* find(const std::string& path) const;
    std::string raw(const Node& node) const;
    void set(const std::string& path, const std::string& json);
private:
    std::string source_;
    Node root_;
    void parse();
};

std::string readFile(const std::wstring& path);
// Flush a sibling temporary before replacing the original. No backup or
// external-change check: saving applies the editor's current document.
void saveFile(const std::wstring& path, const std::string& replacement);
}
