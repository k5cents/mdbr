#' List tables in a database file
#'
#' Used to find table names for `read_mdb()`.
#'
#' @param file Path to the Microsoft Access file.
#' @return A character vector of table names.
mdb_tables <- function(file) {
  x <- system2(
    command = "mdb-tables",
    args = c(file, "-d '\n'"),
    stdout = TRUE
  )
  x[-length(x)]
}
