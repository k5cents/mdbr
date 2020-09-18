library(testthat)
library(mdbr)

test_that("schema returns col spec", {
  dat <- mdb_schema(mdb_example(), "Flights")
  expect_s3_class(dat, "col_spec")
})

test_that("schema can be condensed", {
  a <- mdb_schema(mdb_example(), "Flights")
  b <- mdb_schema(mdb_example(), "Flights", condense = TRUE)
  expect_gt(length(a$cols), length(b$cols))
})

test_that("schema errors without table", {
  expect_error(mdb_schema(mdb_example()))
})
