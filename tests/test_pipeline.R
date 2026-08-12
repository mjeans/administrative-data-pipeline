suppressPackageStartupMessages({
  library(dplyr)
})

source("R/pipeline.R")

output_dir <- tempfile("administrative-pipeline-")
result <- run_pipeline(
  input_dir = "data/raw",
  output_dir = output_dir
)

expected_ids <- c(
  "P001", "P002", "P003", "P007", "P008",
  "P009", "P010", "P011", "P012"
)

stopifnot(
  setequal(result$analytic_cohort$participant_id, expected_ids),
  nrow(result$analytic_cohort) == 9,
  !anyDuplicated(result$analytic_cohort$participant_id)
)

p001 <- result$analytic_cohort |>
  filter(participant_id == "P001")
stopifnot(
  p001$followup_score == 66,
  p001$service_event_count == 2,
  p001$total_service_minutes == 105
)

p007 <- result$analytic_cohort |>
  filter(participant_id == "P007")
stopifnot(
  p007$service_event_count == 0,
  is.na(p007$followup_score)
)

p003 <- result$analytic_cohort |>
  filter(participant_id == "P003")
stopifnot(
  p003$baseline_score == 48,
  p003$service_event_count == 2
)

expected_rules <- c(
  "ENR-01", "ENR-02", "ENR-03", "ENR-04",
  "SVC-01", "SVC-02", "SVC-03", "SVC-04",
  "OUT-01", "OUT-02", "OUT-03", "OUT-04", "OUT-05"
)
stopifnot(
  setequal(result$exclusion_log$rule_id, expected_rules)
)

message("All pipeline assertions passed.")
