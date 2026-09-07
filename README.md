# Administrative data pipeline

A reproducible pipeline for turning four inconsistent administrative extracts into an analysis-ready participant file. The project emphasizes the work that often determines whether an analysis is credible: identifier standardization, schema-contract validation, date parsing, duplicate resolution, record linkage, temporal rules, exclusion tracking, and independent quality checks.

The fixtures are synthetic and intentionally messy. They do not represent a client, organization, or participant.

![Administrative data pipeline audit preview](assets/pipeline-audit-preview.svg)

## Scenario

A multisite service program delivers participant-level files from separate enrollment, service, outcome, and site systems. The extracts disagree on capitalization and date formats, contain duplicate records, and include invalid scores, implausible service durations, orphaned identifiers, and events outside eligible windows. In production, those systems can also drift: a required field may be renamed, identifiers may change representation, crosswalk keys may duplicate, or new categorical codes may appear.

The pipeline answers three operational questions:

1. Can the extracts be reconciled into one trustworthy analytic cohort?
2. Which records were changed or excluded, and can those decisions be audited?
3. Will an upstream schema change fail visibly before it silently alters the analytic file?

## What the pipeline does

~~~mermaid
flowchart LR
    A["Four raw extracts"] --> B["Validate schema contract"]
    B --> C["Normalize safe representations"]
    C --> D["Standardize fields"]
    D --> E["Validate and deduplicate"]
    E --> F["Link records"]
    F --> G["Apply temporal rules"]
    G --> H["Build participant features"]
    H --> I["Export cohort and QA log"]
~~~

The output is one row per eligible participant with enrollment characteristics, service-use measures, latest valid follow-up score, and improvement from baseline. Every exclusion rule contributes an aggregate count to the QA log. Schema-contract failures stop before the analytic file is built and identify the affected source and rule.

## Implementations

- **Stata:** the primary, modular data-management workflow in `stata/`
- **R validated entry point:** schema checks and safe input normalization in `R/validated_pipeline.R`
- **R analytic pipeline:** companion implementation in `R/pipeline.R`
- **Schema contract:** explicit required-field, key, identifier, and category rules in `R/schema_contract.R`
- **Automated validation:** fixture, pipeline, and schema-drift regression checks in `tests/`
- **Continuous integration:** GitHub Actions validates the committed fixtures and runs both R test suites

The implementations are deliberately readable rather than compressed. Intermediate checks are visible so another analyst can review what changed and why.

## Repository structure

~~~text
data/raw/
  enrollment.csv
  service_events.csv
  outcomes.csv
  site_crosswalk.csv
docs/
  data-dictionary.md
  quality-rules.md
  expected-audit.md
R/
  schema_contract.R
  validated_pipeline.R
  pipeline.R
stata/
  00_master.do
  01_clean_enrollment.do
  02_clean_services.do
  03_clean_outcomes.do
  04_build_analytic_file.do
tests/
  validate_fixtures.py
  test_pipeline.R
  test_schema_drift.R
~~~

## Run it

### R

~~~r
install.packages(c("dplyr", "readr", "stringr", "tibble"))
source("R/validated_pipeline.R")
result <- run_validated_pipeline()
~~~

The validated entry point checks the four input contracts first. Safe participant-ID representation differences such as `1`, `001`, `P1`, and `P001` are canonicalized to `P001` in a temporary input copy before the existing analytic pipeline runs. Missing/renamed required fields, duplicate crosswalk keys, incompatible participant-ID formats, and unknown service-mode categories stop with explicit diagnostics rather than being guessed or silently repaired.

The pipeline writes:

- `outputs/analytic_cohort.csv`
- `outputs/exclusion_log.csv`
- `outputs/qa_summary.csv`

`result$schema_contract` also reports how many numeric or under-padded participant identifiers were safely recovered in each source during validation.

### Stata

From the repository root:

~~~stata
do "stata/00_master.do"
~~~

The Stata workflow writes staged `.dta` files to `data/processed/` and equivalent audit outputs to `outputs/`.

## Quality philosophy

An automated check is evidence, not a substitute for judgment. Each exclusion is tied to a documented rule, source record counts are preserved, and ambiguous records are surfaced rather than silently repaired. Schema recovery is intentionally narrow: only transformations that are deterministic under an explicit contract are automated. In a production project, thresholds, schemas, accepted code sets, and disposition rules would be approved with the data owner and subject-matter team before delivery.

See [`docs/quality-rules.md`](docs/quality-rules.md) for row-level rules, schema-drift safeguards, and recovery boundaries.

## Skills demonstrated

Advanced Stata data management · R · multisource joins · schema-contract validation · data-quality engineering · reshaping and aggregation · identifier standardization · duplicate resolution · temporal validation · feature engineering · audit trails · reproducible pipelines · regression testing · GitHub Actions

## License

MIT
