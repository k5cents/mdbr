#define MDBR_NO_STDIO_WRAP
#include "mdb_r_stdio.h"

#include <R_ext/Print.h>
#include <R_ext/Error.h>

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static FILE *const MDBR_STDOUT_SENTINEL = (FILE *) (uintptr_t) 1u;
static FILE *const MDBR_STDERR_SENTINEL = (FILE *) (uintptr_t) 2u;
static int mdbr_r_printv(FILE *stream, const char *format, va_list ap);

FILE *mdbr_r_stdout(void) {
  return MDBR_STDOUT_SENTINEL;
}

FILE *mdbr_r_stderr(void) {
  return MDBR_STDERR_SENTINEL;
}

int mdbr_r_vprintf(const char *format, va_list ap) {
  return mdbr_r_printv(MDBR_STDOUT_SENTINEL, format, ap);
}

int mdbr_r_printf(const char *format, ...) {
  int out;
  va_list ap;

  va_start(ap, format);
  out = mdbr_r_vprintf(format, ap);
  va_end(ap);
  return out;
}

static int mdbr_r_printv(FILE *stream, const char *format, va_list ap) {
  int needed;
  va_list ap_copy;
  char *buffer;

  va_copy(ap_copy, ap);
  needed = vsnprintf(NULL, 0, format, ap_copy);
  va_end(ap_copy);

  if (needed < 0) {
    return needed;
  }

  buffer = (char *) malloc((size_t) needed + 1u);
  if (buffer == NULL) {
    return -1;
  }

  va_copy(ap_copy, ap);
  (void) vsnprintf(buffer, (size_t) needed + 1u, format, ap_copy);
  va_end(ap_copy);

  if (stream == MDBR_STDERR_SENTINEL) {
    REprintf("%s", buffer);
  } else {
    Rprintf("%s", buffer);
  }

  free(buffer);
  return needed;
}

int mdbr_r_vfprintf(FILE *stream, const char *format, va_list ap) {
  if (stream == MDBR_STDOUT_SENTINEL || stream == MDBR_STDERR_SENTINEL) {
    return mdbr_r_printv(stream, format, ap);
  }
  return vfprintf(stream, format, ap);
}

int mdbr_r_fprintf(FILE *stream, const char *format, ...) {
  int out;
  va_list ap;

  va_start(ap, format);
  out = mdbr_r_vfprintf(stream, format, ap);
  va_end(ap);
  return out;
}

int mdbr_r_fputs(const char *s, FILE *stream) {
  if (stream == MDBR_STDOUT_SENTINEL) {
    Rprintf("%s", s);
    return 1;
  }
  if (stream == MDBR_STDERR_SENTINEL) {
    REprintf("%s", s);
    return 1;
  }
  return fputs(s, stream);
}

int mdbr_r_puts(const char *s) {
  Rprintf("%s\n", s);
  return 1;
}

int mdbr_r_fputc(int c, FILE *stream) {
  char ch[2];
  ch[0] = (char) c;
  ch[1] = '\0';

  if (stream == MDBR_STDOUT_SENTINEL) {
    Rprintf("%s", ch);
    return c;
  }
  if (stream == MDBR_STDERR_SENTINEL) {
    REprintf("%s", ch);
    return c;
  }
  return fputc(c, stream);
}

int mdbr_r_putchar(int c) {
  char ch[2];
  ch[0] = (char) c;
  ch[1] = '\0';
  Rprintf("%s", ch);
  return c;
}

int mdbr_r_fflush(FILE *stream) {
  if (stream == MDBR_STDOUT_SENTINEL || stream == MDBR_STDERR_SENTINEL) {
    return 0;
  }
  return fflush(stream);
}

void mdbr_r_exit(int status) {
  Rf_error("mdbtools attempted to terminate the R process (exit status %d)", status);
}