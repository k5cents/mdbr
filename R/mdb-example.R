#' Get path to mdbr example
#'
#' mdbr comes bundled with a sample file from the
#' [nycflights13](https://github.com/hadley/nycflights13) package in its
#' inst/extdata directory. This function make it easy to access.
#'
#' @param path path to the Microsoft Access file.
#' @examples
#' file.size(mdb_example())
#' @export
mdb_example <- function(path = "nycflights13.mdb") {
  if (!is.character(path)) {
    dir(system.file("extdata", package = "mdbr"))
  } else {
    system.file("extdata", path, package = "mdbr", mustWork = TRUE)
  }
}
