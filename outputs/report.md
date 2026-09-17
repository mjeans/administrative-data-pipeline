# Executed administrative-data audit

The four committed extracts are intentionally messy and entirely synthetic. The validated R entry point checks source contracts before constructing the analytic cohort. This example does not certify a real organization's data.

## Before and after

| metric | value |
| --- | --- |
| raw_enrollment_rows | 15 |
| eligible_participants |  9 |
| raw_service_rows | 19 |
| valid_service_events | 11 |
| raw_outcome_rows | 14 |
| participants_with_valid_followup |  8 |

## Rule-level disposition

| source | rule_id | description | n_records |
| --- | --- | --- | --- |
| enrollment | ENR-01 | Blank participant identifier | 1 |
| enrollment | ENR-02 | Duplicate participant record removed | 1 |
| enrollment | ENR-03 | Site code did not resolve | 2 |
| enrollment | ENR-04 | Invalid baseline score | 1 |
| enrollment | ENR-05 | Unparseable required date | 1 |
| service_events | SVC-01 | Duplicate event removed | 1 |
| service_events | SVC-02 | Invalid service duration | 2 |
| service_events | SVC-03 | Participant not in eligible cohort | 4 |
| service_events | SVC-04 | Service preceded enrollment | 1 |
| outcomes | OUT-01 | Duplicate assessment removed | 1 |
| outcomes | OUT-02 | Invalid outcome score | 1 |
| outcomes | OUT-03 | Participant not in eligible cohort | 2 |
| outcomes | OUT-04 | Assessment preceded enrollment | 1 |
| outcomes | OUT-05 | Earlier valid follow-up superseded | 1 |

Rule counts refer to different source tables and stages; do not add them to infer unique excluded people.

## Concrete changes

- Duplicate and incomplete enrollment representations are reconciled by the documented ordering rules.
- The synthetic P001 retains the latest valid score (66) and two valid services totaling 105 minutes.
- P007's pre-enrollment service and assessment do not contribute: zero valid services and no valid follow-up score.
- Nine unique eligible participants remain; these conditions are independently asserted in tests.

## Schema recovery

| source | recovered_participant_ids |
| --- | --- |
| enrollment | 0 |
| service_events | 0 |
| outcomes | 0 |

Only identifier representations explicitly accepted by the contract are normalized. Renamed required columns, duplicate crosswalk keys, incompatible IDs, and unknown service categories stop the validated R path.

## Coverage and reproduction

[R/Stata coverage matrix](../docs/implementation-coverage.md). Run `Rscript scripts/restore_environment.R`, then `Rscript scripts/publish_audit.R`. Run both R test suites and `python tests/validate_fixtures.py`.

Only aggregate QA outputs are added to the report. The generated analytic cohort remains ignored.

[Reference R session](session-info.txt)
