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

This is a resubmission of 0.3.1, which was rejected. All fixes address issues
flagged by CRAN's automated checks on the 0.3.0 release:

* Four C compiler warnings in vendored mdbtools source (ISO C ternary omission,
  void pointer arithmetic, signed char overflow) caused CRAN pre-test rejection
  on Windows and Debian. Fixed in src/mdbtools/src/libmdb/ (#12).

* Compilation failure on CRAN's macOS ARM64 platforms caused by `locale_t`
  being undefined. Fixed by including `<xlocale.h>` on Apple platforms via an
  `__APPLE__` guard in src/mdbtools/include/mdbtools.h (#14).

* Heap-use-after-free detected by AddressSanitizer (M1-SAN and Linux sanitizer).
  The SQL query error path in src/mdb_native.c held a raw pointer into a freed
  `MdbSQL` struct. The error string is now copied to a local buffer before
  cleanup (#15).

* Compilation failure on Linux with clang-22 (clang-ASAN platform): `vasprintf()`
  requires `_GNU_SOURCE` on Linux/glibc. Added `-D_GNU_SOURCE` to PKG_CPPFLAGS
  in src/Makevars.in (#16).
