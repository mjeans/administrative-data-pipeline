version 18
clear all
set more off
set varabbrev off

* Run this file from the repository root.
global raw "data/raw"
global staged "data/processed"
global outputs "outputs"

capture mkdir "$staged"
capture mkdir "$outputs"

capture log close _all
log using "$outputs/pipeline.log", replace text

display as text "Administrative data pipeline started: " c(current_date) " " c(current_time)

do "stata/01_clean_enrollment.do"
do "stata/02_clean_services.do"
do "stata/03_clean_outcomes.do"
do "stata/04_build_analytic_file.do"

display as result "Administrative data pipeline completed successfully."
log close
