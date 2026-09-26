## Test environments

* local: macOS 27.0 (aarch64), R 4.3.3
* win-builder: R devel
* GitHub Actions: ubuntu-latest, R release
* GitHub Actions: ubuntu-latest, R devel
* GitHub Actions: ubuntu-latest, R oldrel-1
* GitHub Actions: windows-latest, R release
* GitHub Actions: macos-latest, R release
* GitHub Actions: clang AddressSanitizer

## R CMD check results

0 errors | 0 warnings | 1 note (all platforms)

### Note (all platforms)

    checking for GNU extensions in Makefiles ... NOTE
    GNU make is a SystemRequirements.

The package vendors the mdbtools C library source and compiles it at install
time using GNU make extensions in src/Makevars. GNU make is declared in
SystemRequirements.

## Reverse dependencies

There are no reverse dependencies.

## Submission notes

This is a minor release. It adds `mdb_stream_table()`, a native C cursor for
reading Access tables in bounded-memory batches through DBI, and replaces the
bundled nycflights13 example database with the Northwind sample database.
