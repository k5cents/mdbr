library(mdbr)

stream_fixture <- function(path, table) {
  con <- DBI::dbConnect(mdb(), dbname = path)
  on.exit(DBI::dbDisconnect(con))
  raw <- mdbr:::.native_read_table(path, table)
  expected <- mdbr:::.coerce_mdb_data_frame(mdbr:::.as_data_frame(raw), raw)
  binary <- attr(raw, "mdb_col_types") %in%
    c(mdbr:::.MDB_TYPE$OLE, mdbr:::.MDB_TYPE$BINARY)
  expected <- expected[, !binary, drop = FALSE]
  res <- mdb_stream_table(con, table)
  on.exit(DBI::dbClearResult(res), add = TRUE)
  expect_identical(DBI::dbIsValid(res), TRUE)
  expect_identical(nrow(res@data), 0L)
  expect_identical(
    DBI::dbFetch(res, 0L)[, !binary, drop = FALSE],
    expected[0, , drop = FALSE]
  )
  expect_identical(res@state$position, 0L)
  parts <- list()
  repeat {
    part <- DBI::dbFetch(res, n = 7L)
    part <- part[, !binary, drop = FALSE]
    if (!nrow(part)) {
      break
    }
    parts[[length(parts) + 1L]] <- part
    expect_lte(nrow(part), 7L)
    expect_identical(names(part), names(expected))
    expect_identical(lapply(part, class), lapply(expected, class))
  }
  combined <- if (length(parts)) {
    do.call(rbind, parts)
  } else {
    expected[0, , drop = FALSE]
  }
  rownames(combined) <- NULL
  expect_identical(combined, expected)
  expect_identical(DBI::dbHasCompleted(res), TRUE)
  expect_identical(
    DBI::dbFetch(res, 2L)[, !binary, drop = FALSE],
    expected[0, , drop = FALSE]
  )
  expect_identical(DBI::dbIsValid(res), TRUE)
  expect_identical(DBI::dbClearResult(res), TRUE)
  expect_identical(DBI::dbClearResult(res), TRUE)
  expect_identical(DBI::dbIsValid(res), FALSE)
}

test_that("Decimal values survive cursor reads in MDB and ACCDB files", {
  for (extension in c("mdb", "accdb")) {
    path <- testthat::test_path(paste0("decimal.", extension))
    con <- DBI::dbConnect(mdb(), dbname = path)
    raw <- mdbr:::.native_read_table(path, "Decimals")
    expect_identical(attr(raw, "mdb_col_types"), 16L)
    res <- mdb_stream_table(con, "Decimals")
    expect_identical(DBI::dbFetch(res, 2L)$Amount, c(123.45, -0.5))
    DBI::dbClearResult(res)
    expect_identical(
      DBI::dbReadTable(con, "Decimals")$Amount,
      c(123.45, -0.5, NA_real_)
    )
    expect_identical(
      read_mdb(path, "Decimals")$Amount,
      c(123.45, -0.5, NA_real_)
    )
    DBI::dbDisconnect(con)
  }
})

test_that("large fetch requests only allocate for available rows", {
  path <- testthat::test_path("decimal.mdb")
  con <- DBI::dbConnect(mdb(), dbname = path)
  on.exit(DBI::dbDisconnect(con))
  res <- mdb_stream_table(con, "Decimals")
  on.exit(DBI::dbClearResult(res), add = TRUE)
  expect_identical(
    DBI::dbFetch(res, n = 300000000L)$Amount,
    c(123.45, -0.5, NA_real_)
  )
  expect_identical(DBI::dbHasCompleted(res), TRUE)
})

test_that("MDB table cursor advances without materializing on open", {
  path <- mdb_example()
  skip_if_not(file.exists(path))
  stream_fixture(path, "Umsätze")
  con <- DBI::dbConnect(mdb(), dbname = path)
  on.exit(DBI::dbDisconnect(con))
  res <- mdb_stream_table(con, "Umsätze")
  expect_identical(res@state$position, 0L)
  expect_identical(nrow(res@data), 0L)
  expect_identical(nrow(DBI::dbFetch(res, 1L)), 1L)
  expect_identical(res@state$position, 1L)
  DBI::dbClearResult(res)
  expect_snapshot(error = TRUE, DBI::dbFetch(res, 1L))
  expect_identical(DBI::dbClearResult(res), TRUE)
})

test_that("Northwind joins agree with source table keys", {
  path <- mdb_example()
  skip_if_not(file.exists(path))
  con <- DBI::dbConnect(mdb(), dbname = path)
  on.exit(DBI::dbDisconnect(con))
  details <- DBI::dbReadTable(con, "Order Details")
  orders <- DBI::dbReadTable(con, "Orders")
  products <- DBI::dbReadTable(con, "Products")
  expect_identical(sum(is.na(match(details$OrderID, orders$OrderID))), 0L)
  expect_identical(sum(is.na(match(details$ProductID, products$ProductID))), 0L)
  expect_gt(length(unique(details$OrderID)), 1L)
})

test_that("MDB OLE fields retain populated raw bytes", {
  path <- mdb_example()
  skip_if_not(file.exists(path))
  stream_fixture(path, "Categories")
  con <- DBI::dbConnect(mdb(), dbname = path)
  on.exit(DBI::dbDisconnect(con))
  res <- mdb_stream_table(con, "Categories")
  on.exit(DBI::dbClearResult(res), add = TRUE)
  picture <- DBI::dbFetch(res, 1L)$Picture[[1L]]
  expect_type(picture, "raw")
  expect_gt(length(picture), 0L)
  expect_identical(picture[[4L]], as.raw(0))
})

test_that("native cursor distinguishes null and empty values", {
  path <- mdb_example()
  skip_if_not(file.exists(path))
  con <- DBI::dbConnect(mdb(), dbname = path)
  on.exit(DBI::dbDisconnect(con))
  res <- mdb_stream_table(con, "Umsätze")
  on.exit(DBI::dbClearResult(res), add = TRUE)
  first <- DBI::dbFetch(res, 2L)
  expect_identical(is.na(first$ShipRegion), c(FALSE, TRUE))
  expect_identical(first$ShipRegion[[1L]], "Lara")
})

test_that("ACCDB table cursor matches eager read", {
  path <- testthat::test_path("mdbtestdata", "data", "ASampleDatabase.accdb")
  skip_if_not(file.exists(path))
  stream_fixture(path, "Asset Items")
  con <- DBI::dbConnect(mdb(), dbname = path)
  expect_identical(mdb_ver(path) |> grepl(pattern = "^ACE"), TRUE)
  expect_identical(DBI::dbListFields(con, "Asset Items")[[1L]], "Asset No")
  on.exit(DBI::dbDisconnect(con))
  res <- mdb_stream_table(con, "Asset Items")
  on.exit(DBI::dbClearResult(res), add = TRUE)
  expect_identical(nrow(DBI::dbFetch(res, 1L)), 1L)
  expect_identical(DBI::dbClearResult(res), TRUE)
  expect_identical(DBI::dbIsValid(res), FALSE)
})
