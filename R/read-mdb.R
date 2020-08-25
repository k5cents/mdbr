#' Read a table as data frame
#'
#' Convert a table to a temporary text file pass to [readr::read_delim()].
#'
#' @param file Path to the Microsoft Access file.
#' @param table Name of the table, use `mdb_tables()`.
#' @param delim Single character used to separate fields within a record.
#' @param quote Single character used to quote strings. Defaults to `"`.
#' @param quote_escape A single character (or empty string) to escape double
#'   quotes with text columns. Defaults to doubling although backslashes are
#'   also used.
#' @param col_names Whether or not to suppress column names from the table.
#' @param date_format The format in which date columns are converted. MDB Tools
#'   uses the `strftime(3)` format, similar to [readr::parse_date()]. No need to
#'   specify whole string. Defaults to ISO8601.
#' @param ... Additional arguments passed to [readr::read_delim()], like
#'   `col_types` (see [mdb_schema()]) or additional `NA` values.
#' @return A data frame.
#' @importFrom readr read_delim
#' @export
read_mdb <- function(file, table = NULL, delim = ",", quote = '"',
                       quote_escape = '"', col_names = TRUE,
                       date_format = "%Y-%m-%d %H:%M:%S", ...) {
  if (is.null(table)) {
    stop("Must define a table name, see mdb_tables()")
  }
  col_arg <- if (!col_names) "-H" else ""
  x <- system2(
    command = "mdb-export",
    stdout = TRUE,
    args = c(
      file, shQuote(table),
      col_arg,
      paste("-d", shQuote(delim)),
      paste("-D", shQuote(date_format)),
      paste("-q", shQuote(quote)),
      paste("-X", shQuote(quote_escape))
    )
  )
  readr::read_delim(
    file = x,
    delim = delim,
    quote = quote,
    escape_backslash = (quote_escape == "\\"),
    escape_double = (quote_escape == '"'),
    col_names = col_names,
    ...
  )
}
