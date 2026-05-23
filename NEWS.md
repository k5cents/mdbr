# mdbr 0.3.2

* Fixed heap-use-after-free in `mdbr_run_query` (detected by AddressSanitizer
  on CRAN's M1-SAN and Linux sanitizer checks). When a SQL query failed,
  the error message was read from a pointer into the `MdbSQL` struct after the
  struct had been freed via `mdb_sql_exit()`. The error string is now copied
  into a local buffer before cleanup (#15).

# mdbr 0.3.1

* Fixed compilation failure on macOS ARM64 (CRAN `r-release-macos-arm64` and
  `r-oldrel-macos-arm64`). The vendored mdbtools source now correctly includes
  `<xlocale.h>` on Apple platforms, where `locale_t` is not exposed through
  `<locale.h>` alone under strict SDK settings (#14).

* Fixed four C compiler warnings in vendored mdbtools source that caused CRAN
  pre-test rejection (#12):
  - `catalog.c`: expanded GCC-only `?:` to standard ternary
  - `file.c`, `table.c`: cast `void*` to `char*` before pointer arithmetic
  - `index.c`: declared `idx_to_text` as `unsigned char[]` to hold `0x81`

# mdbr 0.3.0

* The `mdbtools` C library is now compiled and bundled with the package.
  No external `mdbtools` installation is required on any platform (#3).

* A full read-only DBI backend is now available via `mdb()` (#6):

  ```r
  con <- DBI::dbConnect(mdb(), dbname = "path/to/file.mdb")
  DBI::dbListTables(con)
  DBI::dbGetQuery(con, "SELECT * FROM [Orders] LIMIT 10;")
  DBI::dbDisconnect(con)
  ```

* New helper functions: `mdb_sql()`, `mdb_queries()`, `mdb_count()`,
  `mdb_json()`, `mdb_export()`, `mdb_ver()`, `mdb_array()`, `mdb_header()`,
  `mdb_hexdump()`, and `mdb_prop()`.

* `mdb_schema()` gains a `mode` argument for DDL output in multiple SQL
  dialects in addition to the existing readr col-spec mode.

* `read_mdb()` now reads tables via the bundled C library and returns a tibble.
  The `col_types` and `...` arguments are deprecated with a lifecycle warning.

* `readr` is no longer a hard dependency. If you use `read_mdb()` and rely on
  `readr` being available, add it explicitly to your own dependencies.

* Thanks to [Bruno Tremblay](https://github.com/meztez) for contributing the
  bundled mdbtools source, the DBI backend, and the expanded helper functions
  (#9).

# mdbr 0.2.1

* Update maintainer email, website URL, and GitHub URL.

# mdbr 0.2.0

* Functions now quote their input files with `shQuote()`. (#7)
* `export_mdb()` now mirrors `readr::format_csv()` with arguments, etc.
* Remove all formatting arguments for `read_mdb()` (with smart hidden defaults).
* Add more schema types with readr equivalents. 
* Write schema to a matrix in-memory rather than a temporary file.
* Always read data from a temporary file instead of `stdout` option.
* Add better checking if mdbtools is installed.

# mdbr 0.1.1

* `read_mdb()` now has `stdout()` which can take `TRUE` or a file path.
* Examples and tests don't run on CRAN.

# mdbr 0.1.0

* Added a `NEWS.md` file to track changes to the package.
* Cover the most basic functions from mdbtools:
    * List tables in database
    * Export table as delimited file
    * Read delimited file as dataframe
    * Convert simple schema to readr spec
