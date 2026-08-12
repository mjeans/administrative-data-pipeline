# Data dictionary

## Enrollment

| Field | Type after cleaning | Definition |
|---|---|---|
| participant_id | character | Uppercase participant identifier with whitespace removed |
| site_code | character | Standardized source-system site code |
| enrollment_date | date | Program enrollment date |
| date_of_birth | date | Date of birth used to derive age at enrollment |
| gender | character | Standardized self-reported category |
| language | character | Standardized preferred-language category |
| baseline_score | numeric | Baseline measure constrained to 0–100 |

## Service events

| Field | Type after cleaning | Definition |
|---|---|---|
| event_id | character | Unique service-event identifier |
| participant_id | character | Standardized participant identifier |
| service_date | date | Date the service occurred |
| service_minutes | numeric | Valid duration from 1 through 480 minutes |
| service_mode | character | Standardized delivery mode |

Derived participant measures include valid event count, total minutes, first and last service dates, and an indicator for any valid service.

## Outcomes

| Field | Type after cleaning | Definition |
|---|---|---|
| assessment_id | character | Unique assessment identifier |
| participant_id | character | Standardized participant identifier |
| assessment_date | date | Date the assessment occurred |
| outcome_score | numeric | Follow-up measure constrained to 0–100 |
| assessment_type | character | Standardized assessment label |

When multiple eligible assessments exist, the latest valid follow-up is retained. `score_change` is the latest outcome minus the baseline score.

## Site crosswalk

The crosswalk translates source `site_code` values to stable `site_id`, region, and urbanicity fields. Enrollment records without a resolved site are excluded rather than assigned speculatively.
