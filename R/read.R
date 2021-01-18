#' Read a table as data frame
#'
#' Use [export_mdb()] to write a table as a temporary CSV file, which is then
#' read as a data frame using [readr::read_delim()].
#'
#' @param file Path to the Microsoft Access file.
#' @param table Name of the table, list with `mdb_tables()`.
#' @param col_names Whether or not to suppress column names from the table.
#' @param col_types One of `NULL`, a [readr::cols()] specification, or a string.
#'   See `vignette("readr")` for more details. Use `TRUE` to create a generic
#'   [readr::cols()] specification with [mdb_schema()].
#' @param ... Additional arguments passed to [readr::read_delim()].
#' @return A data frame.
#' @importFrom readr read_delim
#' @examples
#' \dontrun{
#' read_mdb(mdb_example(), "Airlines")
#' }
#' @export
read_mdb <- function(file, table, col_names = TRUE, col_types = NULL, ...) {
  check_mdb_tools()
  if (missing(table)) {
    stop("Must define a table name, list with mdb_tables()", call. = FALSE)
  }
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  export_mdb(file, table, output = tmp, col_names = col_names)
  if (isTRUE(col_types)) {
    message("Using mdb_schema() for column specification")
    col_types <- mdb_schema(file, table)
  }
  readr::read_delim(
    file = tmp,
    delim = ",",
    col_names = col_names,
    col_types = col_types,
    ...
  )
}
