/* One input class per run: ./x normal (3 values) | ./x empty (0 values) */
#include <stdio.h>
#include <string.h>
#include <stddef.h>
int average(const int *v, size_t n);
int main(int argc, char **argv) {
  int v[3] = {1, 2, 3};
  size_t n = (argc > 1 && strcmp(argv[1], "empty") == 0) ? 0 : 3;
  printf("rc=%d\n", average(v, n) < 0 ? -1 : 0); return 0;
}
