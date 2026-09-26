#' Open a streaming cursor for an Access table
#'
#' `mdb_stream_table()` opens a named table without reading its rows. Fetch
#' batches with [DBI::dbFetch()] and close with [DBI::dbClearResult()].
#' The cursor is also closed by garbage collection, but explicit clearing is
#' recommended. Opening does not scan rows. `dbFetch(n)` reads at most `n`
#' rows; `n = 0` does not advance, and `n = -1` reads all remaining rows into
#' memory. After exhaustion a typed zero-row frame is returned. The result
#' remains valid until cleared; after clearing it is invalid. Memory during
#' finite fetches is bounded by the batch and the size of an individual field
#' (including text conversion buffers). Binary and OLE columns are lists of
#' raw vectors; SQL NULL is represented by `NULL` in those lists. Other NULLs
#' are typed `NA`. Unsupported column types fail explicitly.
#'
#' @param conn An open mdbr DBI connection.
#' @param table A table name (or a DBI `Id`).
#' @return A DBI result; fetch with `DBI::dbFetch(result, n = 1000L)`.
#' @examples
#' \dontrun{
#' con <- DBI::dbConnect(mdb(), dbname = mdb_example())
#' res <- mdb_stream_table(con, "Shippers")
#' DBI::dbFetch(res, n = 100L)
#' DBI::dbClearResult(res)
#' DBI::dbDisconnect(con)
#' }
#' @export
mdb_stream_table <- function(conn, table) {
  .require_valid_connection(conn)
  table <- .as_table_name(table)
  cursor <- .native_cursor_open(conn@path, table)
  ok <- FALSE
  on.exit(if (!ok) .native_cursor_close(cursor), add = TRUE)
  raw <- .native_cursor_fetch(cursor, 0L)
  prototype <- .cursor_data_frame(raw)
  state <- new.env(parent = emptyenv())
  state$valid <- TRUE
  state$completed <- FALSE
  state$position <- 0L
  result <- methods::new(
    "MdbResult",
    data = prototype,
    position = 0L,
    completed = FALSE,
    cursor = cursor,
    state = state,
    prototype = prototype
  )
  ok <- TRUE
  result
}

.cursor_data_frame <- function(raw, prototype = NULL) {
  types <- attr(raw, "mdb_col_types")
  if (is.null(prototype)) {
    columns <- lapply(seq_along(raw), function(i) {
      type <- types[[i]]
      if (type %in% c(.MDB_TYPE$OLE, .MDB_TYPE$BINARY)) {
        return(I(list()))
      }
      .coerce_column_by_type(character(), type)
    })
    names(columns) <- names(raw)
    prototype <- .as_data_frame(columns)
  }
  if (!length(raw) || !length(raw[[1L]])) {
    return(prototype)
  }
  columns <- lapply(seq_along(raw), function(i) {
    type <- types[[i]]
    x <- raw[[i]]
    if (type %in% c(.MDB_TYPE$OLE, .MDB_TYPE$BINARY)) {
      return(I(x))
    }
    text <- vapply(
      x,
      function(value) {
        if (is.null(value)) NA_character_ else value
      },
      character(1)
    )
    .coerce_column_by_type(text, type)
  })
  names(columns) <- names(raw)
  .as_data_frame(columns)
}
