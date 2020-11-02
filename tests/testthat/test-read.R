library(testthat)
library(mdbr)

test_that("tables can be read as data frames", {
  skip_on_cran()
  dat <- read_mdb(mdb_example(), "Flights", stdout = tempfile())
  expect_length(dat, 19)
  expect_s3_class(dat, "tbl")
  expect_s3_class(dat$time_hour, "POSIXt")
  expect_type(dat$year, "integer")
  expect_type(dat$carrier, "character")
})

test_that("tables can be read in memory", {
  skip_on_cran()
  dat <- read_mdb(mdb_example(), "Flights", stdout = TRUE)
  expect_length(dat, 19)
  expect_s3_class(dat, "tbl")
  expect_s3_class(dat$time_hour, "POSIXt")
  expect_type(dat$year, "integer")
  expect_type(dat$carrier, "character")
})

test_that("reading errors without table name", {
  skip_on_cran()
  expect_error(read_mdb(mdb_example()))
})

test_that("reading error when console stdout", {
  skip_on_cran()
  expect_error(read_mdb(mdb_example(), "Flights", stdout = ""))
})
