library(testthat)
library(mdbr)

test_that("tables can be read as data frames", {
  skip_on_cran()
  skip_if_not(is.loaded("mdbr_version"))
  dat <- read_mdb(mdb_example(), "Products")
  expect_length(dat, 10)
  expect_s3_class(dat, "tbl_df")
  expect_type(dat$ProductID, "integer")
  expect_type(dat$ProductName, "character")
  expect_type(dat$UnitPrice, "double")
})

test_that("tables can be read in memory", {
  skip_on_cran()
  skip_if_not(is.loaded("mdbr_version"))
  dat <- read_mdb(mdb_example(), "Products")
  expect_length(dat, 10)
  expect_s3_class(dat, "tbl_df")
  expect_type(dat$ProductID, "integer")
  expect_type(dat$ProductName, "character")
  expect_type(dat$UnitPrice, "double")
})

test_that("reading errors without table name", {
  skip_on_cran()
  skip_if_not(is.loaded("mdbr_version"))
  expect_error(read_mdb(mdb_example()))
})
