## Test environments

* local: macOS 26.3 (aarch64), R 4.3.3
* GitHub Actions: ubuntu-latest, R release
* GitHub Actions: ubuntu-latest, R devel
* GitHub Actions: ubuntu-latest, R oldrel-1
* GitHub Actions: windows-latest, R release
* GitHub Actions: macos-latest, R release
* win-builder: R devel (devtools::check_win_devel())

## R CMD check results

0 errors | 0 warnings | 1 note (local and GitHub Actions)
0 errors | 1 warning | 2 notes (win-builder R-devel)

### Note (all platforms)

    checking for GNU extensions in Makefiles ... NOTE
    GNU make is a SystemRequirements.

The package vendors the mdbtools C library source and compiles it at install
time using GNU make extensions in src/Makevars. GNU make is declared in
SystemRequirements.

### Note (win-builder only)

    checking CRAN incoming feasibility ... NOTE
    Possibly misspelled words in DESCRIPTION: schemas

"schemas" is used intentionally and is not misspelled.

### Warning (win-builder only)

The bundled mdbtools C source produces pedantic compiler warnings on Windows
(ISO C ternary omission in catalog.c, void pointer arithmetic in file.c and
table.c, signed char overflow in index.c). These are pre-existing issues in
the upstream mdbtools library (https://github.com/mdbtools/mdbtools), are not
present in the R package code itself, and do not affect installation or
functionality.

## Submission notes

This is a major feature release (0.2.1 -> 0.3.0):

* The mdbtools C library (v1.0.1) is now vendored in src/mdbtools/ and
  compiled at install time. No external mdbtools installation is required.
* A full read-only DBI backend is added via mdb().
* New helper functions: mdb_sql(), mdb_queries(), mdb_count(), mdb_json(),
  mdb_export(), mdb_ver(), mdb_array(), mdb_header(), mdb_hexdump(), mdb_prop().
* readr is no longer a hard dependency; col_types and ... arguments to
  read_mdb() are deprecated with lifecycle warnings.
* Bruno Tremblay added as contributor (DBI interface and bundled mdbtools).

The vendored mdbtools sources are licensed GPL-2+ (COPYING) and LGPL-2+
(COPYING.LIB), both compatible with the package's GPL-3 license.
