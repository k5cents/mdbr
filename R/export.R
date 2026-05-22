#' Export an Access database table as a text file
#'
#' Convert the data of a table into a delimited text string. Save the string as
#' a character vector or write it to a text file. This direct conversion makes
#' it easy to read tables into R or a spreadsheet.
#'
#' @param file Path to the Microsoft Access file.
#' @param table Name of the table, list with `mdb_tables()`.
#' @param output Controls where output is sent. `TRUE` (the default) returns
#'   the output as a character vector. `""` prints to the R console and returns
#'   invisibly. `NULL` or `FALSE` discards the output. A character string is
#'   treated as a file path to write to, returning the path invisibly.
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
export_mdb <- function(
  file,
  table,
  output = TRUE,
  delim = ",",
  quote = "\"",
  quote_escape = "double",
  col_names = TRUE,
  eol = "\n",
  date_format = "%Y-%m-%d %H:%M:%S"
) {
  if (missing(table)) {
    stop("Must define a table name, list with mdb_tables()", call. = FALSE)
  }
  if (identical(output, FALSE) || is.null(output)) {
    return(invisible(NULL))
  }
  quote_escape <- switch(
    standardize_escape(quote_escape),
    double = "\"",
    backslash = "\\",
    none = ""
  )
  escape_arg <- if (nzchar(quote_escape)) quote_escape else NULL

  out <- mdb_export(
    path = file,
    table = table,
    no_header = !col_names,
    delimiter = delim,
    row_delimiter = eol,
    quote = quote,
    escape = escape_arg,
    datetime_format = date_format
  )

  if (isTRUE(output)) {
    return(out)
  } else if (identical(output, "")) {
    cat(out)
    return(invisible(out))
  } else {
    con <- file(output, open = "wb")
    on.exit(close(con), add = TRUE)
    writeLines(out, con = con, useBytes = TRUE)
    return(invisible(output))
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
