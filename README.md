# ASTR 1040 Cloudy Night Activity

This folder contains some sample SBO observation FITS files that you can use to put together a pretty picture of the Ring Nebula! The notebook [Imaging1040.ipynb](Imaging1040.ipynb) is your "assignment" and is a guided approach that walks you through step by step on how to reduce data from a telescope and produce a pretty, science ready image. You won't have to actually code anything, but simply run the cells and answer some questions at the bottom, but if you're curious and interested feel free to play with it! The notebook code is relatively well commented so you should (hopefully) be able to understand what's going on even if you've never programmed before. The script [ImagingWorkshop.jl](ImagingWorkshop.jl) will do everything automatically to produce a pretty picture, and you can run it right away as long as you have Julia installed. it should also work for any set of FITS files so long as they follow the same naming conventions (i.e. the bias frames have BIAS in them, the HDUs indicate the r,g,b filters, etc.).

**Important**: You have to download the whole repository with all the FITS files for this to work right! You can do that with the big green button in the upper right.

## Prerequisites:

### Note: We will walk through doing all of this in class.

**Julia** (version > 1.6) &mdash; you can find installation instructions for your operating system [here](https://julialang.org/downloads/).

You will then need to install the following Julia packages: IJulia, DataFrames, Plots, FITSIO, StatsBase, Statistics, Images, and FileIO. You can do this by entering the Julia REPL (i.e. launch Julia from the start menu, type julia in the command line window, etc. until you see the `julia>` prompt) and then typing the right bracket (`]`) key to get to the package manager. From there you should see something that looks like:

```julia
(@v1.6) pkg>
```

Then you can just type `add IJulia, DataFrames, Plots, FITSIO, StatsBase, Statistics, Images, FileIO` and they should all install *automagically*.

You should then be able to launch the Jupyter notebook, assuming you already have that installed. If you don't, getting that is easy also! There are many ways to do this, but one easy/fast way is to just install [Anaconda](https://www.anaconda.com/download/), which will include all of the Jupyter tools. Then launch Anaconda Navigator and click the Jupyter notebook icon and you should be in business.

Enjoy!

![M57RGB](M57RGB.png)
