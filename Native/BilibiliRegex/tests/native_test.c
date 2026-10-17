#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0602
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../BilibiliRegex.h"

static uintptr_t (__cdecl *compile)(const char *, uint32_t, const char *, uint32_t);
static uintptr_t (__cdecl *compile_rule)(const char *, uint32_t, uint32_t);
static int (__cdecl *test)(uintptr_t, const char *, uint32_t, uint32_t);
static int (__cdecl *release)(uintptr_t);
static int (__cdecl *error_code)(void);
static const char *(__cdecl *error_text)(void);
static uintptr_t (__cdecl *create_set)(uint32_t);
static int (__cdecl *set_rule)(uintptr_t, uint32_t, uintptr_t);
static int (__cdecl *test_set)(uintptr_t, const char *, uint32_t, uint32_t);
static int (__cdecl *free_set)(uintptr_t);
static int (__cdecl *error_rule)(void);
static uintptr_t shared, shared_set;
static volatile LONG thread_failures;

static DWORD WINAPI thread_test(void *arg) {
    uintptr_t number = (uintptr_t)arg;
    int i;
    for (i = 0; i < 500; i++) {
        int expected = number & 1 ? -1 : 0;
        if (number & 1) test(0, "", 0, 1000);
        else test(shared, "foo42", 5, 1000);
        Sleep(0);
        if (error_code() != expected) InterlockedIncrement(&thread_failures);
        if (test(shared, "foo42", 5, 1000) != 1 ||
            test(shared, "other", 5, 1000) != 0 ||
            test_set(shared_set, "foo42", 5, 1000) != 1 ||
            test_set(shared_set, "other", 5, 1000) != 0)
            InterlockedIncrement(&thread_failures);
    }
    return 0;
}

static int check(int condition, const char *label) {
    if (condition) return 1;
    fprintf(stderr, "FAIL %s: %d %s\n", label, error_code(), error_text());
    return 0;
}

static char *read_string(FILE *file, uint32_t bytes) {
    char *result;
    if (bytes > 16 * 1024 * 1024) return NULL;
    result = (char *)malloc((size_t)bytes + 1);
    if (!result) return NULL;
    if (fread(result, 1, bytes, file) != bytes) { free(result); return NULL; }
    result[bytes] = 0;
    return result;
}

int wmain(int argc, wchar_t **argv) {
    HMODULE dll;
    FILE *file;
    char magic[4];
    uint32_t count, i;
    if (argc != 3) return 1;
    dll = LoadLibraryW(argv[1]);
    if (!dll) { fprintf(stderr, "LoadLibrary failed: %lu\n", GetLastError()); return 1; }
#define LOAD(variable, symbol) do { \
    FARPROC address = GetProcAddress(dll, symbol); \
    if (!address) { fprintf(stderr, "Missing export: %s\n", symbol); return 1; } \
    memcpy(&variable, &address, sizeof(variable)); \
} while (0)
    LOAD(compile, "BiliRegexCompile");
    LOAD(compile_rule, "BiliRegexCompileRule");
    LOAD(test, "BiliRegexTest");
    LOAD(release, "BiliRegexFree");
    LOAD(error_code, "BiliRegexGetLastErrorCode");
    LOAD(error_text, "BiliRegexGetLastError");
    LOAD(create_set, "BiliRegexCreateSet");
    LOAD(set_rule, "BiliRegexSetRule");
    LOAD(test_set, "BiliRegexTestSet");
    LOAD(free_set, "BiliRegexFreeSet");
    LOAD(error_rule, "BiliRegexGetLastErrorRule");
    file = _wfopen(argv[2], L"rb");
    if (!file || fread(magic, 1, 4, file) != 4 || memcmp(magic, "BRX1", 4) ||
        fread(&count, 4, 1, file) != 1) return 1;
    for (i = 0; i < count; i++) {
        uint32_t fields[5];
        char *pattern, *flags, *text;
        uintptr_t handle;
        int actual;
        int32_t expected;
        if (fread(fields, 4, 5, file) != 5) return 1;
        expected = (int32_t)fields[4];
        pattern = read_string(file, fields[1]);
        flags = read_string(file, fields[2]);
        text = read_string(file, fields[3]);
        if (!pattern || !flags || !text) return 1;
        handle = fields[0] ? compile_rule(pattern, fields[1], 1000) :
            compile(pattern, fields[1], flags, 1000);
        actual = handle ? test(handle, text, fields[3], 1000) : error_code();
        if (actual != expected) {
            fprintf(stderr, "Case %u expected %d actual %d: pattern=%s flags=%s error=%s\n",
                i, expected, actual, pattern, flags, error_text());
            return 2;
        }
        /* A cached global/sticky regex must behave as a fresh regex each time. */
        if (handle && test(handle, text, fields[3], 1000) != expected) return 2;
        if (handle) {
            uintptr_t set = create_set(3);
            if (!check(set && set_rule(set, 1, handle) == 0, "borrowed set with null slots")) return 2;
            if (!check(test_set(set, text, fields[3], 1000) == expected &&
                       test_set(set, text, fields[3], 1000) == expected, "V8 differential set/fresh reuse")) return 2;
            free_set(set);
            if (!check(test(handle, text, fields[3], 1000) == expected, "free set does not own rules")) return 2;
        }
        release(handle);
        free(pattern); free(flags); free(text);
    }
    fclose(file);
    if (!check(test(0, "", 0, 0) == -1, "NULL handle")) return 3;
    shared = compile("foo[0-9]+", 9, "g", 0);
    if (!check(shared != 0, "shared compile")) return 3;
    shared_set = create_set(2);
    if (!check(shared_set && set_rule(shared_set, 1, shared) == 0, "shared set")) return 3;
    {
        HANDLE threads[8];
        for (i = 0; i < 8; i++) {
            threads[i] = CreateThread(NULL, 0, thread_test, (void *)(uintptr_t)i, 0, NULL);
            if (!threads[i]) return 3;
        }
        WaitForMultipleObjects(8, threads, TRUE, INFINITE);
        for (i = 0; i < 8; i++) CloseHandle(threads[i]);
        if (!check(thread_failures == 0, "shared handle and thread-local errors")) return 3;
    }
    if (!check(test(shared, "\xff", 1, 0) == -5, "invalid UTF-8")) return 3;
    if (!check(test_set(shared_set, "\xff", 1, 0) == -5 && error_rule() == -1, "set invalid UTF-8")) return 3;
    if (!check(set_rule(shared_set, 2, shared) == -1, "set bounds")) return 3;
    free_set(shared_set);
    release(shared);
    {
        char text[65];
        uintptr_t handle = compile("(a+)+$", 6, "", 0);
        if (!check(handle != 0, "timeout rule compile")) return 3;
        memset(text, 'a', 64); text[64] = '!';
        if (!check(test(handle, text, 65, 1) == -3, "pathological match timeout")) return 3;
        if (!check(test(handle, "a", 1, 1000) == 1, "rule still works after timeout")) return 3;
        {
            uintptr_t early = compile("!", 1, "", 0), set = create_set(3);
            if (!check(early && set && set_rule(set, 2, handle) == 0, "timeout set")) return 3;
            if (!check(test_set(set, text, 65, 1) == -3 && error_rule() == 2,
                       "set reports failing original slot")) return 3;
            if (!check(test_set(set, "a", 1, 1000) == 1 && error_rule() == -1,
                       "set recovers and clears failing slot")) return 3;
            if (!check(set_rule(set, 0, early) == 0 && test_set(set, text, 65, 1) == 1,
                       "earlier match short-circuits pathological later rule")) return 3;
            free_set(set); release(early);
        }
        release(handle);
    }
    {
        /* Byte length is authoritative, even if a longer buffer follows it. */
        uintptr_t handle = compile("^a$NOT_PART_OF_PATTERN", 3, "", 0);
        if (!check(handle && test(handle, "aTAIL", 1, 0) == 1, "bounded input slices")) return 3;
        release(handle);
    }
    {
        char *nested = (char *)malloc(80002);
        uintptr_t handle;
        if (!nested) return 3;
        for (i = 0; i < 20000; i++) memcpy(nested + i * 3, "(?:", 3);
        nested[60000] = 'a';
        memset(nested + 60001, ')', 20000); nested[80001] = 0;
        handle = compile(nested, 80001, "", 1000);
        if (!check(!handle && (error_code() == -6 || error_code() == -3), "deep nesting guard")) return 3;
        free(nested);
    }
    release(0);
    {
        uintptr_t empty = create_set(0);
        if (!check(empty && test_set(empty, "", 0, 0) == 0, "empty set")) return 3;
        free_set(empty); free_set(0);
        if (!check(test_set(0, "", 0, 0) == -1 && error_rule() == -1, "NULL set")) return 3;
    }
    FreeLibrary(dll);
    printf("PASS %u V8 differential cases (single + set), cached reuse, 8 threads, UTF-8 errors, timeout/slot recovery, ordered short-circuit, slices, nesting (%u-bit)\n",
        count, (unsigned int)(sizeof(void *) * 8));
    return 0;
}
