#' Create an mdbr DBI Driver
#'
#' `mdb()` is the canonical DBI-style constructor for connecting to Microsoft
#' Access '.mdb' and '.accdb' files.
#'
#' @return A DBI driver for '.mdb' and '.accdb' files.
#' @examples
#' db <- mdb_example()
#' conn <- DBI::dbConnect(mdb(), dbname = db)
#' DBI::dbListTables(conn)
#' DBI::dbDisconnect(conn)
#' @useDynLib mdbr
#' @importFrom methods new setClass setMethod
#' @importFrom DBI dbConnect dbDisconnect dbIsValid dbListTables dbListObjects
#'   dbExistsTable dbListFields dbReadTable dbQuoteIdentifier dbSendQuery
#'   dbGetQuery dbExecute dbFetch dbHasCompleted dbClearResult SQL
#'   dbCanConnect
#' @export
mdb <- function() {
  methods::new("MdbDriver")
}

methods::setClass("MdbDriver", contains = "DBIDriver")

methods::setClass(
  "MdbConnection",
  contains = "DBIConnection",
  slots = c(
    path = "character",
    open = "logical"
  )
)

methods::setClass(
  "MdbResult",
  contains = "DBIResult",
  slots = c(
    data = "data.frame",
    position = "integer",
    completed = "logical"
  )
)

methods::setMethod(
  "dbCanConnect",
  "MdbDriver",
  function(drv, ...) {
    tryCatch(
      {
        conn <- DBI::dbConnect(drv, ...)
        on.exit(DBI::dbDisconnect(conn), add = TRUE)
        TRUE
      },
      error = function(e) {
        FALSE
      }
    )
  }
)

methods::setMethod(
  "dbConnect",
  "MdbDriver",
  function(drv, dbname, ...) {
    if (missing(dbname) || !is.character(dbname) || length(dbname) != 1L) {
      stop("`dbname` must be a single '.mdb' or '.accdb' path.", call. = FALSE)
    }

    path <- normalizePath(dbname, mustWork = TRUE)
    methods::new("MdbConnection", path = path, open = TRUE)
  }
)

methods::setMethod(
  "dbConnect",
  "character",
  function(drv, ...) {
    if (.is_mdb_path(drv)) {
      return(DBI::dbConnect(mdb(), dbname = drv, ...))
    }

    stop(
      "When using a character first argument, provide an '.mdb' or '.accdb' path, ",
      "or call DBI::dbConnect(mdb(), dbname = ...).",
      call. = FALSE
    )
  }
)

methods::setMethod(
  "dbDisconnect",
  "MdbConnection",
  function(conn, ...) {
    conn@open <- FALSE
    TRUE
  }
)

methods::setMethod(
  "dbIsValid",
  "MdbConnection",
  function(dbObj, ...) {
    isTRUE(dbObj@open) && file.exists(dbObj@path)
  }
)

methods::setMethod(
  "dbListTables",
  "MdbConnection",
  function(conn, ...) {
    .require_valid_connection(conn)
    .native_list_tables(conn@path)
  }
)

methods::setMethod(
  "dbListObjects",
  "MdbConnection",
  function(conn, prefix = NULL, ...) {
    .require_valid_connection(conn)

    if (!is.null(prefix)) {
      return(data.frame(
        table = I(list()),
        is_prefix = logical(0),
        stringsAsFactors = FALSE
      ))
    }

    tables <- DBI::dbListTables(conn)
    queries <- .native_list_queries(conn@path)
    object_names <- c(tables, queries)
    object_types <- c(
      rep("table", length(tables)),
      rep("query", length(queries))
    )

    data.frame(
      table = I(as.list(object_names)),
      is_prefix = rep(FALSE, length(object_names)),
      .type = object_types,
      stringsAsFactors = FALSE
    )
  }
)

methods::setMethod(
  "dbExistsTable",
  c("MdbConnection", "character"),
  function(conn, name, ...) {
    .require_valid_connection(conn)
    .as_table_name(name) %in% DBI::dbListTables(conn)
  }
)

methods::setMethod(
  "dbExistsTable",
  c("MdbConnection", "Id"),
  function(conn, name, ...) {
    DBI::dbExistsTable(conn, .as_table_name(name))
  }
)

methods::setMethod(
  "dbListFields",
  c("MdbConnection", "character"),
  function(conn, name, ...) {
    .require_valid_connection(conn)
    table_name <- .as_table_name(name)
    .native_list_fields(conn@path, table_name)
  }
)

methods::setMethod(
  "dbListFields",
  c("MdbConnection", "Id"),
  function(conn, name, ...) {
    DBI::dbListFields(conn, .as_table_name(name))
  }
)

methods::setMethod(
  "dbReadTable",
  c("MdbConnection", "character"),
  function(conn, name, ...) {
    .require_valid_connection(conn)
    table_name <- .as_table_name(name)
    native <- .native_read_table(conn@path, table_name)
    .coerce_mdb_data_frame(.as_data_frame(native), native)
  }
)

methods::setMethod(
  "dbReadTable",
  c("MdbConnection", "Id"),
  function(conn, name, ...) {
    DBI::dbReadTable(conn, .as_table_name(name), ...)
  }
)

methods::setMethod(
  "dbQuoteIdentifier",
  c("MdbConnection", "character"),
  function(conn, x, ...) {
    DBI::SQL(paste0("[", gsub("]", "]]", x, fixed = TRUE), "]"))
  }
)

methods::setMethod(
  "dbQuoteIdentifier",
  c("MdbConnection", "Id"),
  function(conn, x, ...) {
    DBI::dbQuoteIdentifier(conn, as.character(unlist(x, use.names = FALSE)))
  }
)

methods::setMethod(
  "dbSendQuery",
  c("MdbConnection", "character"),
  function(conn, statement, ...) {
    .require_valid_connection(conn)
    native <- .native_run_query(conn@path, statement)
    data <- .coerce_mdb_data_frame(.as_data_frame(native), native)
    methods::new(
      "MdbResult",
      data = data,
      position = 0L,
      completed = nrow(data) == 0L
    )
  }
)

methods::setMethod(
  "dbGetQuery",
  c("MdbConnection", "character"),
  function(conn, statement, ...) {
    res <- DBI::dbSendQuery(conn, statement, ...)
    on.exit(DBI::dbClearResult(res), add = TRUE)
    DBI::dbFetch(res, n = -1)
  }
)

methods::setMethod(
  "dbExecute",
  c("MdbConnection", "character"),
  function(conn, statement, ...) {
    .require_valid_connection(conn)
    stop(
      "`dbExecute()` is not supported for MDB/ACCDB in read-only mode.",
      call. = FALSE
    )
  }
)

methods::setMethod(
  "dbFetch",
  "MdbResult",
  function(res, n = -1, ...) {
    start <- res@position + 1L
    total <- nrow(res@data)

    if (n < 0 || is.infinite(n)) {
      end <- total
    } else {
      end <- min(total, res@position + as.integer(n))
    }

    if (start > total) {
      res@completed <- TRUE
      return(res@data[0, , drop = FALSE])
    }

    chunk <- res@data[start:end, , drop = FALSE]
    res@position <- as.integer(end)
    res@completed <- end >= total
    chunk
  }
)

methods::setMethod(
  "dbHasCompleted",
  "MdbResult",
  function(res, ...) {
    isTRUE(res@completed)
  }
)

methods::setMethod(
  "dbIsValid",
  "MdbResult",
  function(dbObj, ...) {
    isTRUE(!dbObj@completed || dbObj@position <= nrow(dbObj@data))
  }
)

methods::setMethod(
  "dbClearResult",
  "MdbResult",
  function(res, ...) {
    res@completed <- TRUE
    TRUE
  }
)
