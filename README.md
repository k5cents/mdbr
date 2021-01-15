
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
#>   carrier = [31mcol_character()[39m,
#>   tailnum = [31mcol_character()[39m,
#>   origin = [31mcol_character()[39m,
#>   dest = [31mcol_character()[39m,
#>   time_hour = [34mcol_datetime(format = "")[39m
#> )
```

Those column types are used when reading a table as a text file.

``` r
read_mdb(ex, "Airports")
#> [90m# A tibble: 1,458 x 8[39m
#>    faa   name                             lat    lon   alt    tz dst   tzone              
#>    [3m[90m<chr>[39m[23m [3m[90m<chr>[39m[23m                          [3m[90m<dbl>[39m[23m  [3m[90m<dbl>[39m[23m [3m[90m<int>[39m[23m [3m[90m<int>[39m[23m [3m[90m<chr>[39m[23m [3m[90m<chr>[39m[23m              
#> [90m 1[39m 04G   Lansdowne Airport               41.1  -[31m80[39m[31m.[39m[31m6[39m  [4m1[24m044    -[31m5[39m A     America/New_York   
#> [90m 2[39m 06A   Moton Field Municipal Airport   32.5  -[31m85[39m[31m.[39m[31m7[39m   264    -[31m6[39m A     America/Chicago    
#> [90m 3[39m 06C   Schaumburg Regional             42.0  -[31m88[39m[31m.[39m[31m1[39m   801    -[31m6[39m A     America/Chicago    
#> [90m 4[39m 06N   Randall Airport                 41.4  -[31m74[39m[31m.[39m[31m4[39m   523    -[31m5[39m A     America/New_York   
#> [90m 5[39m 09J   Jekyll Island Airport           31.1  -[31m81[39m[31m.[39m[31m4[39m    11    -[31m5[39m A     America/New_York   
#> [90m 6[39m 0A9   Elizabethton Municipal Airport  36.4  -[31m82[39m[31m.[39m[31m2[39m  [4m1[24m593    -[31m5[39m A     America/New_York   
#> [90m 7[39m 0G6   Williams County Airport         41.5  -[31m84[39m[31m.[39m[31m5[39m   730    -[31m5[39m A     America/New_York   
#> [90m 8[39m 0G7   Finger Lakes Regional Airport   42.9  -[31m76[39m[31m.[39m[31m8[39m   492    -[31m5[39m A     America/New_York   
#> [90m 9[39m 0P2   Shoestring Aviation Airfield    39.8  -[31m76[39m[31m.[39m[31m6[39m  [4m1[24m000    -[31m5[39m U     America/New_York   
#> [90m10[39m 0S9   Jefferson County Intl           48.1 -[31m123[39m[31m.[39m    108    -[31m8[39m A     America/Los_Angeles
#> [90m# … with 1,448 more rows[39m
```

Tables can also be exported to a character vector, the console, or a
text file.

``` r
string <- export_mdb(ex, "Airlines", path = TRUE, delim = "|", quote = "'")
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

<!-- refs: start -->

<!-- refs: end -->
