# mdbr 0.3.0

* **Bundled mdbtools**: The mdbtools C library is now compiled and shipped with
  the package (`src/mdbtools/`). No external `mdbtools` installation is required.
* **DBI interface**: A full read-only DBI backend is now available. Use
  `DBI::dbConnect(mdb(), dbname = "path/to/file.mdb")` to open connections and
  standard DBI verbs (`dbReadTable()`, `dbGetQuery()`, `dbListTables()`, etc.).
* **New helper functions** from the bundled library:
  - `mdb_sql()` — run SQL queries directly against an MDB/ACCDB file.
  - `mdb_queries()` — list saved Access queries and retrieve their SQL.
  - `mdb_count()` — count rows in a table, optionally with a `WHERE` clause.
  - `mdb_schema()` — generate DDL (CREATE TABLE) schema in various SQL dialects with `mode = "ddl"`.
  - `mdb_ver()` — return the file format or the mdbtools library version.
  - `mdb_array()` — export a table as a named list of column vectors.
  - `mdb_export()` — export a table to CSV or SQL INSERT statements.
  - `mdb_json()` — export a table to JSON.
  - `mdb_header()` — return a structural summary (version, tables, queries).
  - `mdb_hexdump()` — hexadecimal dump of MDB file bytes.
  - `mdb_import()` — stub (read-only; always errors with a clear message).
  - `mdb_prop()` — retrieve MDB object properties.
  - `print.mdblist` — pretty-printer for `mdblist` objects.
* **No external dependencies**: `readr` has been removed. `read_mdb()` now reads
  tables directly via the bundled C library with automatic type coercion
  (integer, double, logical, POSIXct for DateTime, character otherwise).
* **`mdb_schema()`** now covers both column-type inspection (default,
  backward-compatible with mdbr <= 0.2.1) and DDL generation (`mode = "ddl"`)
* **Backward-compatible**: `read_mdb()`, `export_mdb()`, `mdb_tables()`,
  and `mdb_example()` function signatures are unchanged.
* `mdb_tables()` gains additional optional arguments (`system`, `type`,
  `show_type`, `as_text`, `single_column`, `delimiter`) matching the `mdb-tables`
  CLI surface.
* **`read_mdb()`** now returns a `tibble`. The `col_types` and `...` arguments
  are deprecated with a lifecycle warning; they had no effect with the native
  read path.
* **CI**: macOS and Windows are now part of the check matrix; no external
  mdbtools install step is needed.
* Bruno Tremblay (Boostao) added as co-author for the DBI interface and
  bundled mdbtools integration (originally developed in the `mdbtoolr` package).

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
