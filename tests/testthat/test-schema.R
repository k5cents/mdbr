library(testthat)
library(mdbr)

test_that("schema returns a col_spec with expected columns", {
  skip_on_cran()
  skip_if_not(is.loaded("mdbr_version"))
  skip_if_not_installed("readr")
  dat <- mdb_schema(mdb_example(), "Flights")
  expect_s3_class(dat, "col_spec")
  expect_length(dat$cols, 19L)
})

test_that("schema condense returns condensed col_spec", {
  skip_on_cran()
  skip_if_not(is.loaded("mdbr_version"))
  skip_if_not_installed("readr")
  dat <- mdb_schema(mdb_example(), "Flights", condense = TRUE)
  expect_s3_class(dat, "col_spec")
})

test_that("schema errors without table", {
  skip_on_cran()
  skip_if_not(is.loaded("mdbr_version"))
  expect_error(mdb_schema(mdb_example()))
})
