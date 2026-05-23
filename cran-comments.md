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

This is a patch release fixing a heap-use-after-free detected by AddressSanitizer
on CRAN's M1-SAN and Linux sanitizer checks (reported by CRAN during 0.3.1 review):

* In `src/mdb_native.c`, the SQL query error path stored a raw pointer into
  the `MdbSQL` struct's `error_msg` field (`mdb_sql_last_error()` is a macro
  that returns `(sql)->error_msg`), then freed the struct via `mdb_sql_exit()`,
  then passed the dangling pointer to `Rf_error()`. The error string is now
  copied into a local `char[1024]` buffer before `mdb_sql_exit()` is called,
  matching the safe pattern already used in the adjacent `mdb_sql_open` error
  path in the same function (#15).

All prior fixes from 0.3.1 (locale_t on macOS ARM64, four C compiler warnings)
are retained.
