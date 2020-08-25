#' Find the column types of a table
#'
#' Used to determine the column types for [read_mdb()].
#'
#' @param file Path to the Microsoft Access file.
#' @param table Name of the table, use `mdb_tables()`.
#' @return A tibble of table columns and data types.
#' @importFrom readr read_delim
#' @export
mdb_schema <- function(file, table = NULL) {
  if (is.null(table)) {
    stop("Must define a table name, see mdb_tables()")
  }
  x <- system2(
    command = "mdb-schema",
    args = c(file, paste("-T", shQuote(table))),
    stdout = TRUE
  )
  x <- x[13:(grep("\\);", x) - 1)]
  x <- gsub("^\\s", "", x)
  x <- gsub("\t+", ",", x)
  x <- gsub(",\\s?$", "", x)
  x <- gsub("\\[|\\]", "", x)
  readr::read_delim(x, delim = ",", col_names = c("col", "type"))
}
