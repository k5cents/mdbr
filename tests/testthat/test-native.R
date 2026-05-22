library(testthat)
library(mdbr)

# Tests that verify the bundled mdbtools functionality using the nycflights13
# example database shipped with the mdbr package.

test_that("mdb_tables returns tables using native backend", {
  skip_if_not(is.loaded("mdbr_version"))
  t <- mdb_tables(mdb_example())
  expect_type(t, "character")
  expect_gte(length(t), 1L)
  expect_true("Airlines" %in% t)
})

test_that("mdb_tables type='query' returns character vector", {
  skip_if_not(is.loaded("mdbr_version"))
  q <- mdb_tables(mdb_example(), type = "query")
  expect_type(q, "character")
})

test_that("mdb_tables returns a character vector", {
  skip_if_not(is.loaded("mdbr_version"))
  txt <- mdb_tables(mdb_example())
  expect_type(txt, "character")
  expect_gte(length(txt), 1L)
})

test_that("mdb_ver returns version string from native library", {
  skip_if_not(is.loaded("mdbr_version"))
  ver <- mdb_ver()
  expect_type(ver, "character")
  expect_length(ver, 1L)
  expect_true(nzchar(ver))
})

test_that("mdb_ver with path returns file format", {
  skip_if_not(is.loaded("mdbr_version"))
  fmt <- mdb_ver(mdb_example())
  expect_type(fmt, "character")
  expect_true(grepl("^(JET|ACE)", fmt))
})

test_that("mdb_sql queries nycflights13 example", {
  skip_if_not(is.loaded("mdbr_version"))
  df <- mdb_sql(mdb_example(), "SELECT * FROM [Airlines] LIMIT 3;")
  expect_s3_class(df, "data.frame")
  expect_lte(nrow(df), 3L)
  expect_true("carrier" %in% names(df) || ncol(df) >= 1)
})

test_that("mdb_count returns integer row count", {
  skip_if_not(is.loaded("mdbr_version"))
  n <- mdb_count(mdb_example(), "Airlines")
  expect_type(n, "integer")
  expect_gte(n, 1L)
})

test_that("mdb_schema returns DDL text for a table", {
  skip_if_not(is.loaded("mdbr_version"))
  ddl <- mdb_schema(
    mdb_example(),
    table = "Airlines",
    mode = "ddl",
    as_list = FALSE
  )
  expect_type(ddl, "character")
  expect_true(grepl("CREATE TABLE", ddl, ignore.case = TRUE))
})

test_that("mdb_export returns CSV text", {
  skip_if_not(is.loaded("mdbr_version"))
  csv <- mdb_export(mdb_example(), "Airlines", n = 2L)
  expect_type(csv, "character")
  expect_length(csv, 1L)
  expect_true(grepl(",", csv))
})

test_that("DBI connection to nycflights13 example works", {
  skip_if_not(is.loaded("mdbr_version"))
  conn <- DBI::dbConnect(mdb(), dbname = mdb_example())
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  expect_true(DBI::dbIsValid(conn))
  tables <- DBI::dbListTables(conn)
  expect_true("Airlines" %in% tables)

  df <- DBI::dbReadTable(conn, "Airlines")
  expect_s3_class(df, "data.frame")
  expect_gte(nrow(df), 1L)
})

test_that("export_mdb backward-compat: returns CSV text via native", {
  skip_if_not(is.loaded("mdbr_version"))
  dat <- export_mdb(mdb_example(), "Airlines", output = TRUE)
  expect_type(dat, "character")
  expect_length(dat, 1L)
})

test_that("read_mdb backward-compat: reads table as tibble", {
  skip_if_not(is.loaded("mdbr_version"))
  dat <- read_mdb(mdb_example(), "Airlines")
  expect_s3_class(dat, "data.frame")
  expect_gte(nrow(dat), 1L)
})
