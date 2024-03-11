
<!-- README.md is generated from README.Rmd. Please edit that file -->

# mdbr <img src='man/figures/logo.png' align="right" height="139" />

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/mdbr)](https://CRAN.R-project.org/package=mdbr)
[![Codecov test
coverage](https://img.shields.io/codecov/c/github/k5cents/mdbr/master.svg)](https://codecov.io/gh/k5cents/mdbr?branch=master)
![Downloads](https://cranlogs.r-pkg.org/badges/grand-total/mdbr) [![R
build
status](https://github.com/k5cents/mdbr/workflows/R-CMD-check/badge.svg)](https://github.com/k5cents/mdbr/actions)
[![R-CMD-check](https://github.com/k5cents/mdbr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/k5cents/mdbr/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

The goal of mdbr is to easily access the open source [MDB
Tools](https://github.com/mdbtools/mdbtools) written by Brian Bruns. The
MDB Tools command line utilities take proprietary Microsoft Access files
and convert them to standard text files. This package is experimental
and has only been tested on simple MDB databases.

## Installation

You can install the release version of mdbr from
[CRAN](https://cran.r-project.org/package=mdbr).

``` r
install.packages("mdbr")
```

The development version can be installed from
[GitHub](https://github.com/k5cents/mdbr).

``` r
# install.packages("remotes")
remotes::install_github("k5cents/mdbr")
```

The user must install [MDB Tools](https://github.com/mdbtools/mdbtools)
separately. Users on Debian systems can install the tools from the apt
repository.

``` bash
sudo apt install mdbtools
```

More installation methods can be found on the package’s
[README](https://github.com/mdbtools/mdbtools/blob/dev/README.md).

## Example

``` r
library(mdbr)
library(readr)
```

The package comes with a version of the
[nycflights13](https://github.com/hadley/nycflights13) relational
database found with `mdb_examples()`.

The tables in a database can be listed with `mdb_tables()`.

``` r
mdb_tables(ex <- mdb_example())
#> [1] "Airlines" "Airports" "Flights"  "Planes"
```

These tables can be exported as a delimited string or file.

``` r
string <- export_mdb(ex, "Airlines", output = TRUE, delim = "|", quote = "'")
cat(string)
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

Tables can be easily converted to a temporary file and read immediately.

``` r
read_mdb(ex, "Airports")
#> # A tibble: 1,458 × 8
#>    faa   name                             lat    lon   alt    tz dst   tzone              
#>    <chr> <chr>                          <dbl>  <dbl> <dbl> <dbl> <chr> <chr>              
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

When reading a converted table, you might need to know what types of
data to expect from each column.

The schema of database tables describes the column types.

``` bash
mdb-schema -T Airports nycflights13.mdb
#> -- ----------------------------------------------------------
#> -- MDB Tools - A library for reading MS Access database files
#> -- Copyright (C) 2000-2011 Brian Bruns and others.
#> -- Files in libmdb are licensed under LGPL and the utilities under
#> -- the GPL, see COPYING.LIB and COPYING files respectively.
#> -- Check out http://mdbtools.sourceforge.net
#> -- ----------------------------------------------------------
#> 
#> CREATE TABLE [Airports]
#> (
#>     [faa]            Text (510), 
#>     [name]           Text (510), 
#>     [lat]            Double, 
#>     [lon]            Double, 
#>     [alt]            Long Integer, 
#>     [tz]             Integer, 
#>     [dst]            Text (510), 
#>     [tzone]          Text (510)
#> );
```

This information can be interpreted as a [readr spec
object](https://readr.tidyverse.org/reference/spec.html), which is used
to accurately parse columns of a converted text file.

``` r
mdb_schema(ex, "Airports", condense = TRUE)
#> cols(
#>   .default = col_character(),
#>   lat = col_double(),
#>   lon = col_double(),
#>   alt = col_integer(),
#>   tz = col_integer()
#> )
```

<!-- refs: start -->
<!-- refs: end -->
