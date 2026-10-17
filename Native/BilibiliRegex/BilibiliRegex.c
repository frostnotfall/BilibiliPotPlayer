#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0602
#include <windows.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>
#include "BilibiliRegex.h"
#include "vendor/quickjs-ng/libregexp.h"

#define DEFAULT_TIMEOUT_MS 250
#define MEMORY_LIMIT ((size_t)64 * 1024 * 1024)
#define STACK_RESERVE ((size_t)64 * 1024)

typedef struct {
    ULONGLONG deadline;
    uintptr_t stack_low;
    size_t used;
    int failure;
} Budget;

typedef struct { size_t bytes; } Allocation;
typedef struct { uint8_t *bytecode; int capture_slots; } CompiledRegex;
typedef struct { uint32_t count; CompiledRegex **rules; } RegexSet;

static __declspec(thread) int last_code;
static __declspec(thread) int last_rule = -1;
static __declspec(thread) char last_message[256];

static void clear_error(void) {
    last_code = 0;
    last_rule = -1;
    last_message[0] = '\0';
}

static int fail(int code, const char *message) {
    last_code = code;
    snprintf(last_message, sizeof(last_message), "%s", message);
    return code;
}

static void init_budget(Budget *budget, uint32_t timeout_ms) {
    ULONG_PTR low, high;
    GetCurrentThreadStackLimits(&low, &high);
    budget->deadline = GetTickCount64() + (timeout_ms ? timeout_ms : DEFAULT_TIMEOUT_MS);
    budget->stack_low = (uintptr_t)low;
    budget->used = 0;
    budget->failure = 0;
}

int lre_check_timeout(void *opaque) {
    Budget *budget = (Budget *)opaque;
    if (budget && GetTickCount64() >= budget->deadline) {
        budget->failure = BILI_REGEX_TIMEOUT;
        return 1;
    }
    return 0;
}

bool lre_check_stack_overflow(void *opaque, size_t alloca_size) {
    Budget *budget = (Budget *)opaque;
    char marker;
    uintptr_t current = (uintptr_t)&marker;
    if (lre_check_timeout(opaque)) return true;
    if (budget && (current <= budget->stack_low ||
        current - budget->stack_low <= STACK_RESERVE ||
        alloca_size >= current - budget->stack_low - STACK_RESERVE)) {
        budget->failure = BILI_REGEX_STACK_ERROR;
        return true;
    }
    return false;
}

void *lre_realloc(void *opaque, void *ptr, size_t size) {
    Budget *budget = (Budget *)opaque;
    Allocation *old = ptr ? ((Allocation *)ptr - 1) : NULL;
    size_t previous = old ? old->bytes : 0;
    Allocation *allocation;
    if (size == 0) {
        if (budget) budget->used -= previous;
        free(old);
        return NULL;
    }
    if (size > MEMORY_LIMIT || (budget && size > MEMORY_LIMIT - (budget->used - previous))) {
        if (budget) budget->failure = BILI_REGEX_MEMORY_ERROR;
        return NULL;
    }
    allocation = (Allocation *)realloc(old, sizeof(Allocation) + size);
    if (!allocation) {
        if (budget) budget->failure = BILI_REGEX_MEMORY_ERROR;
        return NULL;
    }
    allocation->bytes = size;
    if (budget) budget->used = budget->used - previous + size;
    return allocation + 1;
}

static void release_bytecode(uint8_t *ptr) {
    if (ptr) free((Allocation *)ptr - 1);
}

static int valid_utf8(const char *text, uint32_t bytes) {
    if ((!text && bytes) || bytes > INT_MAX) {
        fail(BILI_REGEX_INVALID_ARGUMENT, "Invalid UTF-8 pointer or byte length");
        return 0;
    }
    if (!bytes) return 1;
    if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text, (int)bytes, NULL, 0)) {
        fail(BILI_REGEX_UTF8_ERROR, "Input is not valid UTF-8");
        return 0;
    }
    return 1;
}

static int parse_flags(const char *flags, int *result) {
    const char *allowed = "gimsuydv";
    const int bits[] = {LRE_FLAG_GLOBAL, LRE_FLAG_IGNORECASE, LRE_FLAG_MULTILINE,
        LRE_FLAG_DOTALL, LRE_FLAG_UNICODE, LRE_FLAG_STICKY, LRE_FLAG_INDICES, LRE_FLAG_UNICODE_SETS};
    unsigned int seen = 0;
    int value = 0;
    if (flags) {
        unsigned int i;
        for (i = 0; i < 9 && flags[i]; i++) {
            const char *position = strchr(allowed, flags[i]);
            unsigned int bit;
            if (!position) return fail(BILI_REGEX_COMPILE_ERROR, "Unknown JavaScript RegExp flag");
            bit = 1U << (unsigned int)(position - allowed);
            if (seen & bit) return fail(BILI_REGEX_COMPILE_ERROR, "Duplicate JavaScript RegExp flag");
            seen |= bit;
            value |= bits[position - allowed];
        }
        if (i == 9) return fail(BILI_REGEX_COMPILE_ERROR, "Too many JavaScript RegExp flags");
    }
    if ((value & LRE_FLAG_UNICODE) && (value & LRE_FLAG_UNICODE_SETS))
        return fail(BILI_REGEX_COMPILE_ERROR, "Flags u and v are mutually exclusive");
    *result = value;
    return 0;
}

static uint8_t *prepare_pattern(const char *pattern, uint32_t bytes, int flags,
                                Budget *budget, size_t *prepared_bytes) {
    uint8_t *buffer;
    *prepared_bytes = bytes;
    if (flags & (LRE_FLAG_UNICODE | LRE_FLAG_UNICODE_SETS)) {
        buffer = (uint8_t *)lre_realloc(budget, NULL, (size_t)bytes + 1);
        if (buffer) {
            if (bytes) memcpy(buffer, pattern, bytes);
            buffer[bytes] = 0;
        }
        return buffer;
    } else {
        /* Match QuickJS's own RegExp constructor: non-u/v patterns use CESU-8,
         * preserving UTF-16 surrogate pairs instead of treating emoji as one
         * Unicode scalar. lre_compile also requires a terminating NUL even
         * when the caller supplies an explicit byte length or a rule slice.
         */
        int units = bytes ? MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
            pattern, (int)bytes, NULL, 0) : 0;
        uint16_t *utf16;
        size_t at = 0;
        int i;
        if ((size_t)units >= MEMORY_LIMIT / 3) {
            budget->failure = BILI_REGEX_MEMORY_ERROR;
            return NULL;
        }
        utf16 = (uint16_t *)lre_realloc(budget, NULL, ((size_t)units + 1) * sizeof(uint16_t));
        if (!utf16) return NULL;
        if (units) MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, pattern,
            (int)bytes, (wchar_t *)utf16, units);
        buffer = (uint8_t *)lre_realloc(budget, NULL, (size_t)units * 3 + 1);
        if (buffer) {
            for (i = 0; i < units; i++) {
                uint16_t c = utf16[i];
                if (c < 0x80) buffer[at++] = (uint8_t)c;
                else if (c < 0x800) {
                    buffer[at++] = (uint8_t)(0xC0 | (c >> 6));
                    buffer[at++] = (uint8_t)(0x80 | (c & 63));
                } else {
                    buffer[at++] = (uint8_t)(0xE0 | (c >> 12));
                    buffer[at++] = (uint8_t)(0x80 | ((c >> 6) & 63));
                    buffer[at++] = (uint8_t)(0x80 | (c & 63));
                }
            }
            buffer[at] = 0;
            *prepared_bytes = at;
        }
        lre_realloc(budget, utf16, 0);
        return buffer;
    }
}

static uintptr_t compile_pattern(const char *pattern, uint32_t bytes, int flags, Budget *budget) {
    int length;
    size_t prepared_bytes;
    char message[192] = {0};
    uint8_t *prepared = prepare_pattern(pattern, bytes, flags, budget, &prepared_bytes);
    uint8_t *bytecode;
    CompiledRegex *compiled;
    if (!prepared) {
        fail(BILI_REGEX_MEMORY_ERROR, "Pattern allocation exceeded 64 MiB or failed");
        return 0;
    }
    bytecode = lre_compile(&length, message, sizeof(message),
        (const char *)prepared, prepared_bytes, flags, budget);
    lre_realloc(budget, prepared, 0);
    if (!bytecode) {
        if (budget->failure == BILI_REGEX_TIMEOUT) fail(BILI_REGEX_TIMEOUT, "RegExp compilation timed out");
        else if (budget->failure == BILI_REGEX_MEMORY_ERROR) fail(BILI_REGEX_MEMORY_ERROR, "RegExp allocation exceeded 64 MiB or failed");
        else if (budget->failure == BILI_REGEX_STACK_ERROR) fail(BILI_REGEX_STACK_ERROR, "RegExp nesting exceeded available thread stack");
        else fail(BILI_REGEX_COMPILE_ERROR, message[0] ? message : "Invalid JavaScript RegExp");
        return 0;
    }
    compiled = (CompiledRegex *)malloc(sizeof(*compiled));
    if (!compiled) {
        lre_realloc(budget, bytecode, 0);
        fail(BILI_REGEX_MEMORY_ERROR, "Could not allocate compiled RegExp handle");
        return 0;
    }
    compiled->bytecode = bytecode;
    compiled->capture_slots = lre_get_alloc_count(bytecode);
    clear_error();
    return (uintptr_t)compiled;
}

uintptr_t BiliRegexCompile(const char *pattern, uint32_t bytes, const char *flags, uint32_t timeout_ms) {
    Budget budget;
    int parsed_flags;
    clear_error();
    if (!valid_utf8(pattern, bytes) || parse_flags(flags, &parsed_flags) < 0) return 0;
    init_budget(&budget, timeout_ms);
    return compile_pattern(pattern, bytes, parsed_flags, &budget);
}

uintptr_t BiliRegexCompileRule(const char *rule, uint32_t bytes, uint32_t timeout_ms) {
    Budget budget;
    uint32_t slash, i;
    clear_error();
    if (!valid_utf8(rule, bytes)) return 0;
    init_budget(&budget, timeout_ms);
    /* Exact web wrapper recognizer: no line terminators in .+, nonempty body,
     * greedy final '/', and a suffix consisting of 0..3 characters from img.
     * Failure to compile the wrapper body falls back to the complete rule.
     */
    if (bytes >= 3 && rule[0] == '/') {
        slash = bytes - 1;
        while (slash > 0 && rule[slash] != '/') slash--;
        if (slash > 1 && bytes - slash - 1 <= 3) {
            bool wrapped = true;
            char flags[4] = {0};
            for (i = 1; i < slash; i++) {
                unsigned char c = (unsigned char)rule[i];
                if (c == '\n' || c == '\r' ||
                    (c == 0xE2 && i + 2 < slash && (unsigned char)rule[i + 1] == 0x80 &&
                     ((unsigned char)rule[i + 2] == 0xA8 || (unsigned char)rule[i + 2] == 0xA9))) wrapped = false;
            }
            for (i = slash + 1; i < bytes; i++) {
                if (rule[i] != 'i' && rule[i] != 'm' && rule[i] != 'g') wrapped = false;
                flags[i - slash - 1] = rule[i];
            }
            if (wrapped) {
                int parsed_flags;
                if (parse_flags(flags, &parsed_flags) == 0) {
                    uintptr_t handle = compile_pattern(rule + 1, slash - 1, parsed_flags, &budget);
                    if (handle) return handle;
                    /* Resource failures are not syntax failures: report them. */
                    if (last_code != BILI_REGEX_COMPILE_ERROR) return 0;
                }
            }
        }
    }
    clear_error();
    return compile_pattern(rule, bytes, 0, &budget);
}

static int test_rules(CompiledRegex *const *rules, uint32_t count,
                      const char *text, uint32_t bytes, uint32_t timeout_ms) {
    Budget budget;
    uint16_t *utf16;
    uint8_t **captures;
    uint32_t i;
    int units, result = 0, capture_slots = 0, failed_rule = -1;
    clear_error();
    if ((!text && bytes) || bytes > INT_MAX)
        return fail(BILI_REGEX_INVALID_ARGUMENT, "Invalid UTF-8 pointer or byte length");
    for (i = 0; i < count; i++) {
        if (rules[i] && rules[i]->capture_slots > capture_slots)
            capture_slots = rules[i]->capture_slots;
    }
    if (!capture_slots) return 0;
    init_budget(&budget, timeout_ms);
    units = bytes ? MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text, (int)bytes, NULL, 0) : 0;
    if (bytes && !units) return fail(BILI_REGEX_UTF8_ERROR, "Input is not valid UTF-8");
    if ((size_t)units >= MEMORY_LIMIT / sizeof(uint16_t))
        return fail(BILI_REGEX_MEMORY_ERROR, "Text allocation exceeded 64 MiB");
    utf16 = (uint16_t *)lre_realloc(&budget, NULL, ((size_t)units + 1) * sizeof(uint16_t));
    if (!utf16) return fail(BILI_REGEX_MEMORY_ERROR, "Text allocation exceeded 64 MiB or failed");
    if (units && MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text, (int)bytes, (wchar_t *)utf16, units) != units) {
        lre_realloc(&budget, utf16, 0);
        return fail(BILI_REGEX_UTF8_ERROR, "Could not convert text to UTF-16");
    }
    utf16[units] = 0;
    captures = (uint8_t **)lre_realloc(&budget, NULL, (size_t)capture_slots * sizeof(uint8_t *));
    if (!captures) {
        lre_realloc(&budget, utf16, 0);
        return fail(BILI_REGEX_MEMORY_ERROR, "Could not allocate RegExp match state");
    }
    /* A fresh execution at UTF-16 index zero on every call also implements
     * Bilibili's fresh-RegExp behavior for g/y without shared lastIndex state. */
    for (i = 0; i < count; i++) {
        if (!rules[i]) continue;
        /* Reset only the deadline, retaining accounting for live buffers. */
        budget.deadline = GetTickCount64() + (timeout_ms ? timeout_ms : DEFAULT_TIMEOUT_MS);
        budget.failure = 0;
        result = lre_exec(captures, rules[i]->bytecode, (const uint8_t *)utf16, 0, units, 1, &budget);
        if (result != 0) {
            if (result != 1) failed_rule = (int)i;
            break;
        }
    }
    lre_realloc(&budget, captures, 0);
    lre_realloc(&budget, utf16, 0);
    if (result == 0 || result == 1) return result;
    last_rule = failed_rule;
    if (result == LRE_RET_TIMEOUT || budget.failure == BILI_REGEX_TIMEOUT)
        return fail(BILI_REGEX_TIMEOUT, "RegExp matching timed out; this is not a non-match");
    if (result == LRE_RET_MEMORY_ERROR || budget.failure == BILI_REGEX_MEMORY_ERROR)
        return fail(BILI_REGEX_MEMORY_ERROR, "RegExp match allocation exceeded 64 MiB or failed");
    return fail(BILI_REGEX_INTERNAL_ERROR, "RegExp engine returned an execution error");
}

int BiliRegexTest(uintptr_t handle, const char *text, uint32_t bytes, uint32_t timeout_ms) {
    CompiledRegex *compiled = (CompiledRegex *)handle;
    clear_error();
    if (!compiled) return fail(BILI_REGEX_INVALID_ARGUMENT, "RegExp handle is NULL");
    return test_rules(&compiled, 1, text, bytes, timeout_ms);
}

uintptr_t BiliRegexCreateSet(uint32_t capacity) {
    RegexSet *set;
    clear_error();
    if (capacity > INT_MAX || (size_t)capacity > MEMORY_LIMIT / sizeof(CompiledRegex *)) {
        fail(BILI_REGEX_INVALID_ARGUMENT, "RegExp set capacity exceeds budget");
        return 0;
    }
    set = (RegexSet *)calloc(1, sizeof(*set));
    if (!set) { fail(BILI_REGEX_MEMORY_ERROR, "Could not allocate RegExp set"); return 0; }
    if (capacity) {
        set->rules = (CompiledRegex **)calloc(capacity, sizeof(CompiledRegex *));
        if (!set->rules) {
            free(set);
            fail(BILI_REGEX_MEMORY_ERROR, "Could not allocate RegExp set rules");
            return 0;
        }
    }
    set->count = capacity;
    return (uintptr_t)set;
}

int BiliRegexSetRule(uintptr_t handle, uint32_t index, uintptr_t rule) {
    RegexSet *set = (RegexSet *)handle;
    clear_error();
    if (!set || index >= set->count) return fail(BILI_REGEX_INVALID_ARGUMENT, "RegExp set index out of range");
    set->rules[index] = (CompiledRegex *)rule;
    return 0;
}

int BiliRegexTestSet(uintptr_t handle, const char *text, uint32_t bytes, uint32_t timeout_ms) {
    RegexSet *set = (RegexSet *)handle;
    clear_error();
    if (!set) return fail(BILI_REGEX_INVALID_ARGUMENT, "RegExp set is NULL");
    return test_rules(set->rules, set->count, text, bytes, timeout_ms);
}

int BiliRegexFreeSet(uintptr_t handle) {
    RegexSet *set = (RegexSet *)handle;
    clear_error();
    if (set) { free(set->rules); free(set); }
    return 0;
}

int BiliRegexFree(uintptr_t handle) {
    CompiledRegex *compiled = (CompiledRegex *)handle;
    clear_error();
    if (compiled) {
        release_bytecode(compiled->bytecode);
        free(compiled);
    }
    return 0;
}

int BiliRegexGetLastErrorCode(void) { return last_code; }
int BiliRegexGetLastErrorRule(void) { return last_rule; }
const char *BiliRegexGetLastError(void) { return last_message; }
uint32_t BiliRegexGetAbiVersion(void) { return 1; }
const char *BiliRegexGetEngineVersion(void) { return "QuickJS-NG v0.17.0 libregexp / BilibiliRegex ABI 1 set-api 1"; }
