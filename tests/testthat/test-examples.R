library(testthat)
library(mdbr)

test_that("examples work for path and name", {
  skip_on_cran()
  expect_identical(mdb_example(NULL), "nwind.mdb")
  expect_identical(mdb_example("nwind.mdb"), mdb_example())
  expect_identical(file.exists(mdb_example()), TRUE)
})
