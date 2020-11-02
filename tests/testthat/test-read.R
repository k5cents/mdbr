library(testthat)
library(mdbr)

test_that("tables can be read as data frames", {
  dat <- read_mdb(mdb_example(), "Flights", stdout = tempfile())
  expect_length(dat, 19)
  expect_s3_class(dat, "tbl")
  expect_s3_class(dat$time_hour, "POSIXt")
  expect_type(dat$year, "integer")
  expect_type(dat$carrier, "character")
})

test_that("tables can be read in memory", {
  dat <- read_mdb(mdb_example(), "Flights", stdout = TRUE)
  expect_length(dat, 19)
  expect_s3_class(dat, "tbl")
  expect_s3_class(dat$time_hour, "POSIXt")
  expect_type(dat$year, "integer")
  expect_type(dat$carrier, "character")
})

test_that("reading errors without table name", {
  expect_error(read_mdb(mdb_example()))
})

test_that("reading error when console stdout", {
  expect_error(read_mdb(mdb_example(), "Flights", stdout = ""))
})
