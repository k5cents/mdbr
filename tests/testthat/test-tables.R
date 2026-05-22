library(testthat)
library(mdbr)

test_that("tables can be listed as vector", {
  skip_on_cran()
  skip_if_not(is.loaded("mdbr_version"))
  t <- mdb_tables(mdb_example())
  expect_type(t, "character")
  expect_length(t, 4)
})
