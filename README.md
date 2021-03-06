
<!-- README.md is generated from README.Rmd. Please edit that file -->

# campout: Converting DataCamp material to another, free format

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://www.tidyverse.org/lifecycle/#experimental)
[![Travis build
status](https://travis-ci.org/lwjohnst86/campout.svg?branch=master)](https://travis-ci.org/lwjohnst86/campout)
[![Codecov test
coverage](https://codecov.io/gh/lwjohnst86/campout/branch/master/graph/badge.svg)](https://codecov.io/gh/lwjohnst86/campout?branch=master)
<!-- badges: end -->

The goal of campout is for instructors of a DataCamp course to easily
begin converting their course into an alternative format that allows
others to take their course without having to get a DataCamp
subscription. Use this if you, for instance, want to [distance yourself
from DataCamp](https://noamross.github.io/datacamp-sexual-assault/), had
your course cancelled and still want the material to be available to
others, or you disagree with other aspects of how DataCamp conducts
themselves.

## Installation

You can install the development version from
[GitHub](https://github.com/) with:

``` r
# install.packages("remotes")
remotes::install_github("lwjohnst86/campout")
```

# Usage

So far there is only one conversion to the [learnr
tutorials](https://rstudio.github.io/learnr), with this function:

``` r
datacamp_to_learnr_pkg("path/to/data-camp-course",
                       # Folder the new material will be converted and saved to.
                       "path/to/new-learnr-package",
                       "Your name here")
```

  - **Note**: This roughly converts your DataCamp material to the learnr
    tutorial format… it is *not* perfect\!\! So please make sure to look
    through all your material before publicizing\!
  - Also *note*, so far the slides are only converted to a text
    document, they are not slides. If you have the original videos of
    the slides, you can insert the video link into the chapter
    documents, which will then include the video files for you in the
    tutorial.
