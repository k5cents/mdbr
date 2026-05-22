library(mdbr)

sample_accdb <- testthat::test_path(
  "mdbtestdata",
  "data",
  "ASampleDatabase.accdb"
)
sample_mdb <- testthat::test_path("mdbtestdata", "data", "nwind.mdb")
sample_sql <- testthat::test_path("mdbtestdata", "sql", "nwind.sql")

read_sql_statements <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- trimws(lines)
  lines <- lines[nzchar(lines)]
  lines <- lines[!startsWith(lines, "#")]
  lines
}

test_that("driver constructor returns DBIDriver", {
  drv <- mdb()
  expect_s4_class(drv, "MdbDriver")
})

test_that("native symbols are loaded", {
  expect_true(is.loaded("mdbr_list_tables"))
  expect_true(is.loaded("mdbr_list_queries"))
  expect_true(is.loaded("mdbr_list_fields"))
  expect_true(is.loaded("mdbr_read_table"))
  expect_true(is.loaded("mdbr_run_query"))
  expect_true(is.loaded("mdbr_get_query_sql"))
})

test_that("character dbConnect dispatch works for accdb path", {
  skip_if_not(file.exists(sample_accdb))

  conn <- DBI::dbConnect(sample_accdb)
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  expect_true(DBI::dbIsValid(conn))
})

test_that("basic DBI methods operate on sample accdb", {
  skip_if_not(file.exists(sample_accdb))

  conn <- DBI::dbConnect(mdb(), dbname = sample_accdb)
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  tables <- DBI::dbListTables(conn)
  expect_true(length(tables) > 0)
  expect_true("Asset Items" %in% tables)

  target <- "Asset Items"
  expect_true(DBI::dbExistsTable(conn, target))

  fields <- DBI::dbListFields(conn, target)
  expect_true(length(fields) >= 1)

  df <- DBI::dbReadTable(conn, target)
  expect_s3_class(df, "data.frame")
})

test_that("dbReadTable applies type coercion from MDB metadata", {
  skip_if_not(file.exists(sample_mdb))

  conn <- DBI::dbConnect(sample_mdb)
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  df <- DBI::dbReadTable(conn, "Umsätze")
  expect_s3_class(df, "data.frame")

  expect_type(df$OrderID, "integer")
  expect_type(df$Freight, "double")
  expect_s3_class(df$ShippedDate, "POSIXct")
  expect_identical(attr(df$ShippedDate, "tzone"), "UTC")

  formatted <- format(df$ShippedDate, "%Y-%m-%d %H:%M:%S", tz = "UTC")
  expect_true(all(
    is.na(df$ShippedDate) |
      grepl(
        "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$",
        formatted
      )
  ))
})

test_that("query roundtrip works", {
  skip_if_not(file.exists(sample_mdb))

  conn <- DBI::dbConnect(sample_mdb)
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  tables <- DBI::dbListTables(conn)
  expect_true("Umsätze" %in% tables)

  out <- DBI::dbGetQuery(conn, "SELECT * FROM [Umsätze] LIMIT 2;")
  expect_s3_class(out, "data.frame")
  expect_lte(nrow(out), 2)
  expect_true("OrderID" %in% names(out))
})

test_that("dbGetQuery applies type coercion from MDB metadata", {
  skip_if_not(file.exists(sample_mdb))

  conn <- DBI::dbConnect(sample_mdb)
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  out <- DBI::dbGetQuery(
    conn,
    "SELECT [OrderID], [Freight], [ShippedDate] FROM [Umsätze] LIMIT 5;"
  )

  expect_type(out$OrderID, "integer")
  expect_type(out$Freight, "double")
  expect_s3_class(out$ShippedDate, "POSIXct")
  expect_identical(attr(out$ShippedDate, "tzone"), "UTC")

  formatted <- format(out$ShippedDate, "%Y-%m-%d %H:%M:%S", tz = "UTC")
  expect_true(all(
    is.na(out$ShippedDate) |
      grepl(
        "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$",
        formatted
      )
  ))
})

test_that("dbGetQuery does not execute saved Access query names yet", {
  skip_if_not(file.exists(sample_mdb))

  conn <- DBI::dbConnect(sample_mdb)
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  expect_error(
    DBI::dbGetQuery(conn, "SELECT * FROM [Current Product List] LIMIT 3;"),
    regexp = "not a table|Got no result"
  )
})

test_that("mdb_queries lists saved queries and extracts SQL", {
  skip_if_not(file.exists(sample_mdb))

  queries <- mdb_queries(sample_mdb)
  expect_true("Current Product List" %in% queries)

  sql <- mdb_queries(sample_mdb, query = "Current Product List")
  expect_s3_class(sql, "mdblist")
  expect_identical(names(sql), "Current Product List")
  expect_true(grepl(
    "^SELECT",
    sql[["Current Product List"]],
    ignore.case = TRUE
  ))
})

test_that("dbListObjects returns DBI-shaped data frame with tables and queries", {
  skip_if_not(file.exists(sample_mdb))

  conn <- DBI::dbConnect(sample_mdb)
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  objs <- DBI::dbListObjects(conn)
  expect_s3_class(objs, "data.frame")
  expect_identical(names(objs)[1:2], c("table", "is_prefix"))
  expect_true(is.list(objs$table))
  expect_type(objs$is_prefix, "logical")
  expect_true(all(!objs$is_prefix))

  obj_names <- vapply(objs$table, as.character, FUN.VALUE = character(1))
  expect_true("Products" %in% obj_names)
  expect_true("Current Product List" %in% obj_names)
})

test_that("mdb_ver and mdb_schema work without system CLI", {
  skip_if_not(file.exists(sample_mdb))

  ver <- mdb_ver()
  expect_type(ver, "character")
  expect_gt(nchar(ver), 0)

  file_ver <- mdb_ver(sample_mdb)
  expect_identical(file_ver, "JET3")

  ddl <- mdb_schema(
    sample_mdb,
    table = "Products",
    mode = "ddl",
    backend = "postgres",
    as_list = FALSE
  )
  expect_type(ddl, "character")
  expect_true(grepl("CREATE TABLE", ddl, fixed = TRUE))
})

test_that("mdb_prop returns named list of named lists for single object", {
  skip_if_not(file.exists(sample_mdb))

  props <- mdb_prop(sample_mdb, "Orders")
  expect_type(props, "list")
  expect_identical(names(props), "Orders")
  expect_type(props[["Orders"]], "list")
  expect_gt(length(props[["Orders"]]), 0L)
})

test_that("mdb_prop returns named list of named lists for multiple objects", {
  skip_if_not(file.exists(sample_mdb))

  props <- mdb_prop(sample_mdb, c("Orders", "Orders Qry"))
  expect_type(props, "list")
  expect_true(all(c("Orders", "Orders Qry") %in% names(props)))
  expect_type(props[["Orders"]], "list")
  expect_gt(length(props[["Orders"]]), 0L)
})

test_that("mdb_queries can return named mdblist for multiple query SQL texts", {
  skip_if_not(file.exists(sample_mdb))

  queries <- mdb_queries(sample_mdb)
  supported <- queries[vapply(
    queries,
    function(q) {
      !inherits(
        try(mdb_queries(sample_mdb, query = q, as_list = FALSE), silent = TRUE),
        "try-error"
      )
    },
    logical(1)
  )]
  target <- head(supported, 2)
  skip_if_not(length(target) >= 1)

  sqls <- mdb_queries(sample_mdb, query = target, as_list = TRUE)
  expect_s3_class(sqls, "mdblist")
  expect_true(all(target %in% names(sqls)))
  expect_true(all(vapply(
    sqls,
    function(x) is.character(x) && nchar(x) > 0,
    logical(1)
  )))
})

test_that("mdb_queries query SQL output is mdblist by default", {
  skip_if_not(file.exists(sample_mdb))

  queries <- mdb_queries(sample_mdb)
  supported <- queries[vapply(
    queries,
    function(q) {
      !inherits(
        try(mdb_queries(sample_mdb, query = q, as_list = FALSE), silent = TRUE),
        "try-error"
      )
    },
    logical(1)
  )]
  target <- head(supported, 2)
  skip_if_not(length(target) >= 1)

  sqls <- mdb_queries(sample_mdb, query = target)
  expect_s3_class(sqls, "mdblist")
  expect_true(all(target %in% names(sqls)))
})

test_that("mdb_queries mirrors CLI placeholder for unsupported saved-query layout", {
  skip_if_not(file.exists(sample_mdb))

  q <- "Summary of Sales by Quarter"
  skip_if_not(q %in% mdb_queries(sample_mdb))

  sql <- mdb_queries(sample_mdb, query = q, as_list = FALSE)
  expect_identical(sql, "SELECT  FROM  ")
})

test_that("mdb_schema selected table output is mdblist by default", {
  skip_if_not(file.exists(sample_mdb))

  ddl <- mdb_schema(sample_mdb, table = "Products", mode = "ddl")
  expect_s3_class(ddl, "mdblist")
  expect_identical(names(ddl), "Products")
  expect_true(grepl("CREATE TABLE", ddl[["Products"]], fixed = TRUE))
})

test_that("mdb_schema can return named mdblist for selected tables", {
  skip_if_not(file.exists(sample_mdb))

  ddl <- mdb_schema(sample_mdb, table = c("Products", "Orders"), mode = "ddl", as_list = TRUE)
  expect_s3_class(ddl, "mdblist")
  expect_true(all(c("Products", "Orders") %in% names(ddl)))
  expect_true(all(vapply(
    ddl,
    function(x) grepl("CREATE TABLE", x, fixed = TRUE),
    logical(1)
  )))
})

test_that("mdb_schema with no table returns mdblist by default", {
  skip_if_not(file.exists(sample_mdb))

  ddl <- mdb_schema(sample_mdb, mode = "ddl")
  expect_s3_class(ddl, "mdblist")
  expect_true(length(ddl) > 0)
  expect_true("Products" %in% names(ddl))
  expect_true(grepl("CREATE TABLE", ddl[[1]], fixed = TRUE))
})

test_that("mdb_schema output does not include legacy banner", {
  skip_if_not(file.exists(sample_mdb))

  ddl <- mdb_schema(sample_mdb, table = "Products", mode = "ddl", as_list = FALSE)
  expect_false(grepl(
    "MDB Tools - A library for reading MS Access database files",
    ddl,
    fixed = TRUE
  ))
})

test_that("mdb-tables and mdb-queries option mimics behave", {
  skip_if_not(file.exists(sample_mdb))

  table_vec <- mdb_tables(sample_mdb)
  expect_type(table_vec, "character")
  expect_gte(length(table_vec), 1L)

  query_names <- mdb_queries(sample_mdb, list = TRUE)
  expect_type(query_names, "character")

  query_text <- mdb_queries(
    sample_mdb,
    list = TRUE,
    newline = TRUE,
    as_text = TRUE
  )
  expect_type(query_text, "character")

  typed_any <- mdb_tables(sample_mdb, type = "any", show_type = TRUE)
  expect_true(any(grepl("^query ", typed_any)))
})

test_that("mdb-export and mdb-sql option mimics return text output", {
  skip_if_not(file.exists(sample_mdb))

  sql_text <- mdb_sql(
    sample_mdb,
    "SELECT [OrderID], [Freight] FROM [Umsätze] LIMIT 2;",
    as_text = TRUE,
    no_pretty_print = TRUE,
    no_footer = TRUE,
    delimiter = "|"
  )
  expect_type(sql_text, "character")
  expect_true(grepl("\\|", sql_text) || nzchar(sql_text))

  export_text <- mdb_export(
    sample_mdb,
    "Umsätze",
    no_header = TRUE,
    delimiter = ";",
    row_delimiter = "\n",
    no_quote = TRUE,
    n = 2
  )
  expect_type(export_text, "character")
  expect_true(nchar(export_text) > 0)

  # Categories includes binary-like content in nwind; export should not error
  # due to locale-invalid bytes during quoting.
  expect_type(mdb_export(sample_mdb, "Categories", n = 1), "character")
})

test_that("mdb_count fallback preserves WHERE and matches projected-row counts", {
  skip_if_not(file.exists(sample_mdb))

  total <- mdb_count(sample_mdb, "Umsätze")
  filtered <- mdb_count(sample_mdb, "Umsätze", where = "[OrderID] > 11000")

  projected_total <- nrow(mdb_sql(
    sample_mdb,
    "SELECT [OrderID] FROM [Umsätze]"
  ))
  projected_filtered <- nrow(mdb_sql(
    sample_mdb,
    "SELECT [OrderID] FROM [Umsätze] WHERE [OrderID] > 11000"
  ))

  expect_identical(total, as.integer(projected_total))
  expect_identical(filtered, as.integer(projected_filtered))
  expect_lt(filtered, total)
})

test_that("mdb_count without WHERE uses metadata row count semantics", {
  skip_if_not(file.exists(sample_mdb))

  count <- mdb_count(sample_mdb, "Umsätze")
  conn <- DBI::dbConnect(sample_mdb)
  on.exit(DBI::dbDisconnect(conn), add = TRUE)
  table_rows <- DBI::dbReadTable(conn, "Umsätze")
  expect_identical(count, as.integer(nrow(table_rows)))
})

test_that("test_script.sh command set is covered by mimic wrappers", {
  skip_if_not(file.exists(sample_accdb))
  skip_if_not(file.exists(sample_mdb))

  json_accdb <- mdb_json(sample_accdb, "Asset Items", n = 3)
  expect_type(json_accdb, "character")
  expect_true(grepl("\\[|\\{", json_accdb))

  json_mdb <- mdb_json(sample_mdb, "Umsätze", n = 3)
  expect_type(json_mdb, "character")
  expect_true(grepl("\\[|\\{", json_mdb))

  count_accdb <- mdb_count(sample_accdb, "Asset Items")
  expect_type(count_accdb, "integer")
  expect_gte(count_accdb, 0L)

  count_mdb <- mdb_count(sample_mdb, "Umsätze")
  expect_type(count_mdb, "integer")
  expect_gte(count_mdb, 0L)

  prop_accdb <- mdb_prop(sample_accdb, name = "Asset Items")
  expect_type(prop_accdb, "list")
  expect_type(prop_accdb[["Asset Items"]], "list")
  expect_gt(length(prop_accdb[["Asset Items"]]), 0L)

  prop_mdb <- mdb_prop(sample_mdb, name = "Umsätze")
  expect_type(prop_mdb, "list")
  expect_type(prop_mdb[["Umsätze"]], "list")
  expect_gt(length(prop_mdb[["Umsätze"]]), 0L)

  schema_accdb <- mdb_schema(sample_accdb, mode = "ddl", as_list = FALSE)
  expect_type(schema_accdb, "character")
  expect_true(grepl("CREATE TABLE", schema_accdb, fixed = TRUE))

  schema_mdb <- mdb_schema(sample_mdb, mode = "ddl", as_list = FALSE)
  expect_type(schema_mdb, "character")
  expect_true(grepl("CREATE TABLE", schema_mdb, fixed = TRUE))

  tables_accdb <- mdb_tables(sample_accdb)
  expect_type(tables_accdb, "character")
  expect_true("Asset Items" %in% tables_accdb)

  tables_mdb <- mdb_tables(sample_mdb)
  expect_type(tables_mdb, "character")
  expect_true("Umsätze" %in% tables_mdb)

  ver_accdb <- mdb_ver(sample_accdb)
  ver_mdb <- mdb_ver(sample_mdb)
  expect_true(ver_accdb %in% c("JET4", "ACE12", "ACE14", "ACE15", "ACE16"))
  expect_identical(ver_mdb, "JET3")

  queries_accdb <- mdb_queries(sample_accdb)
  expect_type(queries_accdb, "character")
  if (!"qryCostsSummedByOwner" %in% queries_accdb) {
    testthat::skip(
      "Expected query 'qryCostsSummedByOwner' not present in sample accdb."
    )
  }
  query_sql <- mdb_queries(
    sample_accdb,
    query = "qryCostsSummedByOwner",
    as_list = FALSE
  )
  expect_type(query_sql, "character")
  expect_true(grepl("^SELECT", query_sql, ignore.case = TRUE))
})

test_that("test_sql.sh is covered by mdb_sql input mode", {
  skip_if_not(file.exists(sample_mdb))
  skip_if_not(file.exists(sample_sql))

  sql_text <- mdb_sql(
    path = sample_mdb,
    input = sample_sql,
    as_text = TRUE,
    no_pretty_print = TRUE,
    no_footer = TRUE
  )

  expect_type(sql_text, "character")
  expect_true(nchar(sql_text) > 0)
})

test_that("test_sql script is replicated in DBI context", {
  skip_if_not(file.exists(sample_mdb))
  skip_if_not(file.exists(sample_sql))

  conn <- DBI::dbConnect(sample_mdb)
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  statements <- read_sql_statements(sample_sql)
  expect_true(length(statements) >= 1)

  out1 <- DBI::dbGetQuery(conn, statements[[1]])
  expect_s3_class(out1, "data.frame")
  expect_lte(nrow(out1), 10)
  expect_true("CustomerID" %in% names(out1))

  out2 <- DBI::dbGetQuery(conn, statements[[2]])
  expect_s3_class(out2, "data.frame")
  expect_true("City" %in% names(out2))
  expect_true(all(out2$City == "Helsinki"))

  out3 <- DBI::dbGetQuery(conn, statements[[3]])
  expect_s3_class(out3, "data.frame")
  expect_true("CompanyName" %in% names(out3))
  expect_gt(nrow(out3), 0)
})
