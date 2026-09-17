source("R/validated_pipeline.R")
result <- run_validated_pipeline()
stopifnot(nrow(result$analytic_cohort) == 9, !anyDuplicated(result$analytic_cohort$participant_id))
readr::write_csv(result$schema_contract, "outputs/schema_recovery.csv")
table_md <- function(d) {
  c(paste0("| ", paste(names(d), collapse = " | "), " |"),
    paste0("| ", paste(rep("---", ncol(d)), collapse = " | "), " |"),
    apply(d, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")))
}
writeLines(c("# Executed administrative-data audit", "",
  "The four committed extracts are intentionally messy and entirely synthetic. The validated R entry point checks source contracts before constructing the analytic cohort. This example does not certify a real organization's data.", "",
  "## Before and after", "", table_md(result$qa_summary), "",
  "## Rule-level disposition", "", table_md(result$exclusion_log), "",
  "Rule counts refer to different source tables and stages; do not add them to infer unique excluded people.", "",
  "## Concrete changes", "",
  "- Duplicate and incomplete enrollment representations are reconciled by the documented ordering rules.",
  "- The synthetic P001 retains the latest valid score (66) and two valid services totaling 105 minutes.",
  "- P007's pre-enrollment service and assessment do not contribute: zero valid services and no valid follow-up score.",
  "- Nine unique eligible participants remain; these conditions are independently asserted in tests.", "",
  "## Schema recovery", "", table_md(result$schema_contract), "",
  "Only identifier representations explicitly accepted by the contract are normalized. Renamed required columns, duplicate crosswalk keys, incompatible IDs, and unknown service categories stop the validated R path.", "",
  "## Coverage and reproduction", "",
  "[R/Stata coverage matrix](../docs/implementation-coverage.md). Run `Rscript scripts/restore_environment.R`, then `Rscript scripts/publish_audit.R`. Run both R test suites and `python tests/validate_fixtures.py`.", "",
  "Only aggregate QA outputs are added to the report. The generated analytic cohort remains ignored.", "",
  "[Reference R session](session-info.txt)"), "outputs/report.md", useBytes = TRUE)
writeLines(capture.output(sessionInfo()), "outputs/session-info.txt", useBytes = TRUE)
