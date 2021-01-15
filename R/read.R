#' Read a table as data frame
#'
#' Convert a table to a temporary text file pass to [readr::read_delim()].
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
  system2(
    command = "mdb-export",
    stdout = tmp,
    args = c(
      ifelse(col_names, "", "-H"),
      paste("-D", shQuote("%F %T")),
      shQuote(file),
      shQuote(table)
    )
  )
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
