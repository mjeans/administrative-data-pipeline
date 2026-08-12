version 18

import delimited using "$raw/outcomes.csv", ///
    clear varnames(1) stringcols(_all)

generate long source_row = _n
rename assessment_date assessment_date_raw
rename outcome_score outcome_score_raw

foreach variable in assessment_id participant_id {
    replace `variable' = ustrupper(ustrtrim(`variable'))
}
replace assessment_type = strproper(ustrtrim(assessment_type))
replace assessment_type = subinstr(assessment_type, "-", " ", .)

generate double assessment_date = daily(assessment_date_raw, "YMD")
replace assessment_date = daily(assessment_date_raw, "MDY") ///
    if missing(assessment_date)
format assessment_date %td

generate double outcome_score = real(outcome_score_raw)

sort assessment_id source_row
by assessment_id: generate byte duplicate_disposition = ///
    _n > 1 & !missing(assessment_id)

preserve
    keep if duplicate_disposition
    generate str7 exclusion_rule = "OUT-01"
    export delimited using "$outputs/outcome_duplicates.csv", replace
restore

drop if duplicate_disposition

merge m:1 participant_id using "$staged/enrollment_clean.dta", ///
    keepusing(enrollment_date)

generate str7 exclusion_rule = ""
replace exclusion_rule = "OUT-02" ///
    if missing(outcome_score) | !inrange(outcome_score, 0, 100)
replace exclusion_rule = "OUT-03" ///
    if exclusion_rule == "" & _merge != 3
replace exclusion_rule = "OUT-04" ///
    if exclusion_rule == "" & assessment_date < enrollment_date

preserve
    keep if exclusion_rule != ""
    export delimited using "$outputs/outcome_exclusions.csv", replace
restore

keep if exclusion_rule == ""
drop _merge exclusion_rule duplicate_disposition
drop assessment_date_raw outcome_score_raw enrollment_date

gsort participant_id -assessment_date source_row
by participant_id: generate byte superseded = _n > 1

preserve
    keep if superseded
    generate str7 exclusion_rule = "OUT-05"
    export delimited using "$outputs/superseded_outcomes.csv", replace
restore

keep if !superseded
drop superseded

isid participant_id
compress
save "$staged/outcomes_latest.dta", replace
