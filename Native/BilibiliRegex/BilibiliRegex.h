#ifndef BILIBILI_REGEX_H
#define BILIBILI_REGEX_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Windows x64 C ABI; exported names are undecorated.
 * All strings are UTF-8. Explicit lengths are byte counts, including embedded
 * NULs, excluding any optional terminator. Handles are immutable and shareable
 * across threads, provided Free never runs concurrently with Test.
 */
enum BiliRegexResult {
    BILI_REGEX_NO_MATCH = 0,
    BILI_REGEX_MATCH = 1,
    BILI_REGEX_INVALID_ARGUMENT = -1,
    BILI_REGEX_COMPILE_ERROR = -2,
    BILI_REGEX_TIMEOUT = -3,
    BILI_REGEX_MEMORY_ERROR = -4,
    BILI_REGEX_UTF8_ERROR = -5,
    BILI_REGEX_STACK_ERROR = -6,
    BILI_REGEX_INTERNAL_ERROR = -7
};

/* Generic JavaScript pattern + NUL-terminated flags (dgimsuvy, or NULL).
 * Returns 0 on failure; inspect the calling thread's last error.
 * timeout_ms == 0 selects 250 ms. Allocation budget: 64 MiB per operation.
 */
uintptr_t BiliRegexCompile(const char *pattern, uint32_t pattern_bytes,
                          const char *flags, uint32_t timeout_ms);

/* Bilibili web rule: parse /^\/(.+)\/([img]{0,3})$/, attempt its body/flags,
 * and fall back to compiling the complete original rule without flags.
 */
uintptr_t BiliRegexCompileRule(const char *rule, uint32_t rule_bytes,
                              uint32_t timeout_ms);
int BiliRegexTest(uintptr_t handle, const char *text, uint32_t text_bytes,
                  uint32_t timeout_ms);
int BiliRegexFree(uintptr_t handle); /* 0 is accepted; nonzero handles freed once. */
/* A set borrows compiled handles. Populate before sharing across threads;
 * never change/free it or its rules during TestSet. NULL rules are skipped.
 * TestSet converts text once, tests in slot order, and stops at first match.
 * timeout_ms applies to each rule, as in repeated individual Test calls.
 */
uintptr_t BiliRegexCreateSet(uint32_t capacity);
int BiliRegexSetRule(uintptr_t set, uint32_t index, uintptr_t handle);
int BiliRegexTestSet(uintptr_t set, const char *text, uint32_t text_bytes,
                     uint32_t timeout_ms);
int BiliRegexFreeSet(uintptr_t set); /* Does not free the borrowed rules. */
int BiliRegexGetLastErrorRule(void); /* Zero-based slot, or -1 if unknown. */
int BiliRegexGetLastErrorCode(void);
const char *BiliRegexGetLastError(void); /* thread-local; copy before next call */
uint32_t BiliRegexGetAbiVersion(void); /* currently 1 */
const char *BiliRegexGetEngineVersion(void);

#ifdef __cplusplus
}
#endif
#endif
