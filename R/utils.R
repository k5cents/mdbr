has_mdb_tools <- function() {
  try <- suppressWarnings(tryCatch(
    expr = system2("mdb-ver", args = "-M", stderr = TRUE, stdout = TRUE),
    error = function(e) return(NULL)
  ))
  if (is.null(try)) {
    return(FALSE)
  } else {
    yes <- TRUE
    names(yes) <- try
    yes
  }
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
