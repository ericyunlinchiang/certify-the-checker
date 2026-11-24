/* Drives parse_record with one input class per run: ./x normal | ./x large */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
int parse_record(const uint8_t *buf, size_t buf_len);
static uint8_t *mk(uint16_t n, size_t *len) { *len = 2 + (size_t)n * 4; uint8_t *b = malloc(*len); memcpy(b, &n, 2);
  for (size_t i = 2; i < *len; i++) b[i] = (uint8_t)i; return b; }
int main(int argc, char **argv) {
  uint16_t n = (argc > 1 && strcmp(argv[1], "large") == 0) ? 16384 : 4;  /* 16384*4 = 65536 wraps a 16-bit size */
  size_t L; uint8_t *b = mk(n, &L); int rc = parse_record(b, L); free(b); printf("rc=%d\n", rc); return 0;
}
