has_mdb_tools <- function() {
  try <- tryCatch(
    expr = system2("mdb-tools", stderr = TRUE, stdout = TRUE),
    error = function(e) return(NULL)
  )
  !is.null(try)
}
