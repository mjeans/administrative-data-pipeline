# Bootstrap renv, then restore exactly the versions in renv.lock.
if (getRversion() < "4.6.0") stop("Use R 4.6.x (reference version 4.6.1).")
dir.create(".r-library", showWarnings = FALSE)
.libPaths(c(normalizePath(".r-library"), .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"))
if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv", lib = ".r-library")
renv::restore(project = ".", library = ".r-library", lockfile = "renv.lock", prompt = FALSE)
cat("Restored the project-local package library. Run analysis from the repository root.\n")
