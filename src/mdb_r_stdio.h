#ifndef MDBR_R_STDIO_H
#define MDBR_R_STDIO_H

#include <stdarg.h>
#include <stdio.h>

#ifndef MDBR_NO_STDIO_WRAP
FILE *mdbr_r_stdout(void);
FILE *mdbr_r_stderr(void);
int mdbr_r_printf(const char *format, ...);
int mdbr_r_vprintf(const char *format, va_list ap);
int mdbr_r_fprintf(FILE *stream, const char *format, ...);
int mdbr_r_vfprintf(FILE *stream, const char *format, va_list ap);
int mdbr_r_puts(const char *s);
int mdbr_r_putchar(int c);
int mdbr_r_fputs(const char *s, FILE *stream);
int mdbr_r_fputc(int c, FILE *stream);
int mdbr_r_fflush(FILE *stream);
void mdbr_r_exit(int status);

#ifdef stdout
#undef stdout
#endif
#ifdef stderr
#undef stderr
#endif

#define stdout mdbr_r_stdout()
#define stderr mdbr_r_stderr()

#define printf(...) mdbr_r_printf(__VA_ARGS__)
#define vprintf(...) mdbr_r_vprintf(__VA_ARGS__)
#define fprintf(...) mdbr_r_fprintf(__VA_ARGS__)
#define vfprintf(...) mdbr_r_vfprintf(__VA_ARGS__)
#define puts(...) mdbr_r_puts(__VA_ARGS__)
#define putchar(...) mdbr_r_putchar(__VA_ARGS__)
#define fputs(...) mdbr_r_fputs(__VA_ARGS__)
#define fputc(...) mdbr_r_fputc(__VA_ARGS__)
#define fflush(...) mdbr_r_fflush(__VA_ARGS__)
#define exit(...) mdbr_r_exit(__VA_ARGS__)
#endif

#endif