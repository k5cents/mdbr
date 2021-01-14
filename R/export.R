#' Save a table as a text file
#'
#' Write a Microsoft Access table directly to a text file.
#'
#' @param file Path to the Microsoft Access file.
#' @param table Name of the table, use `mdb_tables()`.
#' @param path Path or connection to write to. Empty string prints to console.
#' @param delim Single character used to separate fields within a record.
#' @param quote Single character used to quote strings. Defaults to `"`.
#' @param quote_escape A single character (or empty string) to escape double
#'   quotes with text columns. Defaults to doubling although backslashes are
#'   also used.
#' @param col_names Whether or not to suppress column names from the table.
#' @param date_format The format in which date columns are converted. MDB Tools
#'   uses the `strftime(3)` format, similar to [readr::parse_date()]. No need to
#'   specify whole string. Defaults to ISO8601.
#' @return Invisibly, the path of the new file written.
#' @examples
#' \dontrun{
#' export_mdb(mdb_example(), "Airlines", path = TRUE)
#' }
#' @export
export_mdb <- function(file, table = NULL, path = "", delim = ",", quote = '"',
                       quote_escape = '"', col_names = TRUE,
                       date_format = "%Y-%m-%d %H:%M:%S") {
  check_mdb_tools()
  if (is.null(table)) {
    stop("Must define a table name, see mdb_tables()", call. = FALSE)
  }
  out <- system2(
    command = "mdb-export",
    stdout = path,
    args = c(
      ifelse(!col_names, shQuote("-H"), ""),
      paste("-d", shQuote(delim)),
      paste("-D", shQuote(date_format)),
      paste("-q", shQuote(quote)),
      paste("-X", shQuote(quote_escape)),
      shQuote(file),
      shQuote(table)
    )
  )
  if (isTRUE(path)) {
    return(out)
  } else if (file.exists(path)) {
    invisible(path)
  }
}
