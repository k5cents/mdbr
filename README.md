
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

The package comes with a version of the
[nycflights13](https://github.com/tidyverse/nycflights13) relational
database found with `mdb_examples()`.

The tables in a database can be listed with `mdb_tables()`.

``` r
mdb_tables(ex <- mdb_example())
#> [1] "Airlines" "Airports" "Flights"  "Planes"
```

These tables can be exported as a delimited string or file.

``` r
string <- export_mdb(ex, "Airlines", output = TRUE, delim = "|", quote = "'")
cat(string, sep = "\n")
#> carrier|name
#> '9E'|'Endeavor Air Inc.'
#> 'AA'|'American Airlines Inc.'
#> 'AS'|'Alaska Airlines Inc.'
#> 'B6'|'JetBlue Airways'
#> 'DL'|'Delta Air Lines Inc.'
#> 'EV'|'ExpressJet Airlines Inc.'
#> 'F9'|'Frontier Airlines Inc.'
#> 'FL'|'AirTran Airways Corporation'
#> 'HA'|'Hawaiian Airlines Inc.'
#> 'MQ'|'Envoy Air'
#> 'OO'|'SkyWest Airlines Inc.'
#> 'UA'|'United Air Lines Inc.'
#> 'US'|'US Airways Inc.'
#> 'VX'|'Virgin America'
#> 'WN'|'Southwest Airlines Co.'
#> 'YV'|'Mesa Airlines Inc.'
```

Tables are read directly into R as a tibble with automatic type
coercion.

``` r
read_mdb(ex, "Airports")
#> # A tibble: 1,458 × 8
#>    faa   name                             lat    lon   alt    tz dst   tzone              
#>    <chr> <chr>                          <dbl>  <dbl> <int> <int> <chr> <chr>              
#>  1 04G   Lansdowne Airport               41.1  -80.6  1044    -5 A     America/New_York   
#>  2 06A   Moton Field Municipal Airport   32.5  -85.7   264    -6 A     America/Chicago    
#>  3 06C   Schaumburg Regional             42.0  -88.1   801    -6 A     America/Chicago    
#>  4 06N   Randall Airport                 41.4  -74.4   523    -5 A     America/New_York   
#>  5 09J   Jekyll Island Airport           31.1  -81.4    11    -5 A     America/New_York   
#>  6 0A9   Elizabethton Municipal Airport  36.4  -82.2  1593    -5 A     America/New_York   
#>  7 0G6   Williams County Airport         41.5  -84.5   730    -5 A     America/New_York   
#>  8 0G7   Finger Lakes Regional Airport   42.9  -76.8   492    -5 A     America/New_York   
#>  9 0P2   Shoestring Aviation Airfield    39.8  -76.6  1000    -5 U     America/New_York   
#> 10 0S9   Jefferson County Intl           48.1 -123.    108    -8 A     America/Los_Angeles
#> # ℹ 1,448 more rows
```

The DDL for a table can be retrieved with `mdb_schema(mode = "ddl")`.

``` r
mdb_schema(ex, "Airports", mode = "ddl")
#> [Airports]
#> -- That file uses encoding UTF-8
#> 
#> CREATE TABLE [Airports]
#>  (
#> 	[faa]			Text (255),
#> 	[name]			Text (255),
#> 	[lat]			Double,
#> 	[lon]			Double,
#> 	[alt]			Long Integer,
#> 	[tz]			Integer,
#> 	[dst]			Text (255),
#> 	[tzone]			Text (255)
#> );
```

Column types are returned as a [readr col spec](https://readr.tidyverse.org/reference/cols.html)
(requires the **readr** package). Use `condense = TRUE` to collapse columns
sharing a type.

``` r
mdb_schema(ex, "Airports")
#> cols(
#>   faa = col_character(),
#>   name = col_character(),
#>   lat = col_double(),
#>   lon = col_double(),
#>   alt = col_integer(),
#>   tz = col_integer(),
#>   dst = col_character(),
#>   tzone = col_character()
#> )
```

<!-- refs: start -->

<!-- refs: end -->
