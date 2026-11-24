/* One input class per run: ./x normal (n=8) | ./x negative (n=-1) */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
int read_field(const uint8_t *buf, size_t len, uint8_t *out);
int main(int argc, char **argv) {
  uint8_t b[16] = {0}, out[64]; int32_t n = (argc > 1 && strcmp(argv[1], "negative") == 0) ? -1 : 8;
  memcpy(b, &n, 4); int rc = read_field(b, n < 0 ? 16 : 12, out); printf("rc=%d\n", rc < 0 ? rc : 0); return 0;
}
