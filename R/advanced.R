#' List Or Retrieve Queries In An MDB Database
#'
#' `mdb-queries` is a utility program distributed with MDB Tools.
#' Without `query`, it lists the names of all saved queries in the database.
#' With `query`, it returns the SQL text of the named query or queries.
#'
#' @param path Path to `.mdb`/`.accdb` file.
#' @param query Character vector of query names. When `NULL` (the default),
#'   the function lists available query names instead of fetching SQL.
#' @param list Logical; when `TRUE` (the default) and `query` is `NULL`,
#'   return the list of query names. Set to `FALSE` to suppress listing and
#'   return `character(0)`.
#' @param newline Logical; when `TRUE` and `as_text = TRUE`, collapse names
#'   with `"\n"` instead of `delimiter`.
#' @param delimiter Character scalar used to collapse query names when
#'   `as_text = TRUE`. Default `" "`.
#' @param as_text Logical; when `TRUE`, collapses the query name list into a
#'   single string using `delimiter` (or `"\n"` if `newline = TRUE`).
#' @param as_list Logical; defaults to `TRUE`. When `TRUE` and `query` is
#'   supplied, wraps the result in a named `mdblist` object.
#'
#' @return When `query` is `NULL`: a character vector of query names (or a
#'   collapsed string when `as_text = TRUE`). When `query` is supplied and
#'   `as_list = TRUE`: a named `mdblist` of SQL text strings, one per query.
#'   With a single query and `as_list = FALSE`: a character scalar.
#' @examples
#' db <- mdbr:::.mdb_example_nwind_path()
#' if (nzchar(db)) {
#'   mdb_queries(db)
#'   mdb_queries(db, "Orders Qry")
#' }
#' @export
mdb_queries <- function(
  path,
  query = NULL,
  list = TRUE,
  newline = FALSE,
  delimiter = " ",
  as_text = FALSE,
  as_list = TRUE
) {
  path <- .mdb_normalize_path(path)
  if (!is.null(query) && nzchar(as.character(query[[1]]))) {
    query <- as.character(query)
    query <- query[nzchar(query)]
    if (!length(query)) {
      return(character(0))
    }

    out <- stats::setNames(
      lapply(query, function(q) .native_get_query_sql(path, q)),
      query
    )
    out <- lapply(out, as.character)

    if (isTRUE(as_list)) {
      return(.as_mdblist(out))
    }

    if (length(out) > 1L) {
      return(out)
    }

    return(out[[1]])
  }
  if (!isTRUE(list)) {
    return(character(0))
  }
  out <- .native_list_queries(path)
  delim <- if (isTRUE(newline)) "\n" else delimiter
  if (isTRUE(as_text)) {
    return(paste(out, collapse = delim))
  }
  out
}

#' SQL Interface To MDB Tools
#'
#' `mdb-sql` is a utility program distributed with MDB Tools.
#' It allows querying of an MDB database using a limited SQL subset language.
#' The supported SQL is intentionally small: single-table queries, no aggregates,
#' and limited `WHERE` support.
#'
#' In addition to single statements, this wrapper accepts `input` files similar
#' to `mdb-sql -i file`, strips `go` batch terminators, and executes the script
#' one statement at a time.
#'
#' @param path Path to `.mdb`/`.accdb` file.
#' @param statement SQL statement text.
#' @param no_header Logical, equivalent to `-H/--no-header` (for text mode).
#' @param no_footer Logical, equivalent to `-F/--no-footer` (for text mode).
#' @param no_pretty_print Logical, equivalent to `-p/--no-pretty-print`.
#' @param delimiter Delimiter equivalent to `-d/--delimiter` in plain text mode.
#' @param input Input file equivalent to `-i/--input`.
#' @param output Output file equivalent to `-o/--output`.
#' @param as_text Logical; when `TRUE`, returns CLI-like text output.
#'
#' @importFrom utils capture.output
#' @return `data.frame` by default, or character scalar in text mode.
#' @examples
#' db <- mdbr:::.mdb_example_nwind_path()
#' if (nzchar(db)) {
#'   mdb_sql(db, "SELECT [ProductID], [ProductName] FROM [Products] LIMIT 3;")
#' }
#' @export
mdb_sql <- function(
  path,
  statement = NULL,
  no_header = FALSE,
  no_footer = FALSE,
  no_pretty_print = FALSE,
  delimiter = "\t",
  input = NULL,
  output = NULL,
  as_text = FALSE
) {
  if (!is.null(input)) {
    statements <- .mdb_read_sql_input(input)
  } else {
    statements <- statement
  }

  if (
    is.null(statements) ||
      !length(statements) ||
      !any(nzchar(trimws(statements)))
  ) {
    stop("Provide `statement` or `input`.", call. = FALSE)
  }

  statements <- as.character(statements)
  statements <- trimws(statements)
  statements <- statements[nzchar(statements)]

  con <- .mdb_connect(path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  text_blocks <- character(0)
  last_df <- data.frame()
  for (stmt in statements) {
    df <- DBI::dbGetQuery(con, stmt)
    last_df <- df

    if (!isTRUE(as_text) && is.null(output) && length(statements) == 1L) {
      return(df)
    }

    if (isTRUE(no_pretty_print)) {
      block <- .mdb_delimited_text(
        df,
        delimiter = delimiter,
        row_delimiter = "\n",
        header = !isTRUE(no_header),
        null = "",
        no_quote = TRUE
      )
    } else {
      lines <- capture.output(print(df, row.names = FALSE))
      if (isTRUE(no_header) && length(lines) > 0L) {
        lines <- lines[-1L]
      }
      block <- paste(lines, collapse = "\n")
    }

    if (!isTRUE(no_footer)) {
      block <- paste0(block, "\n", nrow(df), " row(s)")
    }
    text_blocks <- c(text_blocks, block)
  }

  if (!isTRUE(as_text) && is.null(output)) {
    return(last_df)
  }

  text <- paste(text_blocks, collapse = "\n")
  if (!is.null(output)) {
    writeLines(text, con = output, useBytes = TRUE)
  }
  text
}

#' Count Rows In Table
#'
#' `mdb-count` is a utility program distributed with MDB Tools.
#' It outputs the number of rows in a table.
#'
#' @param path Path to `.mdb`/`.accdb` file.
#' @param table Table name.
#' @param where Optional SQL predicate appended to `WHERE`. This is an R-side
#' extension and is not part of the CLI.
#' @param version Logical; when `TRUE`, return mdbtools version (`--version`).
#'
#' @return Integer row count or version string.
#' @examples
#' db <- mdbr:::.mdb_example_nwind_path()
#' if (nzchar(db)) {
#'   mdb_count(db, "Orders")
#' }
#' @export
mdb_count <- function(path, table = NULL, where = NULL, version = FALSE) {
  if (isTRUE(version)) {
    return(mdb_ver())
  }
  if (is.null(table)) {
    stop("`table` is required unless `version = TRUE`.", call. = FALSE)
  }
  table <- as.character(table[[1]])

  if (is.null(where) || !nzchar(trimws(where))) {
    return(as.integer(.native_table_num_rows(.mdb_normalize_path(path), table)))
  }

  # Read a single column to avoid materializing wide rows when only row count is needed.
  where_sql <- if (!is.null(where) && nzchar(trimws(where))) {
    paste(" WHERE", where)
  } else {
    ""
  }
  fields <- tryCatch(
    .native_list_fields(.mdb_normalize_path(path), table),
    error = function(e) character(0)
  )

  if (length(fields) > 0L && nzchar(fields[[1]])) {
    probe_sql <- sprintf(
      "SELECT %s FROM %s%s",
      .mdb_quote_ident(fields[[1]]),
      .mdb_quote_ident(table),
      where_sql
    )
    rows <- mdb_sql(path, probe_sql)
    return(as.integer(nrow(rows)))
  }

  rows <- mdb_sql(
    path,
    sprintf("SELECT * FROM %s%s", .mdb_quote_ident(table), where_sql)
  )
  as.integer(nrow(rows))
}

#' Generate Schema DDL or Column Types
#'
#' `mdb-schema` is a utility program distributed with MDB Tools. It produces
#' DDL (data definition language) output for the given database, which can be
#' passed to another database to recreate the Access table structure. With
#' `mode = "legacy"` (the default), it returns a
#' [readr col spec][readr::cols()] for the table instead.
#'
#' @param path Path to `.mdb`/`.accdb` file.
#' @param table Table name(s). For `mode = "ddl"`, defaults to all user tables.
#'   For `mode = "legacy"`, exactly one table name must be given.
#' @param mode `"legacy"` (default) returns a [readr::cols()] specification,
#'   matching the k5cents/mdbr canonical API. Requires the \pkg{readr} package.
#'   `"ddl"` returns DDL text.
#' @param condense Logical; only used when `mode = "legacy"`. When `TRUE`,
#'   passes the col spec through [readr::cols_condense()]. Default `FALSE`.
#' @param namespace Prefix identifiers with namespace, equivalent to
#' `-N/--namespace`. Only used when `mode = "ddl"`.
#' @param backend Target DDL dialect. Supported values are `access`, `sybase`,
#' `oracle`, `postgres`, `mysql`, and `sqlite`. Only used when `mode = "ddl"`.
#' @param drop_table Issue `DROP TABLE` statements.
#' @param not_null Include `NOT NULL` constraints.
#' @param default_values Include `DEFAULT` values.
#' @param not_empty Include `CHECK <> ''` constraints.
#' @param comments Include `COMMENT ON` statements.
#' @param indexes Export indexes.
#' @param relations Request foreign key constraints. Current library-mode
#' implementation emits a placeholder comment; full FK export is not yet
#' implemented.
#' @param as_list Logical; defaults to `TRUE`. When `TRUE`, returns a named
#' `mdblist` of DDL text entries keyed by table name. Only used when
#' `mode = "ddl"`.
#'
#' @return When `mode = "legacy"`, a [readr::cols()] specification (optionally
#' condensed via [readr::cols_condense()]). Requires the \pkg{readr} package.
#' When `mode = "ddl"` and `as_list = TRUE`, a named `mdblist` of table-level
#' DDL text.
#' @examples
#' db <- mdbr:::.mdb_example_nwind_path()
#' if (nzchar(db)) {
#'   mdb_schema(db, table = "Products")
#'   mdb_schema(db, table = "Products", mode = "ddl")
#' }
#' @export
mdb_schema <- function(
  path,
  table = NULL,
  mode = c("legacy", "ddl"),
  condense = FALSE,
  namespace = NULL,
  backend = c("access", "sybase", "oracle", "postgres", "mysql", "sqlite"),
  drop_table = FALSE,
  not_null = TRUE,
  default_values = FALSE,
  not_empty = FALSE,
  comments = TRUE,
  indexes = TRUE,
  relations = TRUE,
  as_list = TRUE
) {
  mode <- match.arg(mode)
  if (mode == "legacy") {
    if (is.null(table) || length(table) != 1L) {
      stop(
        "mode = \"legacy\" requires exactly one table name.",
        call. = FALSE
      )
    }
    if (!requireNamespace("readr", quietly = TRUE)) {
      stop(
        "Package \"readr\" is needed for mode = \"legacy\". ",
        "Install it with: install.packages(\"readr\")",
        call. = FALSE
      )
    }
    tbl <- as.character(table)[[1]]
    path_norm <- .mdb_normalize_path(path)
    x <- .native_print_schema(
      path = path_norm,
      table = tbl,
      backend = "access",
      namespace = NULL,
      export_options = .mdb_schema_options()
    )
    x <- strsplit(x[[1]], "\n")[[1]]
    x <- grep("^\t", x, value = TRUE)
    x <- gsub("\t{3}", "|", x)
    x <- gsub("^\t", "", x)
    x <- gsub(",\\s*$", "", x)
    x <- gsub("\\[|\\]", "", x)
    x <- gsub("\\s\\(\\d+\\).*", "", x)
    x <- gsub("\\sNOT NULL", "", x)
    y <- matrix(
      data = unlist(strsplit(x, "\\|")),
      ncol = 2,
      byrow = TRUE
    )
    z <- vapply(y[, 2], list_switch, character(1), mdb_col_types)
    names(z) <- y[, 1]
    spec <- readr::as.col_spec(z)
    if (isTRUE(condense)) {
      return(readr::cols_condense(spec))
    }
    return(spec)
  }

  table_vec <- if (is.null(table)) {
    NULL
  } else {
    v <- as.character(table)
    v[nzchar(v)]
  }

  backend <- match.arg(backend)
  export_options <- .mdb_schema_options(
    drop_table = drop_table,
    not_null = not_null,
    default_values = default_values,
    not_empty = not_empty,
    comments = comments,
    indexes = indexes,
    relations = relations
  )
  path <- .mdb_normalize_path(path)
  namespace_val <- if (!is.null(namespace)) {
    as.character(namespace[[1]])
  } else {
    NULL
  }

  # C now returns a named character vector: names = table names, values = DDL.
  # Calling with table = NULL fetches all user tables in a single file open.
  # For a single specific table, pass it directly so C can error if not found.
  if (!is.null(table_vec) && length(table_vec) == 1L) {
    result <- .native_print_schema(
      path = path,
      table = table_vec[[1]],
      backend = backend,
      namespace = namespace_val,
      export_options = export_options
    )
  } else {
    result <- .native_print_schema(
      path = path,
      table = NULL,
      backend = backend,
      namespace = namespace_val,
      export_options = export_options
    )
    if (!is.null(table_vec) && length(table_vec) > 1L) {
      missing_tables <- setdiff(table_vec, names(result))
      if (length(missing_tables) > 0L) {
        stop(
          sprintf(
            "Table(s) not found for schema export: %s",
            paste(missing_tables, collapse = ", ")
          ),
          call. = FALSE
        )
      }
      result <- result[match(table_vec, names(result))]
    }
  }

  if (isTRUE(as_list)) {
    return(.as_mdblist(as.list(result)))
  }

  # as_list = FALSE: single table or all-tables-concatenated returns a scalar
  # string; multiple specific tables returns a plain named list.
  if (length(result) == 1L || is.null(table_vec)) {
    return(paste(result, collapse = "\n"))
  }

  as.list(result)
}

#' Return MDB File Format Or MDB Tools Version
#'
#' `mdb-ver` will return a single line of output corresponding to the program
#' that produced the file: `JET3` (for files produced by Access 97), `JET4`
#' (Access 2000, XP and 2003), `ACE12` (Access 2007), `ACE14` (Access 2010),
#' `ACE15` (Access 2013), or `ACE16` (Access 2016).
#'
#' @param path Optional database path. When omitted, the wrapper returns the
#' mdbtools package version for backward compatibility.
#' @param version Logical, equivalent to `-M/--version`.
#'
#' @return Single character string with file format or mdbtools version.
#' @examples
#' mdb_ver()
#' db <- mdbr:::.mdb_example_nwind_path()
#' if (nzchar(db)) {
#'   mdb_ver(db)
#' }
#' @export
mdb_ver <- function(path = NULL, version = FALSE) {
  if (isTRUE(version) || is.null(path)) {
    return(.native_mdbtools_version())
  }
  .native_file_format(.mdb_normalize_path(path))
}

#' Export Table As List Columns (mdb-array mimic)
#'
#' `mdb-array(1)` emits C source; this wrapper returns a named R list of columns
#' while keeping equivalent database/table inputs.
#'
#' @param path Path to `.mdb`/`.accdb` file.
#' @param table Table name.
#' @param columns Optional character vector of columns.
#' @param n Optional row limit (`LIMIT n`).
#'
#' @return Named list, one entry per selected column.
#' @examples
#' db <- mdbr:::.mdb_example_nwind_path()
#' if (nzchar(db)) {
#'   arr <- mdb_array(db, "Products", columns = c("ProductID", "ProductName"), n = 2)
#'   str(arr)
#' }
#' @export
mdb_array <- function(path, table, columns = NULL, n = -1L) {
  table <- as.character(table[[1]])
  col_sql <- if (is.null(columns) || !length(columns)) {
    "*"
  } else {
    paste(.mdb_quote_ident(columns), collapse = ", ")
  }
  sql <- sprintf("SELECT %s FROM %s", col_sql, .mdb_quote_ident(table))
  if (!is.null(n) && is.finite(n) && n >= 0) {
    sql <- paste(sql, "LIMIT", as.integer(n))
  }
  as.list(mdb_sql(path, sql))
}

#' Export Data In An MDB Table To CSV Or INSERT SQL
#'
#' `mdb-export` is a utility program distributed with MDB Tools.
#' It produces CSV output for the given table. Such output is suitable for
#' importation into databases or spreadsheets.
#'
#' Used with `insert`, it outputs backend-specific SQL `INSERT` statements.
#' Most formatting options also apply in insert mode.
#'
#' @param path Path to `.mdb`/`.accdb` file.
#' @param table Table name.
#' @param no_header Logical, equivalent to `-H/--no-header`.
#' @param delimiter Equivalent to `-d/--delimiter`.
#' @param row_delimiter Equivalent to `-R/--row-delimiter`.
#' @param no_quote Equivalent to `-Q/--no-quote`.
#' @param quote Equivalent to `-q/--quote`.
#' @param escape Equivalent to `-X/--escape`.
#' @param escape_invisible Equivalent to `-e/--escape-invisible`.
#' @param date_format Equivalent to `-D/--date-format`.
#' @param datetime_format Equivalent to `-T/--datetime-format`.
#' @param null Equivalent to `-0/--null`.
#' @param bin Binary mode (`strip`, `raw`, `octal`, `hex`) for parity.
#' @param boolean_words Equivalent to `-B/--boolean-words`.
#' @param insert Backend for `-I/--insert` mode.
#' @param namespace Equivalent to `-N/--namespace`.
#' @param batch_size Equivalent to `-S/--batch-size`.
#' @param n Optional row limit (`LIMIT n`).
#'
#' @return Character scalar containing CSV or SQL INSERT text.
#' @examples
#' db <- mdbr:::.mdb_example_nwind_path()
#' if (nzchar(db)) {
#'   cat(mdb_export(db, "Products", n = 2))
#' }
#' @export
mdb_export <- function(
  path,
  table,
  no_header = FALSE,
  delimiter = ",",
  row_delimiter = "\n",
  no_quote = FALSE,
  quote = '"',
  escape = NULL,
  escape_invisible = FALSE,
  date_format = "%Y-%m-%d",
  datetime_format = "%Y-%m-%d %H:%M:%S",
  null = "",
  bin = c("strip", "raw", "octal", "hex"),
  boolean_words = FALSE,
  insert = NULL,
  namespace = NULL,
  batch_size = 1L,
  n = -1L
) {
  bin <- match.arg(bin)
  if (bin != "strip") {
    warning(
      "`bin` modes other than 'strip' are not fully implemented in library-only mode.",
      call. = FALSE
    )
  }

  df <- .mdb_query_table(path, table, n = n)
  df <- .mdb_apply_datetime_formats(
    df,
    date_format = date_format,
    datetime_format = datetime_format
  )
  df <- .mdb_apply_boolean_words(df, boolean_words = boolean_words)

  if (identical(bin, "strip")) {
    for (nm in names(df)) {
      if (is.raw(df[[nm]])) {
        df[[nm]] <- NA_character_
      }
    }
  }

  if (is.null(insert)) {
    return(.mdb_delimited_text(
      df,
      delimiter = delimiter,
      row_delimiter = row_delimiter,
      header = !isTRUE(no_header),
      null = null,
      no_quote = no_quote,
      quote = quote,
      escape = escape,
      escape_invisible = escape_invisible
    ))
  }

  backend <- match.arg(
    insert,
    c("access", "sybase", "oracle", "postgres", "mysql", "sqlite")
  )
  batch_size <- max(1L, as.integer(batch_size[[1]]))
  target <- .mdb_quote_ident(as.character(table[[1]]))
  if (!is.null(namespace) && nzchar(namespace)) {
    target <- paste0(.mdb_quote_ident(namespace), ".", target)
  }

  cols <- paste(.mdb_quote_ident(names(df)), collapse = ", ")
  out <- character(0)
  if (nrow(df) == 0L) {
    return("")
  }

  for (i in seq(1L, nrow(df), by = batch_size)) {
    j <- min(i + batch_size - 1L, nrow(df))
    chunk <- df[i:j, , drop = FALSE]
    vals <- apply(chunk, 1L, function(row) {
      paste0(
        "(",
        paste(
          vapply(row, .mdb_sql_literal, FUN.VALUE = character(1)),
          collapse = ", "
        ),
        ")"
      )
    })
    stmt <- sprintf(
      "INSERT INTO %s (%s) VALUES %s;",
      target,
      cols,
      paste(vals, collapse = ", ")
    )
    if (backend %in% c("access", "oracle", "sybase") && length(vals) > 1L) {
      stmt <- paste(
        sprintf("INSERT INTO %s (%s) VALUES %s;", target, cols, vals),
        collapse = "\n"
      )
    }
    out <- c(out, stmt)
  }
  paste(out, collapse = "\n")
}

#' MDB Header Summary (mdb-header mimic)
#'
#' `mdb-header(1)` writes C files; this wrapper returns a structured summary.
#'
#' @param path Path to `.mdb`/`.accdb` file.
#'
#' @return Named list with version, table names and query names.
#' @examples
#' db <- mdbr:::.mdb_example_nwind_path()
#' if (nzchar(db)) {
#'   mdb_header(db)
#' }
#' @export
mdb_header <- function(path) {
  list(
    version = mdb_ver(),
    tables = mdb_tables(path, system = TRUE),
    queries = mdb_queries(path)
  )
}

#' Hexdump MDB File (mdb-hexdump mimic)
#'
#' @param path Path to file.
#' @param pagenumber Optional page index (0-based) like `mdb-hexdump file [pagenumber]`.
#' @param page_size Page size in bytes (default 4096 for modern Jet/ACE).
#' @param n Number of bytes to emit.
#'
#' @return Single hexadecimal string.
#' @examples
#' db <- mdbr:::.mdb_example_nwind_path()
#' if (nzchar(db)) {
#'   mdb_hexdump(db, n = 16)
#' }
#' @export
mdb_hexdump <- function(path, pagenumber = NULL, page_size = 4096L, n = 256L) {
  con <- file(path, "rb")
  on.exit(close(con), add = TRUE)
  if (!is.null(pagenumber)) {
    seek(
      con,
      where = as.integer(pagenumber) * as.integer(page_size),
      origin = "start"
    )
  }
  bytes <- readBin(con, what = "raw", n = as.integer(n))
  paste(sprintf("%02X", as.integer(bytes)), collapse = " ")
}

#' Import CSV Into MDB (mdb-import mimic)
#'
#' `mdb-import(1)` writes to MDB files. This package is read-only, so this
#' function validates CLI-like options and then errors.
#'
#' @param path Path to `.mdb`/`.accdb` file.
#' @param table Table name.
#' @param csvfile CSV file path.
#' @param header_lines Equivalent to `-H/--header` skipped lines.
#' @param delimiter Equivalent to `-d/--delimiter`.
#'
#' @return No return; always errors in read-only mode.
#' @keywords internal
mdb_import <- function(
  path,
  table,
  csvfile,
  header_lines = 0L,
  delimiter = ","
) {
  stop(
    "`mdb_import()` is not available: this package currently supports read-only MDB/ACCDB operations.",
    call. = FALSE
  )
}

#' Export Data In An MDB Table To JSON
#'
#' `mdb-json` is a utility program distributed with MDB Tools.
#' It produces JSON output for the given table. Such output is suitable for
#' parsing in a variety of languages.
#'
#' @param path Path to `.mdb`/`.accdb` file.
#' @param table Table name.
#' @param date_format Equivalent to `-D/--date-format`.
#' @param time_format Equivalent to `-T/--time-format`.
#' @param no_unprintable Equivalent to `-U/--no-unprintable`.
#' @param n Optional row limit.
#'
#' @return JSON string.
#' @importFrom jsonlite toJSON
#' @examples
#' db <- mdbr:::.mdb_example_nwind_path()
#' if (nzchar(db) && requireNamespace("jsonlite", quietly = TRUE)) {
#'   mdb_json(db, "Products", n = 2)
#' }
#' @export
mdb_json <- function(
  path,
  table,
  date_format = "%Y-%m-%d",
  time_format = "%Y-%m-%d %H:%M:%S",
  no_unprintable = FALSE,
  n = -1L
) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("`mdb_json()` requires the `jsonlite` package.", call. = FALSE)
  }
  df <- .mdb_query_table(path, table, n = n)
  df <- .mdb_apply_datetime_formats(
    df,
    date_format = date_format,
    datetime_format = time_format
  )
  df <- .mdb_apply_unprintable(df, no_unprintable = no_unprintable)
  jsonlite::toJSON(df, dataframe = "rows", na = "null", auto_unbox = TRUE)
}

#' Get Properties List From MDB Database
#'
#' `mdb-prop` retrieves properties for one or more objects in an MDB database.
#' `name` is the name of the table, query, or other object.
#' `propcol` is the name of the `MSysObjects` column containing properties and
#' defaults to `LvProp`.
#'
#' @param path Path to `.mdb`/`.accdb` file.
#' @param name Object name (`table`, `query`, etc.); may be a character vector.
#' @param propcol Property column name. Defaults to `LvProp`.
#' @param version Logical; when `TRUE`, return mdbtools version.
#' @param as_list Logical; defaults to `TRUE`. When `TRUE`, wraps the result in
#' an `mdblist` object so the dedicated print method is used.
#'
#' @return A named list with one entry per element of `name`. Each entry is
#' itself a named list of named character vectors, one per property block
#' (e.g. `"(none)"` for table-level properties, or a column/field name).
#' Access individual values with `p[["Orders"]][["(none)"]]["Description"]`.
#' @examples
#' db <- mdbr:::.mdb_example_nwind_path()
#' if (nzchar(db)) {
#'   p <- mdb_prop(db, "Orders")
#'   p[["Orders"]][["(none)"]]["Description"]
#'   p2 <- mdb_prop(db, c("Orders", "Orders Qry"))
#' }
#' @export
mdb_prop <- function(
  path,
  name = NULL,
  propcol = "LvProp",
  version = FALSE,
  as_list = TRUE
) {
  if (isTRUE(version)) {
    return(mdb_ver())
  }
  if (is.null(name)) {
    stop("`name` is required unless `version = TRUE`.", call. = FALSE)
  }

  path <- .mdb_normalize_path(path)
  name <- as.character(name)
  name <- name[nzchar(name)]
  if (!length(name)) {
    stop(
      "`name` must contain at least one non-empty object name.",
      call. = FALSE
    )
  }

  propcol <- if (!is.null(propcol) && nzchar(propcol)) {
    as.character(propcol[[1]])
  } else {
    NULL
  }

  out <- stats::setNames(
    lapply(name, function(nm) .native_prop_dump(path, nm, propcol)),
    name
  )

  if (isTRUE(as_list)) .as_mdblist(out) else out
}
