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
