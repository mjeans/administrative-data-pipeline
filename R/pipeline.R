# Companion R implementation of the administrative-data pipeline.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tibble)
})

parse_mixed_date <- function(x) {
  x <- trimws(as.character(x))
  result <- as.Date(rep(NA_character_, length(x)))

  for (format in c("%Y-%m-%d", "%m/%d/%Y")) {
    unresolved <- is.na(result) & !is.na(x) & nzchar(x)
    result[unresolved] <- as.Date(x[unresolved], format = format)
  }

  result
}

standardize_id <- function(x) {
  value <- toupper(trimws(as.character(x)))
  value[value == ""] <- NA_character_
  value
}

run_pipeline <- function(
  input_dir = "data/raw",
  output_dir = "outputs"
) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  audit_rows <- list()
  add_audit <- function(source, rule_id, description, n_records) {
    audit_rows[[length(audit_rows) + 1L]] <<- tibble(
      source = source,
      rule_id = rule_id,
      description = description,
      n_records = as.integer(n_records)
    )
  }

  site_crosswalk <- read_csv(
    file.path(input_dir, "site_crosswalk.csv"),
    col_types = cols(.default = col_character())
  ) |>
    transmute(
      site_code = standardize_id(site_code),
      site_id = standardize_id(site_id),
      region = str_to_title(trimws(region)),
      urbanicity = str_to_title(trimws(urbanicity))
    )

  enrollment_raw <- read_csv(
    file.path(input_dir, "enrollment.csv"),
    col_types = cols(.default = col_character())
  )

  enrollment <- enrollment_raw |>
    transmute(
      source_row = row_number(),
      participant_id = standardize_id(raw_id),
      site_code = standardize_id(site_code),
      enrollment_date = parse_mixed_date(enroll_date),
      date_of_birth = parse_mixed_date(dob),
      gender = case_when(
        str_to_upper(trimws(gender)) %in% c("F", "FEMALE") ~ "Female",
        str_to_upper(trimws(gender)) %in% c("M", "MALE") ~ "Male",
        TRUE ~ str_to_title(trimws(gender))
      ),
      language = str_to_title(trimws(language)),
      baseline_score = suppressWarnings(as.numeric(baseline_score))
    )

  add_audit(
    "enrollment",
    "ENR-01",
    "Blank participant identifier",
    sum(is.na(enrollment$participant_id))
  )

  duplicate_rows <- enrollment |>
    filter(!is.na(participant_id)) |>
    count(participant_id) |>
    summarise(n = sum(pmax(n - 1L, 0L))) |>
    pull(n)
  add_audit(
    "enrollment",
    "ENR-02",
    "Duplicate participant record removed",
    duplicate_rows
  )

  enrollment_deduplicated <- enrollment |>
    filter(!is.na(participant_id)) |>
    mutate(
      completeness =
        !is.na(baseline_score) +
        !is.na(enrollment_date) +
        !is.na(date_of_birth) +
        !is.na(site_code)
    ) |>
    arrange(
      participant_id,
      desc(completeness),
      enrollment_date,
      source_row
    ) |>
    distinct(participant_id, .keep_all = TRUE) |>
    select(-completeness) |>
    left_join(site_crosswalk, by = "site_code") |>
    mutate(
      invalid_site_flag = is.na(site_id),
      invalid_score_flag =
        is.na(baseline_score) |
        baseline_score < 0 |
        baseline_score > 100,
      invalid_date_flag =
        is.na(enrollment_date) |
        is.na(date_of_birth)
    )

  invalid_site <- enrollment_deduplicated$invalid_site_flag
  invalid_score <- enrollment_deduplicated$invalid_score_flag
  invalid_date <- enrollment_deduplicated$invalid_date_flag

  add_audit(
    "enrollment",
    "ENR-03",
    "Site code did not resolve",
    sum(invalid_site)
  )
  add_audit(
    "enrollment",
    "ENR-04",
    "Invalid baseline score",
    sum(invalid_score & !invalid_site)
  )
  add_audit(
    "enrollment",
    "ENR-05",
    "Unparseable required date",
    sum(invalid_date & !invalid_site & !invalid_score)
  )

  eligible <- enrollment_deduplicated |>
    filter(
      !invalid_site_flag,
      !invalid_score_flag,
      !invalid_date_flag
    ) |>
    mutate(
      age_at_enrollment = floor(
        as.numeric(enrollment_date - date_of_birth) / 365.25
      )
    ) |>
    select(
      participant_id,
      site_id,
      region,
      urbanicity,
      enrollment_date,
      age_at_enrollment,
      gender,
      language,
      baseline_score
    )

  service_raw <- read_csv(
    file.path(input_dir, "service_events.csv"),
    col_types = cols(.default = col_character())
  )

  services <- service_raw |>
    transmute(
      source_row = row_number(),
      event_id = standardize_id(event_id),
      participant_id = standardize_id(participant_id),
      service_date = parse_mixed_date(service_date),
      service_minutes = suppressWarnings(as.numeric(minutes)),
      service_mode = case_when(
        str_to_lower(str_replace_all(trimws(mode), "-", " ")) ==
          "in person" ~ "In person",
        str_to_lower(trimws(mode)) == "virtual" ~ "Virtual",
        str_to_lower(trimws(mode)) == "phone" ~ "Phone",
        TRUE ~ str_to_title(trimws(mode))
      )
    )

  service_duplicate_n <- sum(
    duplicated(services$event_id) & !is.na(services$event_id)
  )
  add_audit(
    "service_events",
    "SVC-01",
    "Duplicate event removed",
    service_duplicate_n
  )

  services <- services |>
    arrange(event_id, source_row) |>
    distinct(event_id, .keep_all = TRUE) |>
    mutate(
      invalid_minutes_flag =
        is.na(service_minutes) |
        service_minutes < 1 |
        service_minutes > 480
    )

  invalid_minutes <- services$invalid_minutes_flag
  add_audit(
    "service_events",
    "SVC-02",
    "Invalid service duration",
    sum(invalid_minutes)
  )

  services_linked <- services |>
    filter(!invalid_minutes_flag) |>
    select(-invalid_minutes_flag) |>
    left_join(
      eligible |>
        select(participant_id, enrollment_date),
      by = "participant_id"
    ) |>
    mutate(
      orphan_service_flag = is.na(enrollment_date),
      before_enrollment_flag =
        !orphan_service_flag &
        service_date < enrollment_date
    )

  orphan_service <- services_linked$orphan_service_flag
  add_audit(
    "service_events",
    "SVC-03",
    "Participant not in eligible cohort",
    sum(orphan_service)
  )

  before_enrollment <- services_linked$before_enrollment_flag
  add_audit(
    "service_events",
    "SVC-04",
    "Service preceded enrollment",
    sum(before_enrollment, na.rm = TRUE)
  )

  valid_services <- services_linked |>
    filter(!orphan_service_flag, !before_enrollment_flag) |>
    select(
      -enrollment_date,
      -orphan_service_flag,
      -before_enrollment_flag
    )

  service_summary <- valid_services |>
    group_by(participant_id) |>
    summarise(
      service_event_count = n(),
      total_service_minutes = sum(service_minutes),
      first_service_date = min(service_date),
      last_service_date = max(service_date),
      any_virtual_service = as.integer(any(service_mode == "Virtual")),
      .groups = "drop"
    )

  outcome_raw <- read_csv(
    file.path(input_dir, "outcomes.csv"),
    col_types = cols(.default = col_character())
  )

  outcomes <- outcome_raw |>
    transmute(
      source_row = row_number(),
      assessment_id = standardize_id(assessment_id),
      participant_id = standardize_id(participant_id),
      assessment_date = parse_mixed_date(assessment_date),
      outcome_score = suppressWarnings(as.numeric(outcome_score)),
      assessment_type = str_to_title(
        str_replace_all(trimws(assessment_type), "-", " ")
      )
    )

  outcome_duplicate_n <- sum(
    duplicated(outcomes$assessment_id) &
      !is.na(outcomes$assessment_id)
  )
  add_audit(
    "outcomes",
    "OUT-01",
    "Duplicate assessment removed",
    outcome_duplicate_n
  )

  outcomes <- outcomes |>
    arrange(assessment_id, source_row) |>
    distinct(assessment_id, .keep_all = TRUE) |>
    mutate(
      invalid_outcome_flag =
        is.na(outcome_score) |
        outcome_score < 0 |
        outcome_score > 100
    )

  invalid_outcome <- outcomes$invalid_outcome_flag
  add_audit(
    "outcomes",
    "OUT-02",
    "Invalid outcome score",
    sum(invalid_outcome)
  )

  outcomes_linked <- outcomes |>
    filter(!invalid_outcome_flag) |>
    select(-invalid_outcome_flag) |>
    left_join(
      eligible |>
        select(participant_id, enrollment_date),
      by = "participant_id"
    ) |>
    mutate(
      orphan_outcome_flag = is.na(enrollment_date),
      before_enrollment_flag =
        !orphan_outcome_flag &
        assessment_date < enrollment_date
    )

  orphan_outcome <- outcomes_linked$orphan_outcome_flag
  add_audit(
    "outcomes",
    "OUT-03",
    "Participant not in eligible cohort",
    sum(orphan_outcome)
  )

  outcome_before_enrollment <-
    outcomes_linked$before_enrollment_flag
  add_audit(
    "outcomes",
    "OUT-04",
    "Assessment preceded enrollment",
    sum(outcome_before_enrollment, na.rm = TRUE)
  )

  valid_outcomes <- outcomes_linked |>
    filter(!orphan_outcome_flag, !before_enrollment_flag) |>
    select(-orphan_outcome_flag, -before_enrollment_flag)

  earlier_followups <- valid_outcomes |>
    count(participant_id) |>
    summarise(n = sum(pmax(n - 1L, 0L))) |>
    pull(n)
  add_audit(
    "outcomes",
    "OUT-05",
    "Earlier valid follow-up superseded",
    earlier_followups
  )

  latest_outcome <- valid_outcomes |>
    arrange(participant_id, desc(assessment_date), source_row) |>
    distinct(participant_id, .keep_all = TRUE) |>
    transmute(
      participant_id,
      followup_date = assessment_date,
      followup_score = outcome_score
    )

  analytic_cohort <- eligible |>
    left_join(service_summary, by = "participant_id") |>
    left_join(latest_outcome, by = "participant_id") |>
    mutate(
      service_event_count = coalesce(service_event_count, 0L),
      total_service_minutes = coalesce(total_service_minutes, 0),
      any_virtual_service = coalesce(any_virtual_service, 0L),
      any_valid_service = as.integer(service_event_count > 0),
      score_change = followup_score - baseline_score
    ) |>
    arrange(site_id, participant_id)

  exclusion_log <- bind_rows(audit_rows) |>
    filter(n_records > 0)

  qa_summary <- tibble(
    metric = c(
      "raw_enrollment_rows",
      "eligible_participants",
      "raw_service_rows",
      "valid_service_events",
      "raw_outcome_rows",
      "participants_with_valid_followup"
    ),
    value = c(
      nrow(enrollment_raw),
      nrow(analytic_cohort),
      nrow(service_raw),
      nrow(valid_services),
      nrow(outcome_raw),
      sum(!is.na(analytic_cohort$followup_score))
    )
  )

  stopifnot(
    !anyDuplicated(analytic_cohort$participant_id),
    all(analytic_cohort$baseline_score >= 0),
    all(analytic_cohort$baseline_score <= 100),
    all(analytic_cohort$total_service_minutes >= 0)
  )

  write_csv(
    analytic_cohort,
    file.path(output_dir, "analytic_cohort.csv")
  )
  write_csv(
    exclusion_log,
    file.path(output_dir, "exclusion_log.csv")
  )
  write_csv(
    qa_summary,
    file.path(output_dir, "qa_summary.csv")
  )

  invisible(
    list(
      analytic_cohort = analytic_cohort,
      exclusion_log = exclusion_log,
      qa_summary = qa_summary
    )
  )
}

if (sys.nframe() == 0L) {
  run_pipeline()
}
