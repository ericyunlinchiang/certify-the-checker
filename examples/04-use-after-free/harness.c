/* One input class per run: ./x normal | ./x error (error path only) | ./x error-read (error path, then a read) */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
int handle(const uint8_t *buf, size_t len);
int main(int argc, char **argv) {
  const char *c = argc > 1 ? argv[1] : "normal";
  uint8_t b[2] = {0x00, 0xEE};
  if (strcmp(c, "error") == 0) { b[0] = 0xFF; b[1] = 0x00; }
  if (strcmp(c, "error-read") == 0) { b[0] = 0xFF; b[1] = 0xEE; }
  int rc = handle(b, 2); printf("rc=%d\n", rc < 0 ? rc : 0); return 0;
}
