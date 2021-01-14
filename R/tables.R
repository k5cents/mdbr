#' List tables in a Microsoft Access database
#'
#' Used to find table names for `read_mdb()`.
#'
#' @param file Path to the Microsoft Access file.
#' @return A character vector of table names.
#' @export
mdb_tables <- function(file) {
  check_mdb_tools()
  x <- system2(
    command = "mdb-tables",
    args = c(file, "-d '\n'"),
    stdout = TRUE
  )
  x[nzchar(x)]
}
