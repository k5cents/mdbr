#' Get path to mdbr example
#'
#' mdbr bundles the Northwind Access database in `inst/extdata`. This helper
#' returns its path, or lists bundled examples when `path = NULL`.
#'
#' @param path Name of the bundled Microsoft Access file, or `NULL` to list
#'   available examples.
#' @return A character string with the full path to the bundled example file.
#' @examples
#' mdb_example()
#' @export
mdb_example <- function(path = "nwind.mdb") {
  if (!is.character(path)) {
    dir(system.file("extdata", package = "mdbr"))
  } else {
    system.file("extdata", path, package = "mdbr", mustWork = TRUE)
  }
}
