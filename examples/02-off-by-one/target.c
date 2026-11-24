/* Off-by-one: the guard allows n == CAP, but the loop runs n+1 times. */
#include <stdint.h>
#include <string.h>
#define CAP 16
int copy_items(const uint8_t *buf, size_t len) {
    uint8_t dst[CAP];
    if (len < 1) return -1;
    size_t n = buf[0];
    if (n > CAP || len < 1 + n) return -1;
    for (size_t i = 0; i <= n; i++) {
        dst[i] = buf[1 + (i < n ? i : 0)];
    }
    return dst[0];
}
