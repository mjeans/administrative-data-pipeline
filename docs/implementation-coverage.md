# R and Stata implementation coverage

The two paths share a synthetic scenario and documented analytic rules. They are not currently cross-language numerical equivalence tests.

| Check or behavior | Validated R path | Stata companion |
|---|---|---|
| Standardize baseline identifiers and fields | Implemented and CI-tested | Implemented in modular do-files |
| Enrollment, service, outcome deduplication | Implemented and CI-tested | Implemented |
| Site linkage and temporal eligibility | Implemented and CI-tested | Implemented |
| Aggregate QA and exclusion logging | Implemented and CI-tested | Implemented |
| Latest valid outcome and person-level features | Implemented and CI-tested | Implemented |
| Required-column contract with explicit schema failure IDs | Implemented and drift-tested | No equivalent contract wrapper |
| Numeric/under-padded participant-ID recovery | Contract-normalized before analysis; drift-tested | Not covered by the new R recovery tests |
| Duplicate crosswalk / unknown service category contract failures | Explicit pre-analysis failures; drift-tested | Do not assume equivalent early failures |
| Automated execution on GitHub | Both R suites plus Python fixture checks | Not run; commercial Stata required |

Do not report a Stata run as contract-validated solely because the R tests pass. Before a real cross-language handoff, run both systems on the same frozen inputs, compare cohort IDs, field values, rule counts, date handling, and tie resolution, and log any tolerances or intentional differences.
