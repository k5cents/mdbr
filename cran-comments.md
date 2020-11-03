## Test environments
* local R installation (ubuntu 20.04), R 4.0.0
* [ubuntu](https://github.com/kiernann/mdbr/actions) 18.04 (on github-actions), R 4.0.0
* [rhub](https://builder.r-hub.io/status/mdbr_0.1.1.tar.gz-b4490e7b655f472fa88ed1abe473320b): Fedora Linux, R-devel, clang, gfortran
* [rhub](https://builder.r-hub.io/status/mdbr_0.1.1.tar.gz-66a7afa7897f43538970e18ca03ac013): Ubuntu Linux 16.04 LTS, R-release, GCC
* [rhub](https://builder.r-hub.io/status/mdbr_0.1.1.tar.gz-b4490e7b655f472fa88ed1abe473320b): Fedora Linux, R-devel, clang, gfortran

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## System Requirments

The package relies on the open source mdbtools software. See the mdbtools 
[documentation](http://mdbtools.sourceforge.net/install/) for full installation
instructions. The tools are also found on package managers:

* apt install mdbtools
* brew install mdbtools
* rpm -i mdbtools-0.7-1.rpm 

Source code: https://github.com/mdbtools/mdbtools/archive/0.7.1.tar.gz
