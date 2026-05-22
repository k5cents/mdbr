#' Get path to mdbr example
#'
#' mdbr comes bundled with a sample file from the
#' [nycflights13](https://github.com/tidyverse/nycflights13) package in its
#' inst/extdata directory. This function make it easy to access.
#'
#' @param path path to the Microsoft Access file.
#' @return A character string with the full path to the bundled example file.
#' @examples
#' mdb_example()
#' @export
mdb_example <- function(path = "nycflights13.mdb") {
  if (!is.character(path)) {
    dir(system.file("extdata", package = "mdbr"))
  } else {
    system.file("extdata", path, package = "mdbr", mustWork = TRUE)
  }
}
