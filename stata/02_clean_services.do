version 18

import delimited using "$raw/service_events.csv", ///
    clear varnames(1) stringcols(_all)

generate long source_row = _n
rename service_date service_date_raw
rename minutes service_minutes_raw
rename mode service_mode

foreach variable in event_id participant_id {
    replace `variable' = ustrupper(ustrtrim(`variable'))
}

replace service_mode = ustrlower(ustrtrim(service_mode))
replace service_mode = subinstr(service_mode, "-", " ", .)
replace service_mode = "In person" if service_mode == "in person"
replace service_mode = "Virtual" if service_mode == "virtual"
replace service_mode = "Phone" if service_mode == "phone"

generate double service_date = daily(service_date_raw, "YMD")
replace service_date = daily(service_date_raw, "MDY") ///
    if missing(service_date)
format service_date %td

generate double service_minutes = real(service_minutes_raw)

sort event_id source_row
by event_id: generate byte duplicate_disposition = ///
    _n > 1 & !missing(event_id)

preserve
    keep if duplicate_disposition
    generate str7 exclusion_rule = "SVC-01"
    export delimited using "$outputs/service_duplicates.csv", replace
restore

drop if duplicate_disposition

merge m:1 participant_id using "$staged/enrollment_clean.dta", ///
    keepusing(enrollment_date)

generate str7 exclusion_rule = ""
replace exclusion_rule = "SVC-02" ///
    if missing(service_minutes) | !inrange(service_minutes, 1, 480)
replace exclusion_rule = "SVC-03" ///
    if exclusion_rule == "" & _merge != 3
replace exclusion_rule = "SVC-04" ///
    if exclusion_rule == "" & service_date < enrollment_date

preserve
    keep if exclusion_rule != ""
    export delimited using "$outputs/service_exclusions.csv", replace
restore

keep if exclusion_rule == ""
drop _merge exclusion_rule duplicate_disposition
drop service_date_raw service_minutes_raw enrollment_date

assert inrange(service_minutes, 1, 480)
isid event_id

compress
save "$staged/service_events_clean.dta", replace
