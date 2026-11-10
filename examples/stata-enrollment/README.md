# Which services count during enrollment?

[Open the Stata do-file](stata_data_management_sample.do) · [Independent fixture check](check_sample.py)

A service coordinator wants to know how many visits each participant received while enrolled. Counting rows overstates attendance when a visit has been revised. Counting only people with visits drops enrolled participants who had none. This self-contained sample uses invented records for January–March 2025 and produces one row per **participant, site, and enrolled month**.

### Three source records to follow

| Source case | Decision | Expected reporting result |
|---|---|---|
| P001: E01 was recorded as 30 minutes, then corrected to 45; three North enrollment spells overlap. | Use the latest event version and count each enrolled day once. The later cancellation on E03 supersedes the original attendance. | January: 31 days, **1 visit, 45 minutes**. |
| P002: a North spell ends February 3; one service occurs February 3 and another February 4. | Include the end date; exclude the next day's service. | February: **3 enrolled days, 1 visit, 35 minutes**. |
| P004: two equally recent E11 records disagree on duration. South’s February delivery is partial. | Flag the January conflict instead of choosing a record; in February, an empty extract is not evidence of zero visits. | January: **1 undisputed visit observed**, final count unknown. February: **0 observed**, final count still unknown. |

Contrast P004 with P001 in March: North submitted a complete feed, there are no unresolved events, and zero visits is a reportable result. A missing duration is a different problem again: P001 has **2** February visits but no reportable total minutes.

### How the file works

The do-file normalizes IDs, audits rejected enrollment spells, and unions overlapping or adjacent spells before matching services. It resolves event revisions before dropping cancellations and preserves conflicting latest versions for review. Enrollment supplies the denominator; a separate site-month delivery manifest determines when a count can be interpreted. The script writes source-to-output audit trails as well as the participant-month panel.

### Verification and reproduction

**Native Stata execution: pending.** The examples above are expected results, not a Stata execution log. CI uses Python to read the do-file's three literal input blocks, enumerate eligible calendar days, and independently reconstruct the 11 expected participant-site-months. It checks enrolled days, observed visits, known minutes, data status, reported visits, and reported minutes. This checks the fixture and its interpretation, not the Stata syntax or numerical equivalence of the main R and Stata pipelines.

From the repository root:

~~~bash
python examples/stata-enrollment/check_sample.py
~~~

To verify natively, use a **fresh licensed Stata session** with the repository root as its working directory. The do-file clears in-memory data and replaces its generated files in `sample_output/`; use a clean checkout if that directory already contains work you want to keep.

~~~stata
do "examples/stata-enrollment/stata_data_management_sample.do"
~~~

After the run completes without assertion errors, compare the actual export:

~~~bash
python examples/stata-enrollment/check_sample.py --stata-csv sample_output/participant_month.csv
~~~

The native assertions distinguish extended missing values for an incomplete/absent feed, a revision conflict, and unknown duration. The CSV comparison checks missing values alongside their explicit status. Keep the generated files local; record the Stata version and verification result only after a real run.
