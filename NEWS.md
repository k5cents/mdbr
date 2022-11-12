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
