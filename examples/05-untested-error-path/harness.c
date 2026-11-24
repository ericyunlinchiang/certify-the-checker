/* The "usual test suite": only normal, non-empty input. */
#include <stdio.h>
#include <string.h>
int store(const char *s, size_t len);
int main(int argc, char **argv) {
  (void)argc; (void)argv;
  int rc = store("hello", strlen("hello")); printf("rc=%d\n", rc < 0 ? rc : 0); return 0;
}
