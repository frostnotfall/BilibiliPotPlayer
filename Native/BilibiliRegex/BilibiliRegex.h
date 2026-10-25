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

/* pakku-compatible chronological stream (single caller per handle).
 * Feed returns a zero-based group number, or -1 on failure. Groups expire
 * relative to their first timestamp; matching crosses normal display modes.
 * Text is read only after the final Feed, and is borrowed until Free.
 * Weight is a compatibility no-op. Select returns a font size or -1, and
 * never deletes for density. packed contains
 * font size in bits 0..11, weight in 12..15, enlarge/shrink in bits 16/17.
 * The density window is 5000 ms, used only for automatic shrinking.
 */
uintptr_t BiliDanmakuCreate(uint32_t window_ms);
int BiliDanmakuFeed(uintptr_t handle, const char *text, uint32_t text_bytes, uint32_t time_ms);
const char *BiliDanmakuText(uintptr_t handle, uint32_t group);
int BiliDanmakuWeight(uintptr_t handle, uint32_t weight, uint32_t count);
int BiliDanmakuSelect(uintptr_t handle, const char *text, uint32_t text_bytes,
                      uint32_t time_ms, uint32_t packed, uint32_t peers);
/* Prepare applies enlargement/shrink (minimum 16 when shrink enabled) but
 * neither filters nor counts the candidate. Commit records shrink density:
 * 1=success, -1=error. It never deletes. Complete size preparation before
 * spatial layout. Next Prepare discards uncommitted work. Commit consumes a
 * candidate once; Select above is a compatibility shortcut for size only.
 */
int BiliDanmakuPrepare(uintptr_t handle, const char *text, uint32_t text_bytes,
                       uint32_t time_ms, uint32_t packed, uint32_t peers);
int BiliDanmakuCommit(uintptr_t handle);
/* Actual capacity selection: initialize once after size preparation. Place
 * groups in descending merge-count/weight priority at their original times.
 * Nonchronological reservations check collisions with past/future events.
 * height includes the same row spacing for every mode. 0=no room,
 * UINTPTR_MAX=error; otherwise 1+(centerX<<32)+topY (X only used for top).
 * Top and scrolling have independent capacity and may overlap. Top fills
 * centered rows before searching side gaps; top comments never overlap.
 */
int BiliDanmakuLayoutInit(uintptr_t handle,uint32_t area,uint32_t pitch,uint32_t duration_ms);
uintptr_t BiliDanmakuPlace(uintptr_t handle,uint32_t time_ms,uint32_t mode,uint32_t width,uint32_t height);
/* After all Place calls, refine accepted top positions in priority order.
 * Centered positions stay unchanged. Overflow positions prefer rectangles
 * clear of every accepted mode, otherwise retain the legal top-only position.
 * Pass centerX/topY decoded from Place; same return encoding, or UINTPTR_MAX.
 * Finish refinement before reading positions for ASS output; no more Place.
 */
uintptr_t BiliDanmakuRefineTop(uintptr_t handle,uint32_t time_ms,uint32_t centerX,uint32_t topY);
int BiliDanmakuFree(uintptr_t handle);
/* Configure one font per stream. Measure returns ASS-scaled pixel advance
 * (with a two-pixel guard), or -1. Both calls use explicit UTF-8 byte lengths.
 */
int BiliDanmakuFont(uintptr_t handle, const char *face, uint32_t bytes, uint32_t bold);
int BiliDanmakuMeasure(uintptr_t handle, const char *text, uint32_t bytes, uint32_t size);

#ifdef __cplusplus
}
#endif
#endif
