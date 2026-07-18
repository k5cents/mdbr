## Test environments

* local: macOS 26.5 (aarch64), R 4.3.3
* GitHub Actions: ubuntu-latest, R release
* GitHub Actions: ubuntu-latest, R devel
* GitHub Actions: ubuntu-latest, R oldrel-1
* GitHub Actions: windows-latest, R release
* GitHub Actions: macos-latest, R release

## R CMD check results

0 errors | 0 warnings | 1 note (all platforms)

### Note (all platforms)

    checking for GNU extensions in Makefiles ... NOTE
    GNU make is a SystemRequirements.

The package vendors the mdbtools C library source and compiles it at install
time using GNU make extensions in src/Makevars. GNU make is declared in
SystemRequirements.

## Submission notes

This is a patch resubmission of 0.3.1, fixing a CRAN check warning introduced
by GCC 16 on Fedora 44 (r-devel-linux-x86_64-fedora-gcc):

* `assignment discards 'const' qualifier from pointer target type` in
  `src/mdbtools/src/libmdb/fakeglib.c` lines 56 and 64. The `found` variable
  in `g_strsplit()` was declared `char *` but assigned from `strstr()` called
  on a `const char *` argument. Changed to `const char *` (#17).
