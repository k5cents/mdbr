#' List tables in a Microsoft Access database
#'
#' @param file Path to the Microsoft Access file.
#' @return A character vector of table names.
#' @export
mdb_tables <- function(file) {
  check_mdb_tools()
  system2(
    command = Sys.which("mdb-tables"),
    args = c("-1", shQuote(file)),
    stdout = TRUE
  )
}
