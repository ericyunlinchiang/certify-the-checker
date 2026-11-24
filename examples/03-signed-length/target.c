/* Signed length: a negative length passes the "too big" check and is then used as a size. */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#define MAX 64
int read_field(const uint8_t *buf, size_t len, uint8_t *out) {
    if (len < 4) return -1;
    int32_t n;
    memcpy(&n, buf, 4);
    if (n > MAX) return -1;
    if ((size_t)4 + (size_t)(uint32_t)n > len && n >= 0) return -1;
    memcpy(out, buf + 4, (size_t)n);
    return n;
}
