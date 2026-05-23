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

This is a patch release fixing two build issues discovered after 0.3.0 was
accepted to CRAN:

* Four C compiler warnings in vendored mdbtools source (ISO C ternary omission,
  void pointer arithmetic, signed char overflow) caused CRAN pre-test rejection
  on Windows and Debian. These have been fixed by patching the four affected
  files in src/mdbtools/src/libmdb/.

* A compilation failure on CRAN's macOS ARM64 platforms (`r-release-macos-arm64`
  and `r-oldrel-macos-arm64`) caused by `locale_t` being undefined. Fixed by
  including `<xlocale.h>` on Apple platforms via a compile-time `__APPLE__`
  guard in src/mdbtools/include/mdbtools.h.

All fixes are in the vendored mdbtools C source and do not affect the R API.
