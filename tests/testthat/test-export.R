library(testthat)
library(mdbr)

test_that("tables can be exported as strings", {
  skip_on_cran()
  dat <- export_mdb(mdb_example(), "Airlines", path = TRUE)
  expect_type(dat, "character")
  expect_length(dat, 17)
})

test_that("tables can be exported to file", {
  skip_on_cran()
  tmp <- tempfile()
  dat <- export_mdb(mdb_example(), "Airlines", path = tmp)
  expect_true(file.exists(tmp))
  expect_equal(file.size(tmp), 450)
})

test_that("exporting errors without table name", {
  skip_on_cran()
  expect_error(export_mdb(mdb_example()))
})
