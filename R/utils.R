has_mdb_tools <- function() {
  try <- tryCatch(
    expr = system2("mdb-tables", stderr = TRUE, stdout = TRUE),
    error = function(e) return(NULL)
  )
  is.null(try)
}

check_mdb_tools <- function() {
  if (isFALSE(has_mdb_tools())) {
    msg <- c(
      "MDB Tools are not installed",
      "See: https://github.com/mdbtools/mdbtools",
      "* Debian: apt install mdbtools",
      "* Homebrew: brew install mdbtools"
    )
    stop(paste(msg, collapse = "\n"), call. = FALSE)
  }
}
