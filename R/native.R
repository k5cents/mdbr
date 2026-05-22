# Internal native wrappers and helpers for the bundled mdbtools library.
# These functions call into the compiled C library (src/mdb_native.c).

.is_mdb_path <- function(x) {
  is.character(x) &&
    length(x) == 1L &&
    grepl("\\.(mdb|accdb)$", x, ignore.case = TRUE)
}

.as_table_name <- function(name) {
  if (inherits(name, "Id")) {
    vals <- unlist(name, use.names = FALSE)
    return(as.character(vals[[length(vals)]]))
  }
  as.character(name[[1]])
}

.require_valid_connection <- function(conn) {
  if (!DBI::dbIsValid(conn)) {
    stop("Invalid or closed MDB connection.", call. = FALSE)
  }
}

.native_list_tables <- function(path, system = FALSE) {
  .Call("mdbr_list_tables", PACKAGE = "mdbr", path, system)
}

.native_list_queries <- function(path) {
  .Call("mdbr_list_queries", PACKAGE = "mdbr", path)
}

.native_list_objects <- function(path, type_int) {
  .Call("mdbr_list_objects", PACKAGE = "mdbr", path, as.integer(type_int))
}

.native_list_fields <- function(path, table) {
  .Call("mdbr_list_fields", PACKAGE = "mdbr", path, table)
}

.native_table_num_rows <- function(path, table) {
  .Call("mdbr_table_num_rows", PACKAGE = "mdbr", path, table)
}

.native_read_table <- function(path, table) {
  .Call("mdbr_read_table", PACKAGE = "mdbr", path, table)
}

.native_run_query <- function(path, statement) {
  .Call("mdbr_run_query", PACKAGE = "mdbr", path, statement)
}

.native_get_query_sql <- function(path, query_name) {
  .Call("mdbr_get_query_sql", PACKAGE = "mdbr", path, query_name)
}

.native_print_schema <- function(
  path,
  table = NULL,
  backend = NULL,
  namespace = NULL,
  export_options = NULL
) {
  .Call(
    "mdbr_print_schema",
    PACKAGE = "mdbr",
    path,
    table,
    backend,
    namespace,
    export_options
  )
}

.native_mdbtools_version <- function() {
  .Call("mdbr_version", PACKAGE = "mdbr")
}

.native_file_format <- function(path) {
  .Call("mdbr_file_format", PACKAGE = "mdbr", path)
}

.native_prop_dump <- function(path, name, propcol = NULL) {
  .Call("mdbr_prop_dump", PACKAGE = "mdbr", path, name, propcol)
}

.trim_sql_semicolon <- function(x) {
  x <- trimws(x)
  sub(";\\s*$", "", x)
}

.expand_saved_query_statement <- function(path, statement) {
  pattern <- "^\\s*SELECT\\s+\\*\\s+FROM\\s+\\[([^\\]]+)\\]\\s*(?:LIMIT\\s+([0-9]+))?\\s*;?\\s*$"
  m <- regexec(pattern, statement, ignore.case = TRUE, perl = TRUE)
  hit <- regmatches(statement, m)[[1]]
  if (length(hit) == 0L) {
    return(statement)
  }

  query_name <- hit[[2]]
  limit <- if (length(hit) >= 3L) hit[[3]] else ""
  queries <- .native_list_queries(path)
  if (!query_name %in% queries) {
    return(statement)
  }

  query_sql <- .native_get_query_sql(path, query_name)
  query_sql <- .trim_sql_semicolon(query_sql)
  if (nzchar(limit)) {
    query_sql <- paste0(query_sql, " LIMIT ", limit)
  }
  query_sql
}

.as_data_frame <- function(x) {
  if (length(x) == 0L) {
    return(data.frame())
  }
  as.data.frame(
    x,
    check.names = FALSE,
    stringsAsFactors = FALSE,
    optional = TRUE
  )
}

.MDB_TYPE <- list(
  BOOL = 0x01L,
  BYTE = 0x02L,
  INT = 0x03L,
  LONGINT = 0x04L,
  MONEY = 0x05L,
  FLOAT = 0x06L,
  DOUBLE = 0x07L,
  DATETIME = 0x08L,
  BINARY = 0x09L,
  TEXT = 0x0aL,
  OLE = 0x0bL,
  MEMO = 0x0cL,
  REPID = 0x0fL,
  NUMERIC = 0x10L,
  COMPLEX = 0x12L
)

.normalize_string_na <- function(x) {
  x <- trimws(as.character(x))
  x[x == ""] <- NA_character_
  x
}

.coerce_logical <- function(x) {
  out <- rep(NA, length(x))
  if (!length(x)) {
    return(out)
  }
  y <- tolower(trimws(as.character(x)))
  false_vals <- c("0", "false", "f", "no", "n")
  true_vals <- c("1", "-1", "true", "t", "yes", "y")
  out[y %in% false_vals] <- FALSE
  out[y %in% true_vals] <- TRUE
  out[y == ""] <- NA
  out
}

.coerce_datetime <- function(x) {
  y <- .normalize_string_na(x)
  out <- rep(as.POSIXct(NA_real_, origin = "1970-01-01", tz = "UTC"), length(y))
  if (!length(y)) {
    return(out)
  }
  formats <- c(
    "%Y-%m-%d %H:%M:%OS",
    "%Y-%m-%d %H:%M",
    "%Y-%m-%d",
    "%m/%d/%Y %H:%M:%OS",
    "%m/%d/%Y %H:%M",
    "%m/%d/%Y",
    "%d/%m/%Y %H:%M:%OS",
    "%d/%m/%Y %H:%M",
    "%d/%m/%Y"
  )
  pending <- !is.na(y)
  for (fmt in formats) {
    if (!any(pending)) {
      break
    }
    parsed <- as.POSIXct(y[pending], format = fmt, tz = "UTC")
    ok <- !is.na(parsed)
    if (any(ok)) {
      idx <- which(pending)[ok]
      out[idx] <- parsed[ok]
      pending[idx] <- FALSE
    }
  }
  out
}

.coerce_column_by_type <- function(x, type_code) {
  type_code <- as.integer(type_code[[1]])
  if (is.na(type_code) || !length(x)) {
    return(x)
  }
  if (type_code == .MDB_TYPE$BOOL) {
    return(.coerce_logical(x))
  }
  if (type_code %in% c(.MDB_TYPE$BYTE, .MDB_TYPE$INT, .MDB_TYPE$LONGINT)) {
    return(suppressWarnings(as.integer(.normalize_string_na(x))))
  }
  if (
    type_code %in%
      c(.MDB_TYPE$MONEY, .MDB_TYPE$FLOAT, .MDB_TYPE$DOUBLE, .MDB_TYPE$NUMERIC)
  ) {
    return(suppressWarnings(as.numeric(.normalize_string_na(x))))
  }
  if (type_code == .MDB_TYPE$DATETIME) {
    return(.coerce_datetime(x))
  }
  x
}

.coerce_mdb_data_frame <- function(df, source) {
  type_codes <- attr(source, "mdb_col_types", exact = TRUE)
  if (is.null(type_codes) || !length(type_codes) || !ncol(df)) {
    return(df)
  }
  n <- min(length(type_codes), ncol(df))
  for (i in seq_len(n)) {
    df[[i]] <- .coerce_column_by_type(df[[i]], type_codes[[i]])
  }
  df
}

.mdb_normalize_path <- function(path) {
  normalizePath(path, mustWork = TRUE)
}

.mdb_connect <- function(path) {
  DBI::dbConnect(mdb(), dbname = .mdb_normalize_path(path))
}

.mdb_schema_options <- function(
  drop_table = FALSE,
  not_null = TRUE,
  default_values = FALSE,
  not_empty = FALSE,
  comments = TRUE,
  indexes = TRUE,
  relations = TRUE
) {
  opts <- 0L
  if (isTRUE(drop_table)) {
    opts <- bitwOr(opts, 1L)
  }
  if (isTRUE(not_null)) {
    opts <- bitwOr(opts, bitwShiftL(1L, 1L))
  }
  if (isTRUE(not_empty)) {
    opts <- bitwOr(opts, bitwShiftL(1L, 2L))
  }
  if (isTRUE(comments)) {
    opts <- bitwOr(opts, bitwShiftL(1L, 3L))
  }
  if (isTRUE(default_values)) {
    opts <- bitwOr(opts, bitwShiftL(1L, 4L))
  }
  if (isTRUE(indexes)) {
    opts <- bitwOr(opts, bitwShiftL(1L, 5L))
  }
  if (isTRUE(relations)) {
    opts <- bitwOr(opts, bitwShiftL(1L, 6L))
  }
  as.integer(opts)
}

.mdb_quote_ident <- function(x) {
  x <- as.character(x)
  x <- gsub("]", "]]", x, fixed = TRUE)
  paste0("[", x, "]")
}

.mdb_field_text <- function(
  x,
  null = "",
  no_quote = FALSE,
  quote = '"',
  escape = NULL,
  escape_invisible = FALSE
) {
  if (is.na(x)) {
    return(null)
  }
  value <- as.character(x)
  if (escape_invisible) {
    value <- gsub("\\\\", "\\\\\\\\", value, fixed = TRUE, useBytes = TRUE)
    value <- gsub("\\r", "\\\\r", value, fixed = TRUE, useBytes = TRUE)
    value <- gsub("\\n", "\\\\n", value, fixed = TRUE, useBytes = TRUE)
    value <- gsub("\\t", "\\\\t", value, fixed = TRUE, useBytes = TRUE)
  }
  if (isTRUE(no_quote)) {
    return(value)
  }
  if (is.null(escape)) {
    value <- gsub(
      quote,
      paste0(quote, quote),
      value,
      fixed = TRUE,
      useBytes = TRUE
    )
  } else {
    value <- gsub(
      quote,
      paste0(escape, quote),
      value,
      fixed = TRUE,
      useBytes = TRUE
    )
  }
  paste0(quote, value, quote)
}

.mdb_apply_datetime_formats <- function(
  df,
  date_format = "%Y-%m-%d",
  datetime_format = "%Y-%m-%d %H:%M:%S"
) {
  out <- df
  for (nm in names(out)) {
    if (inherits(out[[nm]], "POSIXct")) {
      out[[nm]] <- ifelse(
        is.na(out[[nm]]),
        NA_character_,
        format(out[[nm]], datetime_format, tz = "UTC")
      )
    } else if (inherits(out[[nm]], "Date")) {
      out[[nm]] <- ifelse(
        is.na(out[[nm]]),
        NA_character_,
        format(out[[nm]], date_format)
      )
    }
  }
  out
}

.mdb_apply_boolean_words <- function(df, boolean_words = FALSE) {
  out <- df
  for (nm in names(out)) {
    if (is.logical(out[[nm]])) {
      if (isTRUE(boolean_words)) {
        out[[nm]] <- ifelse(
          is.na(out[[nm]]),
          NA_character_,
          ifelse(out[[nm]], "TRUE", "FALSE")
        )
      } else {
        out[[nm]] <- ifelse(
          is.na(out[[nm]]),
          NA_integer_,
          ifelse(out[[nm]], 1L, 0L)
        )
      }
    }
  }
  out
}

.mdb_apply_unprintable <- function(df, no_unprintable = FALSE) {
  if (!isTRUE(no_unprintable)) {
    return(df)
  }
  out <- df
  for (nm in names(out)) {
    if (is.character(out[[nm]])) {
      out[[nm]] <- gsub("[^[:print:]\\t\\r\\n]", " ", out[[nm]], perl = TRUE)
    }
  }
  out
}

.mdb_delimited_text <- function(
  df,
  delimiter = "\t",
  row_delimiter = "\n",
  header = TRUE,
  null = "",
  no_quote = FALSE,
  quote = '"',
  escape = NULL,
  escape_invisible = FALSE
) {
  rows <- character(0)
  if (isTRUE(header)) {
    rows <- c(rows, paste(names(df), collapse = delimiter))
  }
  if (nrow(df) > 0L) {
    body <- apply(df, 1L, function(row) {
      vals <- vapply(
        row,
        .mdb_field_text,
        FUN.VALUE = character(1),
        null = null,
        no_quote = no_quote,
        quote = quote,
        escape = escape,
        escape_invisible = escape_invisible
      )
      paste(vals, collapse = delimiter)
    })
    rows <- c(rows, unname(body))
  }
  paste(rows, collapse = row_delimiter)
}

.mdb_sql_literal <- function(x) {
  if (is.na(x)) {
    return("NULL")
  }
  if (is.numeric(x)) {
    return(as.character(x))
  }
  if (is.logical(x)) {
    return(if (isTRUE(x)) "1" else "0")
  }
  val <- as.character(x)
  val <- gsub("'", "''", val, fixed = TRUE)
  paste0("'", val, "'")
}

.mdb_query_table <- function(path, table, n = -1L) {
  table <- as.character(table[[1]])
  sql <- sprintf("SELECT * FROM %s", .mdb_quote_ident(table))
  if (!is.null(n) && is.finite(n) && n >= 0) {
    sql <- paste(sql, "LIMIT", as.integer(n))
  }
  mdb_sql(path = path, statement = sql)
}

.mdb_read_sql_input <- function(input) {
  lines <- readLines(input, warn = FALSE)
  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]
  lines <- lines[!startsWith(lines, "#")]
  lines <- lines[tolower(lines) != "go"]
  script <- paste(lines, collapse = "\n")
  parts <- strsplit(script, ";", fixed = TRUE)[[1]]
  parts <- trimws(parts)
  parts <- parts[nzchar(parts)]
  parts
}

.mdb_example_nwind_path <- function() {
  candidates <- c(
    Sys.getenv("MDBR_EXAMPLE_DB", unset = ""),
    system.file(
      "testthat",
      "mdbtestdata",
      "data",
      "nwind.mdb",
      package = "mdbr"
    ),
    system.file(
      "tests",
      "testthat",
      "mdbtestdata",
      "data",
      "nwind.mdb",
      package = "mdbr"
    )
  )
  candidates <- unique(candidates[nzchar(candidates)])
  hits <- candidates[file.exists(candidates)]
  if (!length(hits)) {
    return("")
  }
  normalizePath(hits[[1]], mustWork = TRUE)
}

.as_mdblist <- function(x) {
  if (length(x) == 0L) {
    return(structure(x, class = "mdblist"))
  }
  if (is.null(names(x)) || any(!nzchar(names(x)))) {
    stop("`mdblist` entries must be named.", call. = FALSE)
  }
  structure(x, class = "mdblist")
}

#' Print Method For `mdblist`
#'
#' Pretty printer for multi-object text outputs returned by selected
#' `mdb_*` helpers when `as_list = TRUE` (default).
#'
#' @param x A `mdblist` object.
#' @param ... Unused.
#'
#' @return The input object, invisibly.
#' @export
print.mdblist <- function(x, ...) {
  n <- length(x)
  if (n == 0L) {
    cat("<mdblist[0]>\n")
    return(invisible(x))
  }
  for (i in seq_len(n)) {
    nm <- names(x)[[i]]
    cat("[", nm, "]\n", sep = "")
    val <- x[[i]]
    if (!is.null(val) && length(val) > 0L) {
      cat(as.character(val), sep = "\n")
    }
  }
  invisible(x)
}
