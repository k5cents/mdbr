
<!-- README.md is generated from README.Rmd. Please edit that file -->

# mdbr <img src='man/figures/logo.png' align="right" height="139" />

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
[GitHub](https://github.com/kiernann/mdbr).

``` r
# install.packages("remotes")
remotes::install_github("kiernann/mdbr")
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

The package comes with a version of the
[nycflights13](https://github.com/hadley/nycflights13) relational
database as the `nycflights13.mdb` file.

This example data can be located with `mdb_example()`. The tables in a
database can be listed with `mdb_tables()`.

``` r
library(mdbr)
mdb_tables(ex <- mdb_example())
#> [1] "Airlines" "Airports" "Flights"  "Planes"
```

The schema of a table can be printed as a [readr spec
object](https://readr.tidyverse.org/reference/spec.html).

``` r
mdb_schema(ex, "Flights", condense = TRUE)
#> cols(
#>   .default = col_integer(),
#>   carrier = col_character(),
#>   tailnum = col_character(),
#>   origin = col_character(),
#>   dest = col_character(),
#>   time_hour = col_datetime(format = "")
#> )
```

Those column types are used when reading a table as a text file.

``` r
read_mdb(ex, "Airports")
#> # A tibble: 1,458 x 8
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
#> # … with 1,448 more rows
```

Tables can also be exported to a character vector, the console, or a
text file.

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

<!-- refs: start -->

<!-- refs: end -->
