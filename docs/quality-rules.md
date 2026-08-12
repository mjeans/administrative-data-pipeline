# Quality and disposition rules

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
