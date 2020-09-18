library(testthat)
library(mdbr)

test_that("examples work for path and name", {
  expect_equal(mdb_example(NULL), "nycflights13.mdb")
  expect_true(file.exists(mdb_example()))
})
