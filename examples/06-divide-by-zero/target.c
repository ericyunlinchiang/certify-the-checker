/* Not a memory bug: the average of an empty list divides by zero. */
#include <stddef.h>
int average(const int *v, size_t n) {
    long sum = 0;
    for (size_t i = 0; i < n; i++) sum += v[i];
    return (int)(sum / (long)n);
}
