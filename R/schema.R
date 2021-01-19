#' Specification for columns in a table
#'
#' Used to determine the column types for [read_mdb()]. Passed to `col_types`
#' in `readr::read_delim()`.
#'
#' @param file Path to the Microsoft Access file.
#' @param table Name of the table, list with `mdb_tables()`.
#' @param condense Should [readr::cols_condense()] be called on the spec?
#' @return A readr cols specification list.
#' @importFrom readr as.col_spec
#' @examples
#' \dontrun{
#' mdb_schema(mdb_example(), "Flights", condense = TRUE)
#' }
#' @export
mdb_schema <- function(file, table, condense = FALSE) {
  check_mdb_tools()
  if (missing(table)) {
    stop("Must define a table name, list with mdb_tables()", call. = FALSE)
  }
  x <- system2(
    command = "mdb-schema",
    args = c(file, paste("-T", shQuote(table))),
    stdout = TRUE
  )
  x <- grep("^\t", x, value = TRUE)
  x <- gsub("\t{3}", "|", x)
  x <- gsub("^\t", "", x)
  x <- gsub(",\\s$", "", x)
  x <- gsub("\\[|\\]", "", x)
  x <- gsub("\\s\\(\\d+\\).*", "", x)
  x <- gsub("\\sNOT NULL", "", x)
  y <- matrix(
    data = unlist(strsplit(x, "\\|")),
    ncol = 2,
    byrow = TRUE
  )
  z <- vapply(y[, 2], list_switch, character(1), mdb_col_types)
  names(z) <- y[, 1]
  spec <- readr::as.col_spec(z)
  if (isTRUE(condense)) {
    readr::cols_condense(spec)
  } else {
    return(spec)
  }
}

# types from mdbtools/src/libmdb/backend.c
#   MDB Tools - A library for reading MS Access database files
#   Copyright (C) 2000-2011 Brian Bruns and others
mdb_col_types <- list(
  "Unknown 0x00" = "c",
  "Boolean" = "l",
  "Byte" = "i",
  "Integer" = "i",
  "Long Integer" = "i",
  "Currency" = "d",
  "Single" = "d",
  "Double" = "d",
  "DateTime" = "T",
  "Binary" = "c",
  "Text" = "c",
  "OLE" = "c",
  "Memo/Hyperlink" = "c",
  "Unknown 0x0d" = "c",
  "Unknown 0x0e" = "c",
  "Replication ID" = "c",
  "Numeric" = "d"
)

list_switch <- function(val, list) {
  do.call("switch", c(val, as.list(list)))
}
