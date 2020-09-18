#' Create a cols() spec from schema
#'
#' Used to determine the column types for [read_mdb()].
#'
#' @param file Path to the Microsoft Access file.
#' @param table Name of the table, use [mdb_tables()].
#' @param condense Should [readr::cols_condense()] be called on the spec?
#' @return A readr cols specification list.
#' @importFrom readr as.col_spec
#' @examples
#' mdb_schema(mdb_example(), "Flights", condense = TRUE)
#' @export
mdb_schema <- function(file, table = NULL, condense = FALSE) {
  if (is.null(table)) {
    stop("Must define a table name, see mdb_tables()")
  }
  x <- system2(
    command = "mdb-schema",
    args = c(file, paste("-T", shQuote(table))),
    stdout = TRUE
  )
  x <- x[13:(grep("\\);", x) - 1)]
  x <- gsub("\t{3}", "|", x)
  x <- gsub("^\t", "", x)
  x <- gsub(",\\s$", "", x)
  x <- gsub("\\[|\\]", "", x)
  x <- strsplit(x, "\\|")
  vars <- sapply(x, `[`, 1)
  x <- sapply(x, `[`, 2)
  names(x) <- vars
  x[grep("DateTime", x)] <- "T"
  x[grep("Text", x)] <- "c"
  x[grep("Integer", x)] <- "i"
  x[grep("Double", x)] <- "d"
  x[grep("Boolean", x)] <- "l"
  x[grep("Currency", x)] <- "n"
  x[nchar(x) > 1] <- "c"
  spec <- readr::as.col_spec(x)
  if (condense) {
    readr::cols_condense(spec)
  } else {
    return(spec)
  }
}
