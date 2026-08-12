version 18

* Prepare the site crosswalk.
import delimited using "$raw/site_crosswalk.csv", ///
    clear varnames(1) stringcols(_all)

foreach variable in site_code site_id {
    replace `variable' = ustrupper(ustrtrim(`variable'))
}
replace region = strproper(ustrtrim(region))
replace urbanicity = strproper(ustrtrim(urbanicity))

isid site_code
compress
save "$staged/site_crosswalk.dta", replace

* Clean enrollment records.
import delimited using "$raw/enrollment.csv", ///
    clear varnames(1) stringcols(_all)

generate long source_row = _n
rename raw_id participant_id
rename enroll_date enrollment_date_raw
rename dob date_of_birth_raw
rename baseline_score baseline_score_raw

replace participant_id = ustrupper(ustrtrim(participant_id))
replace site_code = ustrupper(ustrtrim(site_code))
replace gender = strproper(ustrtrim(gender))
replace language = strproper(ustrtrim(language))

replace gender = "Female" if inlist(ustrupper(gender), "F", "FEMALE")
replace gender = "Male" if inlist(ustrupper(gender), "M", "MALE")

generate double enrollment_date = daily(enrollment_date_raw, "YMD")
replace enrollment_date = daily(enrollment_date_raw, "MDY") ///
    if missing(enrollment_date)

generate double date_of_birth = daily(date_of_birth_raw, "YMD")
replace date_of_birth = daily(date_of_birth_raw, "MDY") ///
    if missing(date_of_birth)

format enrollment_date date_of_birth %td
generate double baseline_score = real(baseline_score_raw)

generate byte completeness = ///
    !missing(site_code) + ///
    !missing(enrollment_date) + ///
    !missing(date_of_birth) + ///
    !missing(baseline_score)

gsort participant_id -completeness enrollment_date source_row
by participant_id: generate byte duplicate_disposition = ///
    _n > 1 & !missing(participant_id)

preserve
    keep if duplicate_disposition
    generate str7 exclusion_rule = "ENR-02"
    export delimited using "$outputs/enrollment_duplicates.csv", replace
restore

drop if duplicate_disposition
merge m:1 site_code using "$staged/site_crosswalk.dta", ///
    keepusing(site_id region urbanicity)

generate str7 exclusion_rule = ""
replace exclusion_rule = "ENR-01" if missing(participant_id)
replace exclusion_rule = "ENR-03" ///
    if exclusion_rule == "" & (_merge != 3 | missing(site_id))
replace exclusion_rule = "ENR-04" ///
    if exclusion_rule == "" & ///
    (missing(baseline_score) | !inrange(baseline_score, 0, 100))
replace exclusion_rule = "ENR-05" ///
    if exclusion_rule == "" & ///
    (missing(enrollment_date) | missing(date_of_birth))

preserve
    keep if exclusion_rule != ""
    export delimited using "$outputs/enrollment_exclusions.csv", replace
restore

keep if exclusion_rule == ""
drop _merge exclusion_rule duplicate_disposition completeness
drop enrollment_date_raw date_of_birth_raw baseline_score_raw

generate int age_at_enrollment = ///
    floor((enrollment_date - date_of_birth) / 365.25)

assert !missing(participant_id, site_id, enrollment_date)
assert inrange(baseline_score, 0, 100)
isid participant_id

order participant_id site_id region urbanicity enrollment_date ///
    age_at_enrollment gender language baseline_score

compress
save "$staged/enrollment_clean.dta", replace
