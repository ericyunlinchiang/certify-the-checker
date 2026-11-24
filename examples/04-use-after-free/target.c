/* Use after free on an error path that only runs for one kind of input. */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
int handle(const uint8_t *buf, size_t len) {
    uint8_t *p = calloc(32, 1);
    if (!p) return -1;
    int bad = 0;
    if (len > 0 && buf[0] == 0xFF) { free(p); bad = 1; }
    int v = 0;
    if (len > 1 && buf[1] == 0xEE) v = p[0];
    if (!bad) free(p);
    return v + bad;
}
