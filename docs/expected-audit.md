# Expected audit of the synthetic fixtures

The raw fixtures intentionally contain the following conditions:

- one blank enrollment identifier
- one duplicate participant with a more complete replacement row
- two enrollment records without a valid site mapping
- one out-of-range baseline score
- one enrollment record with an unparseable required date
- one duplicate service event
- two implausible service durations
- service events associated with ineligible or unknown participants
- one service before enrollment
- one out-of-range outcome
- one outcome before enrollment
- one duplicate outcome record
- two follow-ups for one participant, with the latest retained

A successful run should produce an eligible cohort containing P001, P002, P003, P007, P008, P009, P010, P011, and P012. P001's June assessment should be retained as the latest valid outcome, and P007's pre-enrollment service and assessment should not contribute to participant features.

The automated tests assert those high-value conditions rather than merely checking whether files were created.
