library(testthat)
library(mdbr)

test_that("tables can be exported as strings", {
  dat <- export_mdb(mdb_example(), "Airlines", path = TRUE)
  expect_type(dat, "character")
  expect_length(dat, 17)
})

test_that("tables can be exported to file", {
  tmp <- tempfile()
  dat <- export_mdb(mdb_example(), "Airlines", path = tmp)
  expect_true(file.exists(tmp))
  expect_equal(file.size(tmp), 450)
})


test_that("tables can be printed to console", {
  skip("not sure how to capture console")
  capture_output(
    code = {
      export_mdb(mdb_example(), "Airlines", path = "")
    }
  )
})

test_that("exporting errors without table name", {
  expect_error(export_mdb(mdb_example()))
})
