
<!-- README.md is generated from README.Rmd. Please edit that file -->

# mdbr

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/mdbr)](https://CRAN.R-project.org/package=mdbr)
[![Codecov test
coverage](https://img.shields.io/codecov/c/github/kiernann/mdbr/master.svg)](https://codecov.io/gh/kiernann/mdbr?branch=master)
![Downloads](https://cranlogs.r-pkg.org/badges/grand-total/mdbr) [![R
build
status](https://github.com/kiernann/mdbr/workflows/R-CMD-check/badge.svg)](https://github.com/kiernann/mdbr/actions)
<!-- badges: end -->

The goal of mdbr is to easily access the open source [MDB
Tools](https://github.com/brianb/mdbtools) written by Brian Bruns. The
MDB Tools command line utilities take proprietary Microsoft Access files
and convert them to standard text files.

## Installation

You can install the released version of mdbr from
[GitHub](https://github.com/kiernann/mdbr) with:

``` r
# install.packages("remotes")
remotes::install_github("kiernann/mdbr")
```

## Example

The package comes with a smaller version of the
[nycflights13](https://github.com/hadley/nycflights13) example RDBMS
database as the `nycflights13.mdb` file. This example data can be
located with `mdb_example()`.

The `mdb_tables()` function returns a simple character vector of table
names.

``` r
library(mdbr)
mdb_tables(ex <- mdb_example())
#> [1] "Airlines" "Airports" "Flights"  "Planes"
```

Those table names can be used to directly read a table as a data frame.

``` r
read_mdb(ex, "Planes")
#> # A tibble: 1,468 x 9
#>    tailnum  year type          manufacturer   model  engines seats speed engine 
#>    <chr>   <dbl> <chr>         <chr>          <chr>    <dbl> <dbl> <dbl> <chr>  
#>  1 N10156   2004 Fixed wing m… EMBRAER        EMB-1…       2    55    NA Turbo-…
#>  2 N103US   1999 Fixed wing m… AIRBUS INDUST… A320-…       2   182    NA Turbo-…
#>  3 N104UW   1999 Fixed wing m… AIRBUS INDUST… A320-…       2   182    NA Turbo-…
#>  4 N10575   2002 Fixed wing m… EMBRAER        EMB-1…       2    55    NA Turbo-…
#>  5 N105UW   1999 Fixed wing m… AIRBUS INDUST… A320-…       2   182    NA Turbo-…
#>  6 N107US   1999 Fixed wing m… AIRBUS INDUST… A320-…       2   182    NA Turbo-…
#>  7 N11109   2002 Fixed wing m… EMBRAER        EMB-1…       2    55    NA Turbo-…
#>  8 N11113   2002 Fixed wing m… EMBRAER        EMB-1…       2    55    NA Turbo-…
#>  9 N11119   2002 Fixed wing m… EMBRAER        EMB-1…       2    55    NA Turbo-…
#> 10 N11121   2003 Fixed wing m… EMBRAER        EMB-1…       2    55    NA Turbo-…
#> # … with 1,458 more rows
```

Or, export to a character string, console, or text file.

``` r
cat(export_mdb(ex, "Airlines", TRUE, "\t", ""), sep = "\n")
#> carrier  name
#> 9E   Endeavor Air Inc.
#> AA   American Airlines Inc.
#> AS   Alaska Airlines Inc.
#> B6   JetBlue Airways
#> DL   Delta Air Lines Inc.
#> EV   ExpressJet Airlines Inc.
#> F9   Frontier Airlines Inc.
#> FL   AirTran Airways Corporation
#> HA   Hawaiian Airlines Inc.
#> MQ   Envoy Air
#> OO   SkyWest Airlines Inc.
#> UA   United Air Lines Inc.
#> US   US Airways Inc.
#> VX   Virgin America
#> WN   Southwest Airlines Co.
#> YV   Mesa Airlines Inc.
```

<!-- refs: start -->

<!-- refs: end -->
