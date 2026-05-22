library(testthat)
library(mdbr)

test_that("tables can be read as data frames", {
  skip_on_cran()
  skip_if_not(is.loaded("mdbr_version"))
  dat <- read_mdb(mdb_example(), "Flights")
  expect_length(dat, 19)
  expect_s3_class(dat, "tbl_df")
  expect_s3_class(dat$time_hour, "POSIXct")
  expect_type(dat$year, "integer")
  expect_type(dat$carrier, "character")
})

test_that("tables can be read in memory", {
  skip_on_cran()
  skip_if_not(is.loaded("mdbr_version"))
  dat <- read_mdb(mdb_example(), "Flights")
  expect_length(dat, 19)
  expect_s3_class(dat, "tbl_df")
  expect_s3_class(dat$time_hour, "POSIXct")
  expect_type(dat$year, "integer")
  expect_type(dat$carrier, "character")
})

test_that("reading errors without table name", {
  skip_on_cran()
  skip_if_not(is.loaded("mdbr_version"))
  expect_error(read_mdb(mdb_example()))
})
