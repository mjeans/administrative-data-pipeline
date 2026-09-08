suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})

source("R/validated_pipeline.R")

copy_fixture_dir <- function() {
  target <- tempfile("schema-drift-fixtures-")
  dir.create(target, recursive = TRUE)
  fixtures <- list.files("data/raw", pattern = "\\.csv$", full.names = TRUE)
  copied <- file.copy(fixtures, target)
  if (!all(copied)) {
    stop("Failed to copy synthetic fixtures for schema-drift test.")
  }
  target
}

read_fixture <- function(dir, name) {
  read_csv(
    file.path(dir, name),
    col_types = cols(.default = col_character()),
    show_col_types = FALSE
  )
}

expect_schema_failure <- function(fn, expected) {
  message_text <- tryCatch(
    {
      fn()
      NA_character_
    },
    error = function(error) conditionMessage(error)
  )

  if (is.na(message_text)) {
    stop(sprintf("Expected schema failure containing: %s", expected))
  }
  if (!grepl(expected, message_text, fixed = TRUE)) {
    stop(
      sprintf(
        "Unexpected schema failure. Expected: %s. Actual: %s",
        expected,
        message_text
      )
    )
  }
}

# Valid inputs must produce the same analytic outputs as the existing pipeline.
baseline <- run_pipeline(
  input_dir = "data/raw",
  output_dir = tempfile("baseline-pipeline-")
)
validated <- run_validated_pipeline(
  input_dir = "data/raw",
  output_dir = tempfile("validated-pipeline-")
)
stopifnot(
  isTRUE(all.equal(baseline$analytic_cohort, validated$analytic_cohort)),
  isTRUE(all.equal(baseline$exclusion_log, validated$exclusion_log)),
  isTRUE(all.equal(baseline$qa_summary, validated$qa_summary))
)

# Required-field drift must fail with source-specific diagnostics.
missing_column_dir <- copy_fixture_dir()
enrollment <- read_fixture(missing_column_dir, "enrollment.csv") |>
  select(-site_code)
write_csv(enrollment, file.path(missing_column_dir, "enrollment.csv"))
expect_schema_failure(
  function() run_validated_pipeline(
    missing_column_dir,
    tempfile("missing-column-output-")
  ),
  "SCH-01 [enrollment] missing required columns: site_code"
)

# Keys that are expected to be unique cannot silently multiply joins.
duplicate_crosswalk_dir <- copy_fixture_dir()
sites <- read_fixture(duplicate_crosswalk_dir, "site_crosswalk.csv")
sites <- bind_rows(sites, sites[1, ])
write_csv(sites, file.path(duplicate_crosswalk_dir, "site_crosswalk.csv"))
expect_schema_failure(
  function() run_validated_pipeline(
    duplicate_crosswalk_dir,
    tempfile("duplicate-crosswalk-output-")
  ),
  "SCH-02 [site_crosswalk.site_code] duplicate key values: A1"
)

# Incompatible participant-ID conventions must not create silent orphan joins.
bad_id_dir <- copy_fixture_dir()
services <- read_fixture(bad_id_dir, "service_events.csv")
services$participant_id[1] <- "STUDENT-001"
write_csv(services, file.path(bad_id_dir, "service_events.csv"))
expect_schema_failure(
  function() run_validated_pipeline(
    bad_id_dir,
    tempfile("bad-id-output-")
  ),
  paste0(
    "SCH-03 [service_events.participant_id] ",
    "unexpected participant identifier format: STUDENT-001"
  )
)

# Numeric or under-padded IDs are safe to canonicalize under the explicit P### contract.
recoverable_id_dir <- copy_fixture_dir()
services <- read_fixture(recoverable_id_dir, "service_events.csv")
services$participant_id[1] <- "1"
write_csv(services, file.path(recoverable_id_dir, "service_events.csv"))
recovered <- run_validated_pipeline(
  recoverable_id_dir,
  tempfile("recoverable-id-output-")
)
p001 <- recovered$analytic_cohort |>
  filter(participant_id == "P001")
service_recovery <- recovered$schema_contract |>
  filter(source == "service_events") |>
  pull(recovered_participant_ids)
stopifnot(
  p001$service_event_count == 2,
  p001$total_service_minutes == 105,
  service_recovery == 1
)

# New categorical codes require an explicit mapping decision.
unknown_mode_dir <- copy_fixture_dir()
services <- read_fixture(unknown_mode_dir, "service_events.csv")
services$mode[1] <- "Hybrid"
write_csv(services, file.path(unknown_mode_dir, "service_events.csv"))
expect_schema_failure(
  function() run_validated_pipeline(
    unknown_mode_dir,
    tempfile("unknown-mode-output-")
  ),
  "SCH-04 [service_events.mode] unexpected categorical values: Hybrid"
)

message("All schema-drift assertions passed.")
