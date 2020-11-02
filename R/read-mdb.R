#' Read a table as data frame
#'
#' Convert a table to a temporary text file pass to [readr::read_delim()].
#'
#' @param file Path to the Microsoft Access file.
#' @param table Name of the table, use `mdb_tables()`.
#' @param stdout Where to save the exported text; accepted options are `TRUE`,
#'   which creates a character vector in memory, or a file path to write
#'   (defaults to [tempfile()]).
#' @param delim Single character used to separate fields within a record.
#' @param quote Single character used to quote strings. Defaults to `"`.
#' @param quote_escape A single character (or empty string) to escape double
#'   quotes with text columns. Defaults to doubling although backslashes are
#'   also used.
#' @param col_names Whether or not to suppress column names from the table.
#' @param date_format The format in which date columns are converted. MDB Tools
#'   uses the `strftime(3)` format, similar to [readr::parse_date()]. No need to
#'   specify whole string. Defaults to ISO8601.
#' @param col_types One of `NULL`, a [readr::cols()] specification, or a string.
#'   See `vignette("readr")` for more details. A generic [readr::cols()]
#'   specification can be made by [mdb_schema()] via the `mdb-schema` utility.
#' @param ... Additional arguments passed to [readr::read_delim()].
#' @return A data frame.
#' @importFrom readr read_delim
#' @examples
#' read_mdb(mdb_example(), "Flights")
#' @export
read_mdb <- function(file, table = NULL, stdout = tempfile(), delim = ",",
                     quote = '"', quote_escape = '"', col_names = TRUE,
                     date_format = "%Y-%m-%d %H:%M:%S",
                     col_types = mdb_schema(file, table), ...) {
  if (is.null(table)) {
    stop(
      "must define a table name, from mdb_tables():\n",
      paste("*", mdb_tables(file), collapse = "\n")
    )
  }
  if (is.character(stdout) && nchar(stdout) == 0) {
    stop("use export_mdb() to print to console")
  }
  col_arg <- if (!col_names) shQuote("-H") else ""
  output <- system2(
    command = "mdb-export",
    stdout = stdout,
    args = c(
      file, shQuote(table),
      col_arg,
      paste("-d", shQuote(delim)),
      paste("-D", shQuote(date_format)),
      paste("-q", shQuote(quote)),
      paste("-X", shQuote(quote_escape))
    )
  )
  if (isTRUE(stdout)) {
    input <- output
  } else {
    input <- stdout
  }
  readr::read_delim(
    file = input,
    delim = delim,
    quote = quote,
    escape_backslash = (quote_escape == "\\"),
    escape_double = (quote_escape == '"'),
    col_names = col_names,
    col_types = col_types,
    ...
  )
}
