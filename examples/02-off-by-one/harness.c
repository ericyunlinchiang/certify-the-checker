/* One input class per run: ./x normal (n=8) | ./x boundary (n=16, exactly the capacity) */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
int copy_items(const uint8_t *buf, size_t len);
int main(int argc, char **argv) {
  uint8_t b[64]; memset(b, 7, sizeof b);
  b[0] = (argc > 1 && strcmp(argv[1], "boundary") == 0) ? 16 : 8;
  int rc = copy_items(b, 1 + (size_t)b[0]); printf("rc=%d\n", rc < 0 ? rc : 0); return 0;
}
