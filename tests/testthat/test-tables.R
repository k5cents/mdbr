library(testthat)
library(mdbr)

test_that("tables can be listed as vector", {
  skip_on_cran()
  skip_if_not(has_mdb_tools())
  t <- mdb_tables(mdb_example())
  expect_type(t, "character")
  expect_length(t, 4)
})
