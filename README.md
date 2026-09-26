
<!-- README.md is generated from README.Rmd. Please edit that file -->

# mdbr <img src='man/figures/logo.png' align="right" height="139" />

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental))
[![CRAN
status](https://www.r-pkg.org/badges/version/mdbr)](https://CRAN.R-project.org/package=mdbr)
[![Codecov test
coverage](https://img.shields.io/codecov/c/github/k5cents/mdbr/master.svg)](https://app.codecov.io/gh/k5cents/mdbr?branch=master)
![Downloads](https://cranlogs.r-pkg.org/badges/grand-total/mdbr) [![R
build
status](https://github.com/k5cents/mdbr/workflows/R-CMD-check/badge.svg)](https://github.com/k5cents/mdbr/actions)
<!-- badges: end -->

The goal of mdbr is to easily access the open source [MDB
Tools](https://github.com/mdbtools/mdbtools) written by Brian Bruns. The
MDB Tools C library is now bundled with the package — no external
installation is required. This package reads proprietary Microsoft
Access files directly and returns standard R data frames.

## Installation

You can install the release version of mdbr from
[CRAN](https://cran.r-project.org/package=mdbr).

``` r
install.packages("mdbr")
```

The development version can be installed from
[GitHub](https://github.com/k5cents/mdbr/).

``` r
# install.packages("remotes")
remotes::install_github("k5cents/mdbr")
```

## Example

``` r
library(mdbr)
```

The package bundles the [Northwind Access
database](https://github.com/mdbtools/mdbtestdata), including related
tables, foreign keys, and non-ASCII names. Find it with `mdb_example()`.

The tables in a database can be listed with `mdb_tables()`.

``` r
mdb_tables(ex <- mdb_example())
#> [1] "Order Details" "Orders"        "Products"      "Shippers"      "Categories"    "Customers"     "Employees"     "Suppliers"     "Umsätze"
```

These tables can be exported as a delimited string or file.

``` r
string <- export_mdb(ex, "Shippers", output = TRUE, delim = "|", quote = "'")
cat(string, sep = "\n")
#> ShipperID|CompanyName|Phone
#> '1'|'Speedy Express'|'(503) 555-9831'
#> '2'|'United Package'|'(503) 555-3199'
#> '3'|'Federal Shipping'|'(503) 555-9931'
```

Tables are read directly into R as a tibble with automatic type
coercion.

``` r
read_mdb(ex, "Shippers")
#> # A tibble: 3 × 3
#>   ShipperID CompanyName      Phone
#>       <int> <chr>            <chr>
#> 1         1 Speedy Express   (503) 555-9831
#> 2         2 United Package   (503) 555-3199
#> 3         3 Federal Shipping (503) 555-9931
```

The DDL for a table can be retrieved with `mdb_schema(mode = "ddl")`.

``` r
mdb_schema(ex, "Shippers", mode = "ddl")
#> [Shippers]
#> -- That file uses encoding UTF-8
#> 
#> CREATE TABLE [Shippers]
#>  (
#>  [ShipperID]         Long Integer,
#>  [CompanyName]           Text (40) NOT NULL,
#>  [Phone]         Text (24)
#> );
```

Column types are returned as a [readr col
spec](https://readr.tidyverse.org/reference/cols.html) (requires the
**readr** package). Use `condense = TRUE` to collapse columns sharing a
type.

``` r
mdb_schema(ex, "Shippers")
#> cols(
#>   ShipperID = col_integer(),
#>   CompanyName = col_character(),
#>   Phone = col_character()
#> )
```

<!-- refs: start -->

<!-- refs: end -->
