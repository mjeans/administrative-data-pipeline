# Versioned R environment

The committed `renv.lock` records R 4.6.1 and the packages actually used for the September 2026 reference run, including recursive dependencies. Packages are restored into the ignored project-local `.r-library`; the small `.Rprofile` adds that library when R starts in this repository.

```bash
Rscript scripts/restore_environment.R
```

Then run the README's analysis stages or `make all` where provided. Start a fresh R process after restoration. On Linux, scientific SVG generation may require fontconfig, FreeType, HarfBuzz, and FriBidi development libraries; CI installs these before restoring packages.

The restore step may bootstrap a current `renv` if none is available; the lockfile subsequently restores the recorded `renv` version too. Update the lock only after rerunning the analysis and tests. Do not blindly snapshot a personal library.

RNG seeds and numeric checks support reproducibility; fonts, operating systems, BLAS implementations, and graphics devices can still cause small rendering or floating-point differences. The reference session manifest records the executed environment, not a guarantee of bitwise equivalence across platforms. CI reruns the analyses using the lock.
