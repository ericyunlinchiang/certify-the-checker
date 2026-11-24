/* An error path that the usual tests never take: empty input frees the copy too early. */
#include <stdlib.h>
#include <string.h>
int store(const char *s, size_t len) {
    char *copy = malloc(len + 1);
    if (!copy) return -1;
    memcpy(copy, s, len);
    copy[len] = 0;
    if (len == 0) {
        free(copy);
    }
    int first = (int)copy[0];
    free(copy);
    return first;
}
