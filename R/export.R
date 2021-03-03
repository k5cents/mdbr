#' Export an Access database table as a text file
#'
#' Convert the data of a table into a delimited text string. Save the string as
#' a character vector or write it to a text file. This direct conversion makes
#' it easy to read tables into R or a spreadsheet.
#'
#' @param file Path to the Microsoft Access file.
#' @param table Name of the table, list with `mdb_tables()`.
#' @param output Path or connection to write to. Passed to the `stdout` argument
#'   of [system2()]. Possible values are "", to the R console (the default),
#'   `NULL` or `FALSE` (discard output), `TRUE` (capture the output in a
#'   character vector) or a character string naming a file.
#' @param delim Delimiter used to separate values.
#' @param quote Single character used to quote strings. Defaults to `"`.
#' @param quote_escape The type of escaping to use for quoted values, one of
#'   `"double"`, `"backslash"` or `"none"`. You can also use `FALSE`, which is
#'   equivalent to "none". The default is `"double"`, which is expected format
#'   for Excel.
#' @param col_names If `FALSE`, column names will not be included at the top of
#'   the file. If `TRUE`, column names will be included.
#' @param eol The end of line character to use. Most commonly either `"\n"` for
#'   Unix style newlines, or `"\r\n"` for Windows style newlines.
#' @param date_format The format in which date columns are converted. MDB Tools
#'   uses the `strftime(3)` format, similar to [readr::parse_date()]. No need to
#'   specify whole string. Defaults to ISO8601.
#' @return Character string, invisible if path to file.
#' @examples
#' \dontrun{
#' export_mdb(mdb_example(), "Airlines", output = TRUE)
#' }
#' @export
export_mdb <- function(file, table, output = TRUE, delim = ",",
                       quote = "\"", quote_escape = "double", col_names = TRUE,
                       eol = "\n", date_format = "%Y-%m-%d %H:%M:%S") {
  check_mdb_tools()
  if (missing(table)) {
    stop("Must define a table name, list with mdb_tables()", call. = FALSE)
  }
  quote_escape <- switch(
    standardize_escape(quote_escape),
    double = "\"",
    backslash = "\\",
    none = ""
  )
  out <- system2(
    command = Sys.which("mdb-export"),
    stdout = output,
    args = c(
      ifelse(!col_names, shQuote("-H"), ""),
      paste("-d", shQuote(delim)),
      paste("-R", shQuote(eol)),
      paste("-D", shQuote(date_format)),
      paste("-q", shQuote(quote)),
      paste("-X", shQuote(quote_escape)),
      shQuote(file),
      shQuote(table)
    )
  )
  if (isTRUE(output)) {
    Encoding(out) <- "UTF-8"
    paste0(out, collapse = eol)
  } else if (file.exists(output)) {
    invisible(output)
  }
}

# from tidyverse/readr/R/write.R
standardize_escape <- function(x) {
  if (identical(x, FALSE)) {
    x <- "none"
  }

  escape_types <- c("double" = 1L, "backslash" = 2L, "none" = 3L)
  escape <- match.arg(tolower(x), names(escape_types))

  escape_types[escape]
}
