# Explicit schema-contract checks for administrative-data inputs.

suppressPackageStartupMessages({
  library(readr)
  library(stringr)
})

schema_failure <- function(rule_id, source, detail) {
  stop(
    sprintf("%s [%s] %s", rule_id, source, detail),
    call. = FALSE
  )
}

required_columns <- list(
  site_crosswalk = c("site_code", "site_id", "region", "urbanicity"),
  enrollment = c(
    "raw_id", "site_code", "enroll_date", "dob", "gender",
    "language", "baseline_score"
  ),
  service_events = c(
    "event_id", "participant_id", "service_date", "minutes", "mode"
  ),
  outcomes = c(
    "assessment_id", "participant_id", "assessment_date",
    "outcome_score", "assessment_type"
  )
)

read_contract_csv <- function(input_dir, source) {
  path <- file.path(input_dir, paste0(source, ".csv"))
  if (!file.exists(path)) {
    schema_failure("SCH-01", source, "required source file is missing")
  }

  data <- read_csv(
    path,
    col_types = cols(.default = col_character()),
    show_col_types = FALSE
  )

  missing <- setdiff(required_columns[[source]], names(data))
  if (length(missing) > 0L) {
    schema_failure(
      "SCH-01",
      source,
      sprintf(
        "missing required columns: %s",
        paste(missing, collapse = ", ")
      )
    )
  }

  data
}

canonical_participant_id <- function(x, source = "participant_id") {
  value <- toupper(trimws(as.character(x)))
  value[value == ""] <- NA_character_

  invalid <- !is.na(value) & !str_detect(value, "^P?\\d{1,3}$")
  if (any(invalid)) {
    schema_failure(
      "SCH-03",
      source,
      sprintf(
        "unexpected participant identifier format: %s",
        paste(sort(unique(value[invalid])), collapse = ", ")
      )
    )
  }

  recoverable <- !is.na(value) & (
    str_detect(value, "^\\d{1,3}$") |
      str_detect(value, "^P\\d{1,2}$")
  )

  canonical <- value
  canonical[!is.na(value)] <- sprintf(
    "P%03d",
    as.integer(str_remove(value[!is.na(value)], "^P"))
  )

  attr(canonical, "recovered_n") <- sum(recoverable)
  canonical
}

canonical_service_mode <- function(x) {
  raw <- str_to_lower(str_replace_all(trimws(as.character(x)), "-", " "))
  canonical <- dplyr::case_when(
    raw == "in person" ~ "In person",
    raw == "virtual" ~ "Virtual",
    raw == "phone" ~ "Phone",
    TRUE ~ NA_character_
  )

  invalid <- !is.na(raw) & nzchar(raw) & is.na(canonical)
  blank <- is.na(raw) | !nzchar(raw)
  if (any(invalid | blank)) {
    bad <- unique(trimws(as.character(x[invalid | blank])))
    bad[is.na(bad) | bad == ""] <- "<blank>"
    schema_failure(
      "SCH-04",
      "service_events.mode",
      sprintf(
        "unexpected categorical values: %s",
        paste(sort(bad), collapse = ", ")
      )
    )
  }

  canonical
}

validate_unique_key <- function(data, source, key) {
  value <- toupper(trimws(as.character(data[[key]])))
  value[value == ""] <- NA_character_

  if (any(is.na(value))) {
    schema_failure(
      "SCH-02",
      paste0(source, ".", key),
      "required key contains blank values"
    )
  }

  duplicate_values <- sort(unique(value[duplicated(value)]))
  if (length(duplicate_values) > 0L) {
    schema_failure(
      "SCH-02",
      paste0(source, ".", key),
      sprintf(
        "duplicate key values: %s",
        paste(duplicate_values, collapse = ", ")
      )
    )
  }

  invisible(TRUE)
}

validate_input_contract <- function(input_dir = "data/raw") {
  site_crosswalk <- read_contract_csv(input_dir, "site_crosswalk")
  enrollment <- read_contract_csv(input_dir, "enrollment")
  services <- read_contract_csv(input_dir, "service_events")
  outcomes <- read_contract_csv(input_dir, "outcomes")

  validate_unique_key(site_crosswalk, "site_crosswalk", "site_code")

  enrollment_ids <- canonical_participant_id(
    enrollment$raw_id,
    "enrollment.raw_id"
  )
  service_ids <- canonical_participant_id(
    services$participant_id,
    "service_events.participant_id"
  )
  outcome_ids <- canonical_participant_id(
    outcomes$participant_id,
    "outcomes.participant_id"
  )
  service_modes <- canonical_service_mode(services$mode)

  recovery <- data.frame(
    source = c("enrollment", "service_events", "outcomes"),
    recovered_participant_ids = c(
      attr(enrollment_ids, "recovered_n"),
      attr(service_ids, "recovered_n"),
      attr(outcome_ids, "recovered_n")
    )
  )

  enrollment$raw_id <- as.vector(enrollment_ids)
  services$participant_id <- as.vector(service_ids)
  services$mode <- service_modes
  outcomes$participant_id <- as.vector(outcome_ids)

  invisible(
    list(
      site_crosswalk = site_crosswalk,
      enrollment = enrollment,
      service_events = services,
      outcomes = outcomes,
      participant_id_recovery = recovery
    )
  )
}

prepare_validated_input <- function(input_dir = "data/raw") {
  contract <- validate_input_contract(input_dir)
  prepared_dir <- tempfile("validated-admin-input-")
  dir.create(prepared_dir, recursive = TRUE)

  write_csv(
    contract$site_crosswalk,
    file.path(prepared_dir, "site_crosswalk.csv")
  )
  write_csv(
    contract$enrollment,
    file.path(prepared_dir, "enrollment.csv")
  )
  write_csv(
    contract$service_events,
    file.path(prepared_dir, "service_events.csv")
  )
  write_csv(
    contract$outcomes,
    file.path(prepared_dir, "outcomes.csv")
  )

  invisible(
    list(
      input_dir = prepared_dir,
      participant_id_recovery = contract$participant_id_recovery
    )
  )
}
