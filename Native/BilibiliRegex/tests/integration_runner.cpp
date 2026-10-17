// AngelScript runtime + real DLL, with small stand-ins for the PotPlayer API.
// This verifies the actual class/filter block extracted from the playback file;
// PotPlayer's own Host* implementations still require an in-player smoke test.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <angelscript.h>
#include <scriptstdstring.h>
#include <scriptarray.h>
#include <scriptdictionary.h>
#include <scriptany.h>
#include <fstream>
#include <sstream>
#include <iostream>
#include <string>
#include <vector>
#include <new>

static std::string workspace;
static std::vector<std::string> logs;
static int fault, live_libraries, live_handles, compile_count, free_count, test_call_count;
static uintptr_t free_set_address;

static const std::string &str(asIScriptGeneric *g, unsigned index) {
    return *static_cast<std::string *>(g->GetArgAddress(index));
}
static void return_string(asIScriptGeneric *g, const std::string &value) {
    new (g->GetAddressOfReturnLocation()) std::string(value);
}
static void message(const asSMessageInfo *m, void *) {
    std::cerr << m->section << ':' << m->row << ':' << m->col << ' ' << m->message << '\n';
}
static void assertion(asIScriptGeneric *g) {
    if (!g->GetArgByte(0)) asGetActiveContext()->SetException(str(g, 1).c_str());
}
static void string_empty(asIScriptGeneric *g) {
    g->SetReturnByte(static_cast<std::string *>(g->GetObject())->empty());
}
static void array_empty(asIScriptGeneric *g) {
    g->SetReturnByte(static_cast<CScriptArray *>(g->GetObject())->IsEmpty());
}
static void print(asIScriptGeneric *g) {
    logs.push_back(str(g, 0));
    if (str(g, 0).find("[benchmark]") == 0 || str(g, 0).find("[Danmaku]") != std::string::npos)
        std::cout << str(g, 0) << '\n';
}
static void set_fault(asIScriptGeneric *g) {
    if (live_libraries || live_handles) {
        asGetActiveContext()->SetException("Resources leaked by previous filter call");
        return;
    }
    fault = g->GetArgDWord(0); logs.clear(); compile_count = free_count = test_call_count = 0;
}
static void active_libraries(asIScriptGeneric *g) { g->SetReturnDWord(live_libraries); }
static void active_handles(asIScriptGeneric *g) { g->SetReturnDWord(live_handles); }
static void compilation_count(asIScriptGeneric *g) { g->SetReturnDWord(compile_count); }
static void release_count(asIScriptGeneric *g) { g->SetReturnDWord(free_count); }
static void test_calls(asIScriptGeneric *g) { g->SetReturnDWord(test_call_count); }
static void log_count(asIScriptGeneric *g) { g->SetReturnDWord(static_cast<asDWORD>(logs.size())); }
static void log_contains(asIScriptGeneric *g) {
    for (const auto &line : logs) if (line.find(str(g, 0)) != std::string::npos) {
        g->SetReturnByte(true); return;
    }
    g->SetReturnByte(false);
}
static void extension_folder(asIScriptGeneric *g) { return_string(g, workspace + "\\Extension\\"); }
static void load_library(asIScriptGeneric *g) {
    HMODULE library = fault == 1 ? nullptr : LoadLibraryA(str(g, 0).c_str());
    if (library) ++live_libraries;
    g->SetReturnQWord(reinterpret_cast<uintptr_t>(library));
}
static void free_library(asIScriptGeneric *g) {
    if (FreeLibrary(reinterpret_cast<HMODULE>(g->GetArgQWord(0)))) --live_libraries;
}
static void get_proc(asIScriptGeneric *g) {
    FARPROC proc = GetProcAddress(reinterpret_cast<HMODULE>(g->GetArgQWord(0)), str(g, 1).c_str());
    if (fault == 2 && str(g, 1) == "BiliRegexTestSet") proc = nullptr;
    if (str(g, 1) == "BiliRegexFreeSet") free_set_address = reinterpret_cast<uintptr_t>(proc);
    g->SetReturnQWord(reinterpret_cast<uintptr_t>(proc));
}
static void string_pointer(asIScriptGeneric *g) {
    g->SetReturnQWord(reinterpret_cast<uintptr_t>(str(g, 0).data()));
}
static void pointer_string(asIScriptGeneric *g) {
    const char *ptr = reinterpret_cast<const char *>(g->GetArgQWord(0));
    return_string(g, ptr ? ptr : "");
}
static void read_test_file(asIScriptGeneric *g) {
    std::ifstream file(str(g, 0), std::ios::binary);
    if (!file) { asGetActiveContext()->SetException("Cannot read test fixture"); return; }
    std::stringstream buffer; buffer << file.rdbuf();
    return_string(g, buffer.str());
}
static void call_pointer(asIScriptGeneric *g) {
    auto address = static_cast<uintptr_t>(g->GetArgQWord(0));
    uintptr_t result = 0;
    if (str(g, 1) == "PII") {
        auto fn = reinterpret_cast<uintptr_t (*)(const char *, uint32_t, uint32_t)>(address);
        result = fn(reinterpret_cast<const char *>(g->GetArgQWord(2)),
            static_cast<uint32_t>(g->GetArgQWord(3)), static_cast<uint32_t>(g->GetArgQWord(4)));
        ++compile_count;
        if (result) ++live_handles;
    } else if (str(g, 1) == "I") {
        if (fault != 6) result = reinterpret_cast<uintptr_t (*)(uint32_t)>(address)(static_cast<uint32_t>(g->GetArgQWord(2)));
        if (result) ++live_handles;
    } else if (str(g, 1).empty()) {
        result = reinterpret_cast<uintptr_t (*)()>(address)();
    } else {
        asGetActiveContext()->SetException("Unexpected HostCallProcUIntPtr signature");
    }
    g->SetReturnQWord(result);
}
static void call_int(asIScriptGeneric *g) {
    auto address = static_cast<uintptr_t>(g->GetArgQWord(0));
    int result = -1000;
    if (str(g, 1) == "PPII") {
        ++test_call_count;
        if (fault == 4) result = -3;
        else if (fault == 5) {
            asGetActiveContext()->SetException("Simulated HostCallProcInt application exception");
            return;
        } else {
            auto fn = reinterpret_cast<int (*)(uintptr_t, const char *, uint32_t, uint32_t)>(address);
            result = fn(static_cast<uintptr_t>(g->GetArgQWord(2)),
                reinterpret_cast<const char *>(g->GetArgQWord(3)),
                static_cast<uint32_t>(g->GetArgQWord(4)), static_cast<uint32_t>(g->GetArgQWord(5)));
        }
    } else if (str(g, 1) == "P") {
        auto handle = static_cast<uintptr_t>(g->GetArgQWord(2));
        result = reinterpret_cast<int (*)(uintptr_t)>(address)(handle);
        if (handle) { --live_handles; if (address != free_set_address) ++free_count; }
    } else if (str(g, 1) == "PIP") {
        result = fault == 7 ? -4 : reinterpret_cast<int (*)(uintptr_t, uint32_t, uintptr_t)>(address)(
            static_cast<uintptr_t>(g->GetArgQWord(2)), static_cast<uint32_t>(g->GetArgQWord(3)),
            static_cast<uintptr_t>(g->GetArgQWord(4)));
    } else if (str(g, 1).empty()) {
        result = reinterpret_cast<int (*)()>(address)();
        // The ABI query is the only no-argument call returning 1 here.
        if (fault == 3 && result == 1) result = 99;
    } else {
        asGetActiveContext()->SetException("Unexpected HostCallProcInt signature");
    }
    g->SetReturnDWord(result);
}
static void tick(asIScriptGeneric *g) { g->SetReturnDWord(GetTickCount()); }
static void inc_timeout(asIScriptGeneric *) {}

int main(int argc, char **argv) {
    if (argc != 3) return 1;
    workspace = argv[2];
    auto *engine = asCreateScriptEngine();
    engine->SetMessageCallback(asFUNCTION(message), nullptr, asCALL_CDECL);
    engine->RegisterTypedef("uintptr", "uint64");
    RegisterStdString(engine); RegisterScriptArray(engine, true);
    engine->RegisterObjectMethod("string", "bool empty() const", asFUNCTION(string_empty), asCALL_GENERIC);
    engine->RegisterObjectMethod("array<T>", "bool empty() const", asFUNCTION(array_empty), asCALL_GENERIC);
    RegisterScriptDictionary(engine); RegisterScriptAny(engine);
#define BIND(decl, fn) if (engine->RegisterGlobalFunction(decl, asFUNCTION(fn), asCALL_GENERIC) < 0) return 1
    BIND("void Assert(bool, const string &in)", assertion);
    BIND("void HostPrintUTF8(const string &in)", print);
    BIND("void SetHostFault(int)", set_fault);
    BIND("int ActiveLibraries()", active_libraries);
    BIND("int ActiveHandles()", active_handles);
    BIND("int CompilationCount()", compilation_count);
    BIND("int ReleaseCount()", release_count);
    BIND("int TestCallCount()", test_calls);
    BIND("int LogCount()", log_count);
    BIND("bool LogContains(const string &in)", log_contains);
    BIND("string HostGetExtensionFolder()", extension_folder);
    BIND("uintptr HostLoadLibrary(const string &in)", load_library);
    BIND("void HostFreeLibrary(uintptr)", free_library);
    BIND("uintptr HostGetProcAddress(uintptr, const string &in)", get_proc);
    BIND("uintptr HostString2UIntPtr(const string &in)", string_pointer);
    BIND("string HostUIntPtr2String(uintptr)", pointer_string);
    BIND("string ReadTestFile(const string &in)", read_test_file);
    BIND("uint HostGetTickCount()", tick);
    BIND("void HostIncTimeOut(int)", inc_timeout);
    BIND("uintptr HostCallProcUIntPtr(uintptr, const string &in, uint64=0, uint64=0, uint64=0, uint64=0, uint64=0, uint64=0)", call_pointer);
    BIND("int HostCallProcInt(uintptr, const string &in, uint64=0, uint64=0, uint64=0, uint64=0, uint64=0, uint64=0)", call_int);
    std::ifstream file(argv[1]); std::stringstream buffer; buffer << file.rdbuf();
    auto source = buffer.str();
    auto *module = engine->GetModule("integration", asGM_ALWAYS_CREATE);
    module->AddScriptSection("playback-extract", source.c_str());
    if (module->Build() < 0) return 2;
    auto *ctx = engine->CreateContext();
    ctx->Prepare(module->GetFunctionByName("Run"));
    int result = ctx->Execute();
    if (result != asEXECUTION_FINISHED) {
        std::cerr << "FAIL line " << ctx->GetExceptionLineNumber() << ": " << ctx->GetExceptionString() << '\n';
        for (const auto &line : logs) std::cerr << line << '\n';
        return 3;
    }
    ctx->Release(); engine->ShutDownAndRelease();
    if (live_libraries || live_handles) return 4;
    std::cout << "PASS: extracted playback + real x64 DLL; filter 1/8 workers/fallback, compile-once, lifetime, failures; merge/render, uint64 sort, segment decode/collect, log/debug controls (mock host)\n";
}
