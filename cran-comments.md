## Test environments

* local: macOS 26.3 (aarch64), R 4.3.3
* GitHub Actions: ubuntu-latest, R release
* GitHub Actions: ubuntu-latest, R devel
* GitHub Actions: ubuntu-latest, R oldrel-1
* GitHub Actions: windows-latest, R release
* GitHub Actions: macos-latest, R release
* win-builder: R devel (devtools::check_win_devel())

## R CMD check results

0 errors | 0 warnings | 1 note (all platforms)

### Note (all platforms)

    checking for GNU extensions in Makefiles ... NOTE
    GNU make is a SystemRequirements.

The package vendors the mdbtools C library source and compiles it at install
time using GNU make extensions in src/Makevars. GNU make is declared in
SystemRequirements.

## Submission notes

This is a patch release fixing two issues detected by CRAN's sanitizer checks:

* Heap-use-after-free in `src/mdb_native.c`: the SQL query error path stored a
  raw pointer into `MdbSQL->error_msg` via `mdb_sql_last_error()` (a macro
  returning `(sql)->error_msg`), then freed the struct via `mdb_sql_exit()`,
  then passed the dangling pointer to `Rf_error()`. The error string is now
  copied into a local `char[1024]` buffer before cleanup (#15).

* Compilation failure on Linux with clang-22 (`clang-ASAN` platform):
  `vasprintf()` requires `_GNU_SOURCE` to be visible from glibc's `<stdio.h>`.
  Added `#define _GNU_SOURCE` guard at the top of
  `src/mdbtools/src/libmdb/fakeglib.c` before any system headers (#16).

All prior fixes from 0.3.1 are retained.
