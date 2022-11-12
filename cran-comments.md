## Test environments
* local R installation (ubuntu 22.10), R 4.2.1
* [ubuntu][gh_act] 18.04 (on github-actions), R 4.0.0
* [rhub][rhub_win]: Fedora Linux, R-devel, clang, gfortran
* [rhub][rhub_ubu]: Ubuntu Linux 16.04 LTS, R-release, GCC
* [rhub][rhub_fed]: Fedora Linux, R-devel, clang, gfortran

Tests and example do not run remotely, as the mdbtools software is needed.

## R CMD check results

0 errors | 0 warnings

## System Requirments

The package relies on the open source mdbtools software. See the mdbtools 
[documentation](http://mdbtools.sourceforge.net/install/) for full installation
instructions. The tools are also found on package managers:

* `apt install mdbtools`
* `brew install mdbtools`
* `rpm -i mdbtools-0.7-1.rpm `

Source code: https://github.com/mdbtools/mdbtools/archive/0.7.1.tar.gz

<!-- links: start -->
[gh_act]: https://github.com/kiernann/mdbr/actions
[rhub_win]: https://builder.r-hub.io/status/mdbr_0.1.1.tar.gz-b4490e7b655f472fa88ed1abe473320b
[rhub_ubu]: https://builder.r-hub.io/status/mdbr_0.1.1.tar.gz-66a7afa7897f43538970e18ca03ac013
[rhub_fed]: https://builder.r-hub.io/status/mdbr_0.1.1.tar.gz-b4490e7b655f472fa88ed1abe473320b
<!-- links: end -->
