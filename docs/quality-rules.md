# Quality and disposition rules

## Record-level rules

| Rule ID | Source | Condition | Disposition |
|---|---|---|---|
| ENR-01 | Enrollment | Participant ID is blank | Exclude |
| ENR-02 | Enrollment | Duplicate participant ID | Retain the most complete record, then earliest enrollment |
| ENR-03 | Enrollment | Site code does not resolve to crosswalk | Exclude |
| ENR-04 | Enrollment | Baseline score is missing, nonnumeric, or outside 0–100 | Exclude |
| ENR-05 | Enrollment | Enrollment date or date of birth cannot be parsed | Exclude |
| SVC-01 | Services | Duplicate event ID | Retain one record |
| SVC-02 | Services | Duration outside 1–480 minutes | Exclude event |
| SVC-03 | Services | Participant is not in the eligible cohort | Exclude event and count as orphaned |
| SVC-04 | Services | Service date precedes enrollment | Exclude event |
| OUT-01 | Outcomes | Duplicate assessment ID | Retain one record |
| OUT-02 | Outcomes | Score is missing, nonnumeric, or outside 0–100 | Exclude assessment |
| OUT-03 | Outcomes | Participant is not in the eligible cohort | Exclude assessment |
| OUT-04 | Outcomes | Assessment precedes enrollment | Exclude assessment |
| OUT-05 | Outcomes | Multiple valid follow-ups | Retain latest assessment |

Rules are applied in a documented order because one record can violate more than one condition. Counts represent the stage at which a record is dispositioned, preventing double-counting in the aggregate audit.

## Schema-contract safeguards

Schema checks run before the R analytic pipeline. They distinguish recoverable representation differences from changes that require an explicit data-contract decision.

| Rule ID | Source | Condition | Disposition |
|---|---|---|---|
| SCH-01 | Any required input | Source file or required column is missing/renamed | Hard fail with source-specific diagnostic |
| SCH-02 | Site crosswalk | Required site key is blank or duplicated | Hard fail before any join can multiply records |
| SCH-03 | Enrollment, services, outcomes | Participant ID does not match the explicit `P###` contract or a safe numeric/under-padded equivalent | Hard fail for incompatible formats; safely canonicalize numeric/under-padded equivalents |
| SCH-04 | Service events | Service mode is outside `In person`, `Virtual`, or `Phone` after documented spelling normalization | Hard fail and require an explicit mapping decision |

### Recovery boundaries

The validated R entry point may normalize participant identifiers only when the transformation is deterministic under the documented contract: `1`, `001`, `P1`, and `P001` all refer to `P001`. Case and surrounding whitespace are also normalized. The number of numeric/under-padded participant IDs recovered in each source is returned in the validation metadata.

The validator does **not** guess renamed columns, auto-map unknown categorical values, or accept duplicate crosswalk keys. Those conditions stop the pipeline before the final analytic file is built.
