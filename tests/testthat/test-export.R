library(testthat)
library(mdbr)

test_that("tables can be exported as strings", {
  skip_on_cran()
  skip_if_not(has_mdb_tools())
  dat <- export_mdb(mdb_example(), "Airlines", output = TRUE)
  expect_type(dat, "character")
  expect_length(dat, 1)
})

test_that("tables can be exported to file", {
  skip_on_cran()
  skip_if_not(has_mdb_tools())
  tmp <- tempfile()
  dat <- export_mdb(mdb_example(), "Airlines", output = tmp)
  expect_true(file.exists(tmp))
  expect_equal(file.size(tmp), 450)
})

test_that("tables can be exported without escape", {
  skip_on_cran()
  skip_if_not(has_mdb_tools())
  dat <- export_mdb(
    file = mdb_example(),
    table = "Airlines",
    output = TRUE,
    quote_escape = FALSE
  )
  expect_type(dat, "character")
  expect_length(dat, 1)
})

test_that("exporting errors without table name", {
  skip_on_cran()
  skip_if_not(has_mdb_tools())
  expect_error(export_mdb(mdb_example()))
})
