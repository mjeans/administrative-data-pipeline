/*

This self-contained example uses invented records. The question is how much
service each participant received while enrolled, allowing for overlapping
enrollment spells and corrected records.

*/

clear all
set more off

local out "sample_output"
local first = daily("2025-01-01", "YMD")
local last  = daily("2025-03-31", "YMD")
capture mkdir "`out'"
capture log close participation
log using "`out'/participation.log", text replace name(participation)

tempfile episodes versions matched_rows monthly_services reporting

* Keep IDs as strings. Only spaces, hyphens, and case are harmless here.
capture program drop clean_pid
program define clean_pid
    version 16.0
    syntax varname(string), Generate(name)
    tempvar cleaned
    quietly {
        gen strL `cleaned' = upper(strtrim(`varlist'))
        replace `cleaned' = subinstr(`cleaned', " ", "", .)
        replace `cleaned' = subinstr(`cleaned', "-", "", .)
        gen str4 `generate' = `cleaned' ///
            if regexm(`cleaned', "^P[0-9][0-9][0-9]$")
    }
end

* Small source extracts include the cases that tend to cause trouble.
input str3 spell_id str8 raw_id str5 site str10 start_raw str10 end_raw
"s01" "P-001"   "North" "2024-12-20" "2025-02-10"
"s02" "p001"    "North" "2025-01-10" "2025-01-15"
"s03" "P 001"   "North" "2025-01-20" "2025-03-31"
"s04" "P-002"   "North" "2025-01-20" "2025-02-03"
"s05" "P-002"   "North" "2025-03-01" ""
"s06" "P003"    "South" "2025-02-01" "2025-03-15"
"s07" "P004"    "South" "2025-01-01" "2025-01-31"
"s08" "P004"    "South" "2025-02-01" "2025-02-20"
"s09" "P005"    "North" "2025-03-31" ""
"s10" "P006"    "North" "2025-02-10" "2025-02-01"
"s11" "unknown" "North" "2025-01-01" "2025-03-31"
"s12" "P007"    "South" "2025-02-01" "2025-02-30"
"s13" "P008"    "South" "2024-10-01" "2024-11-30"
end

isid spell_id
clean_pid raw_id, generate(participant_id)
gen int start_date = daily(start_raw, "YMD")
gen int end_date = daily(end_raw, "YMD")
format start_date end_date %td

gen str40 issue = ""
replace issue = "unrecognized participant ID" if participant_id == ""
replace issue = "unrecognized site" if issue == "" & !inlist(site, "North", "South")
replace issue = "invalid start date" if issue == "" & missing(start_date)
replace issue = "invalid end date" ///
    if issue == "" & end_raw != "" & missing(end_date)
replace issue = "end precedes start" ///
    if issue == "" & end_date < start_date

* A blank end means still enrolled. A failed date conversion does not.
replace end_date = `last' if end_raw == "" & issue == ""
gen str20 disposition = "included"
replace disposition = "outside_window" if end_date < `first' | start_date > `last'
replace disposition = "review" if issue != ""
sort spell_id
export delimited using "`out'/enrollment_audit.csv", replace datafmt
keep if disposition == "included"
replace start_date = max(start_date, `first')
replace end_date = min(end_date, `last')
assert !missing(start_date, end_date) & start_date <= end_date

* Union overlapping or adjacent spells before counting days. Comparing only
* with the previous end date fails when one spell is nested inside another.
* Running-maximum idiom: stata.com/support/faqs/data-management/maximum-and-minimum-of-sequence/
bysort participant_id site (start_date end_date spell_id): gen int furthest_end = end_date
by participant_id site: replace furthest_end = max(furthest_end[_n-1], end_date) if _n > 1
by participant_id site: gen byte new_episode = _n == 1 | start_date > furthest_end[_n-1] + 1
by participant_id site: gen int episode = sum(new_episode)
gen byte source_spells = 1

preserve
keep spell_id participant_id site episode start_date end_date
sort participant_id site episode spell_id
export delimited using "`out'/enrollment_crosswalk.csv", replace datafmt
restore

collapse (min) start_date (max) end_date (sum) source_spells, ///
    by(participant_id site episode)
bysort participant_id site (start_date): ///
    assert start_date > end_date[_n-1] + 1 if _n > 1
isid participant_id site episode
save `episodes'

* Repeated event IDs are revisions, not necessarily duplicate visits.
clear
input str3 event_id str8 raw_id str5 site str10 date_raw ///
    str19 updated_raw str9 status str7 minutes_raw
"E01" "P-001" "North" "2025-01-05" "2025-01-06 09:00:00" "attended"  "30"
"E01" "p001"  "North" "2025-01-05" "2025-01-07 10:00:00" "attended"  "45"
"E02" "P001"  "North" "2025-02-14" "2025-02-15 09:00:00" "attended"  "20"
"E02" "P001"  "North" "2025-02-14" "2025-02-15 09:00:00" "attended"  "20"
"E03" "P001"  "North" "2025-01-18" "2025-01-18 14:00:00" "attended"  "30"
"E03" "P001"  "North" "2025-01-18" "2025-01-19 10:00:00" "cancelled" ""
"E04" "P002"  "North" "2025-01-19" "2025-01-20 09:00:00" "attended"  "20"
"E05" "P002"  "North" "2025-01-20" "2025-01-21 09:00:00" "attended"  "25"
"E06" "P002"  "North" "2025-02-03" "2025-02-04 09:00:00" "attended"  "35"
"E07" "P002"  "North" "2025-02-04" "2025-02-05 09:00:00" "attended"  "45"
"E08" "P003"  "South" "2025-02-10" "2025-02-11 09:00:00" "attended"  "30"
"E09" "P003"  "South" "2025-03-15" "2025-03-16 09:00:00" "attended"  "unknown"
"E10" "P004"  "South" "2025-01-12" "2025-01-13 09:00:00" "attended"  "20"
"E11" "P004"  "South" "2025-01-15" "2025-01-16 09:00:00" "attended"  "40"
"E11" "P004"  "South" "2025-01-15" "2025-01-16 09:00:00" "attended"  "50"
"E12" "P005"  "North" "2025-03-31" "2025-04-01 09:00:00" "attended"  "15"
"E13" "P999"  "North" "2025-03-01" "2025-03-02 09:00:00" "attended"  "30"
"E15" "P001"  "North" "2025-02-20" "2025-02-21 09:00:00" "attended"  "unknown"
end

gen long source_row = _n
clean_pid raw_id, generate(participant_id)
gen int service_date = daily(date_raw, "YMD")
gen double updated_at = clock(updated_raw, "YMDhms")
gen double minutes = real(minutes_raw)
format service_date %td
format updated_at %tc

* Stop on errors that prevent placing a record in a person-month. Dropping
* those records and continuing could turn an unknown count into a false zero.
assert !missing(event_id, participant_id, site)
assert !missing(service_date, updated_at)
assert inlist(site, "North", "South")
assert inlist(status, "attended", "cancelled")
* Contacts can last up to four hours; a missing duration is still a visit.
assert inrange(minutes, 0, 240) | inlist(minutes_raw, "", "unknown")

bysort event_id: egen double last_update = max(updated_at)
gen byte is_latest = updated_at == last_update
bysort event_id updated_at participant_id site service_date status minutes (source_row): ///
    gen byte extra_copy = _n > 1
bysort event_id: egen int latest_variants = total(is_latest & !extra_copy)

gen str24 disposition = "superseded"
replace disposition = "duplicate_copy" if extra_copy
replace disposition = "version_conflict" if is_latest & latest_variants > 1
replace disposition = "cancelled" ///
    if is_latest & latest_variants == 1 & !extra_copy & status == "cancelled"
replace disposition = "keep" ///
    if is_latest & latest_variants == 1 & !extra_copy & status == "attended"
save `versions'

* Resolve revisions before excluding cancellations. Otherwise E03 comes back
* as an attended visit. Equally recent, conflicting versions remain unresolved.
keep if inlist(disposition, "keep", "version_conflict")
preserve
keep if disposition == "keep"
isid event_id
restore

* Interval join: each candidate is compared only with that person's spells
* at that site. For a large archive, partition by site/year before this join.
joinby participant_id site using `episodes', unmatched(master)
gen byte eligible = _merge == 3 & inrange(service_date, start_date, end_date)
bysort source_row: egen byte n_matches = total(eligible)
assert n_matches <= 1
bysort source_row (eligible episode): keep if _n == _N
isid source_row

preserve
keep source_row eligible
save `matched_rows'
restore

keep if eligible
gen int month = mofd(service_date)
gen byte observed_visits = disposition == "keep"
gen byte unresolved_events = disposition == "version_conflict"
gen byte missing_duration = observed_visits & missing(minutes)
gen double observed_minutes = cond(observed_visits & !missing(minutes), minutes, 0)
collapse (sum) observed_visits observed_minutes missing_duration ///
    (max) unresolved_events, by(participant_id site month)
isid participant_id site month
save `monthly_services'

* Keep every source row in the audit, including revisions and rejected events.
use `versions', clear
merge 1:1 source_row using `matched_rows', assert(master match) nogen
replace disposition = "outside_enrollment" if disposition == "keep" & eligible == 0
replace disposition = "accepted" if disposition == "keep" & eligible == 1
assert disposition != "keep"
keep source_row event_id raw_id participant_id site date_raw updated_raw ///
    status minutes_raw service_date updated_at minutes disposition eligible
sort source_row
export delimited using "`out'/service_audit.csv", replace datafmt

* Feed status comes from a separate delivery manifest, never from the presence
* of service rows. South's February feed is partial; March has no manifest row.
clear
input str5 site str7 month_raw byte feed_complete
"North" "2025-01" 1
"North" "2025-02" 1
"North" "2025-03" 1
"South" "2025-01" 1
"South" "2025-02" 0
end
gen int month = monthly(month_raw, "YM")
assert !missing(month) & inlist(feed_complete, 0, 1)
isid site month
keep site month feed_complete
save `reporting'

* Build the denominator from enrollment, not attendance. Expand by month
* rather than day, then intersect each episode with the month's boundaries.
use `episodes', clear
gen int n_months = mofd(end_date) - mofd(start_date) + 1
assert inrange(n_months, 1, mofd(`last') - mofd(`first') + 1)
expand n_months
bysort participant_id site episode: gen int month = mofd(start_date) + _n - 1
gen int days_enrolled = min(end_date, dofm(month + 1) - 1) ///
    - max(start_date, dofm(month)) + 1
assert days_enrolled > 0
collapse (sum) days_enrolled, by(participant_id site month)
assert days_enrolled <= dofm(month + 1) - dofm(month)
isid participant_id site month

merge 1:1 participant_id site month using `monthly_services', assert(master match) nogen
foreach v in observed_visits observed_minutes missing_duration unresolved_events {
    replace `v' = 0 if missing(`v')
}
merge m:1 site month using `reporting', keep(master match) nogen

* Observed counts are lower bounds when delivery or revision problems remain.
* Only a complete feed with no unresolved events can support a true zero.
gen byte ascertainable = feed_complete == 1 & unresolved_events == 0
gen double visits = observed_visits if ascertainable
gen double total_minutes = observed_minutes if ascertainable & missing_duration == 0
replace total_minutes = .m if ascertainable & missing_duration > 0
foreach v in visits total_minutes {
    replace `v' = .u if feed_complete != 1
    replace `v' = .c if unresolved_events
}
label define unavailable .u "Feed incomplete or absent" ///
    .c "Conflicting event versions" .m "Duration not recorded"
label values visits total_minutes unavailable

gen str20 data_status = "complete"
replace data_status = "duration_missing" if ascertainable & missing_duration > 0
replace data_status = "feed_partial" if feed_complete == 0
replace data_status = "feed_missing" if missing(feed_complete)
replace data_status = "version_conflict" if unresolved_events
gen byte any_visit = visits > 0 if !missing(visits)
gen double visits_per_30_days = 30 * visits / days_enrolled if !missing(visits)

* The unit is participant-site-month. Time gaps remain gaps; no rows are
* invented for months when a participant was not enrolled at that site.
egen long panel_id = group(participant_id site)
format month %tm
format visits_per_30_days %9.2f
xtset panel_id month
label var days_enrolled "Distinct enrolled calendar days, inclusive of endpoints"
label var observed_visits "Accepted visits present in the extract"
label var observed_minutes "Recorded minutes among accepted visits"
label var missing_duration "Accepted visits with no recorded duration"
label var unresolved_events "At least one unresolved event overlaps enrollment"
label var visits "Monthly visits, requiring a complete and unambiguous feed"
label var total_minutes "Monthly minutes, also requiring all visit durations"
label var visits_per_30_days "Visits per 30 enrolled calendar days"

* Checks tied to the deliberately awkward records above.
assert _N == 11
assert days_enrolled == 31 & visits == 1 & total_minutes == 45 ///
    if participant_id == "P001" & month == ym(2025, 1)
assert visits == 2 & total_minutes == .m ///
    if participant_id == "P001" & month == ym(2025, 2)
assert visits == 0 & total_minutes == 0 ///
    if participant_id == "P001" & month == ym(2025, 3)
assert days_enrolled == 3 & visits == 1 ///
    if participant_id == "P002" & month == ym(2025, 2)
assert visits == .c & observed_visits == 1 ///
    if participant_id == "P004" & month == ym(2025, 1)
assert visits == .u & observed_visits == 0 ///
    if participant_id == "P004" & month == ym(2025, 2)
assert missing(feed_complete) & visits == .u ///
    if participant_id == "P003" & month == ym(2025, 3)
assert days_enrolled == 1 & visits == 1 ///
    if participant_id == "P005" & month == ym(2025, 3)

order participant_id site month days_enrolled visits total_minutes ///
    visits_per_30_days any_visit data_status observed_visits observed_minutes ///
    missing_duration unresolved_events feed_complete
drop ascertainable
sort participant_id site month
compress
save "`out'/participant_month.dta", replace
export delimited using "`out'/participant_month.csv", replace nolabel datafmt
list participant_id site month days_enrolled visits total_minutes data_status, ///
    sepby(participant_id) noobs abbreviate(20)
log close participation
