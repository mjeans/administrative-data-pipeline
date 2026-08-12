version 18

* Collapse valid service events to participant-level features.
use "$staged/service_events_clean.dta", clear
generate byte virtual_event = service_mode == "Virtual"

collapse ///
    (count) service_event_count=service_minutes ///
    (sum) total_service_minutes=service_minutes ///
    (min) first_service_date=service_date ///
    (max) last_service_date=service_date ///
    (max) any_virtual_service=virtual_event, ///
    by(participant_id)

format first_service_date last_service_date %td
save "$staged/service_summary.dta", replace

* Rename follow-up fields before joining.
use "$staged/outcomes_latest.dta", clear
rename assessment_date followup_date
rename outcome_score followup_score
keep participant_id followup_date followup_score
save "$staged/outcomes_latest_renamed.dta", replace

* Construct one row per eligible participant.
use "$staged/enrollment_clean.dta", clear

merge 1:1 participant_id using "$staged/service_summary.dta", nogen
replace service_event_count = 0 if missing(service_event_count)
replace total_service_minutes = 0 if missing(total_service_minutes)
replace any_virtual_service = 0 if missing(any_virtual_service)
generate byte any_valid_service = service_event_count > 0

merge 1:1 participant_id using ///
    "$staged/outcomes_latest_renamed.dta", nogen

generate double score_change = followup_score - baseline_score
format enrollment_date first_service_date last_service_date followup_date %td

isid participant_id
assert total_service_minutes >= 0
assert inrange(baseline_score, 0, 100)

sort site_id participant_id
order participant_id site_id region urbanicity enrollment_date ///
    age_at_enrollment gender language baseline_score ///
    any_valid_service service_event_count total_service_minutes ///
    first_service_date last_service_date any_virtual_service ///
    followup_date followup_score score_change

save "$staged/analytic_cohort.dta", replace
export delimited using "$outputs/analytic_cohort.csv", replace

* Compact participant-level QA output for reconciliation.
preserve
    generate byte eligible_participant = 1
    generate byte has_followup = !missing(followup_score)
    collapse ///
        (sum) eligible_participants=eligible_participant ///
        (sum) participants_with_service=any_valid_service ///
        (sum) participants_with_followup=has_followup ///
        (mean) mean_baseline=baseline_score ///
        (mean) mean_followup=followup_score ///
        (mean) mean_score_change=score_change
    export delimited using "$outputs/qa_summary.csv", replace
restore
