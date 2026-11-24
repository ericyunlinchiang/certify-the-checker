/* Illustrative target (author's own code; not a vulnerability report).
 * A record parser: [u16 count][count x u32 item]. The destination buffer size is computed
 * in a 16-bit type, so a large count TRUNCATES the size while the copy loop writes count*4 bytes.
 * Demonstrates: one real static analyzer (clang) stays silent (CLEAN) while another (gcc -fanalyzer)
 * flags it, and an execution oracle observes a heap out-of-bounds WRITE under an adversarial
 * input-class. The clean verdict is INPUT-CLASS-scoped and does not transfer. */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* returns 0 on success; the OOB (if any) happens inside, observable only by an execution oracle */
int parse_record(const uint8_t *buf, size_t buf_len) {
    if (buf_len < 2) return -1;
    uint16_t n;
    memcpy(&n, buf, 2);
    if ((size_t)2 + (size_t)n * 4u > buf_len) return -1;   /* SOURCE-read bound: fully guarded */
    uint16_t sz = (uint16_t)(n * 4);                        /* DEST size in 16-bit -> truncates */
    uint8_t *out = (uint8_t *)malloc(sz ? sz : 1);
    if (!out) return -1;
    for (uint16_t i = 0; i < n; i++) {
        memcpy(out + (size_t)i * 4, buf + 2 + (size_t)i * 4, 4); /* writes n*4 into sz-sized out */
    }
    free(out);
    return 0;
}
