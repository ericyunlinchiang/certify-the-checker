/* Linked only into the coverage build: write coverage data even if the program crashes. */
#include <signal.h>
#include <unistd.h>
extern void __gcov_dump(void);
static void on_crash(int sig) { __gcov_dump(); _exit(128 + sig); }
__attribute__((constructor)) static void install(void) {
  signal(SIGSEGV, on_crash); signal(SIGABRT, on_crash); signal(SIGBUS, on_crash); signal(SIGFPE, on_crash);
}
