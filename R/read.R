#' Read a table as data frame
#'
#' Reads a table directly from a Microsoft Access database using the bundled
#' mdbtools C library. Column types are inferred from the MDB schema:
#' integer, double, logical, [POSIXct][base::DateTimeClasses] for DateTime
#' columns, and character otherwise.
#'
#' @param file Path to the Microsoft Access file.
#' @param table Name of the table, list with [mdb_tables()].
#' @param col_names Logical; when `FALSE` columns are named `V1`, `V2`, etc.
#' @param col_types `r lifecycle::badge("deprecated")` Ignored. Type coercion
#'   is now handled automatically by the native reader.
#' @param ... `r lifecycle::badge("deprecated")` Ignored. Extra arguments were
#'   previously forwarded to [readr::read_delim()], which is no longer used.
#' @return A [tibble][tibble::tibble].
#' @importFrom lifecycle deprecate_warn
#' @importFrom tibble as_tibble
#' @examples
#' \dontrun{
#' read_mdb(mdb_example(), "Airlines")
#' }
#' @export
read_mdb <- function(file, table, col_names = TRUE, col_types = NULL, ...) {
  if (missing(table)) {
    stop("Must define a table name, list with mdb_tables()", call. = FALSE)
  }
  if (!is.null(col_types)) {
    lifecycle::deprecate_warn(
      when = "0.3.0",
      what = "read_mdb(col_types)",
      details = "Column types are now inferred automatically by the native reader."
    )
  }
  if (...length() > 0) {
    lifecycle::deprecate_warn(
      when = "0.3.0",
      what = "read_mdb(...)",
      details = "Extra arguments were previously forwarded to readr::read_delim(), which is no longer used."
    )
  }
  path <- .mdb_normalize_path(file)
  raw <- .native_read_table(path, as.character(table))
  df <- .as_data_frame(raw)
  df <- .coerce_mdb_data_frame(df, raw)
  if (!isTRUE(col_names)) {
    names(df) <- paste0("V", seq_along(df))
  }
  tibble::as_tibble(df)
}
