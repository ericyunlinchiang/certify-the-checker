/* X = execution oracle (ASan). Drives parse_record on two input-classes. */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
int parse_record(const uint8_t *buf, size_t buf_len);
static uint8_t *mk(uint16_t n, size_t *len){ *len = 2 + (size_t)n*4; uint8_t*b=malloc(*len); memcpy(b,&n,2);
  for(size_t i=2;i<*len;i++) b[i]=(uint8_t)i; return b; }
int main(void){
  setvbuf(stdout, NULL, _IONBF, 0);
  /* BENIGN input-class: small n, no truncation (n*4 fits in u16) */
  { size_t L; uint8_t*b=mk(4,&L); int rc=parse_record(b,L); free(b);
    printf("benign      (n=4)      : rc=%d (covered; condition n*4>65535 NOT exercised)\n", rc); }
  /* ADVERSARIAL input-class: n such that n*4 overflows u16 (65536) -> sz truncates small */
  { size_t L; uint16_t n=16384; uint8_t*b=mk(n,&L);
    printf("adversarial (n=%u)  : entering parse_record (n*4=%u truncates u16)...\n", n, (unsigned)n*4);
    int rc=parse_record(b,L); free(b);
    printf("adversarial            : rc=%d (if we got here, no OOB observed)\n", rc); }
  printf("done.\n"); return 0;
}
