"""Independent, fixture-specific check. Does not execute or emulate Stata."""
import argparse
import csv
import re
import shlex
from collections import Counter, defaultdict
from datetime import date, timedelta
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = HERE / "stata_data_management_sample.do"
FIRST, LAST = date(2025, 1, 1), date(2025, 3, 31)


def input_rows(text, first_field):
    """Read a named literal Stata input block, including continued headers."""
    lines = iter(text.splitlines())
    for line in lines:
        if line.startswith("input ") and first_field in line.split():
            while line.rstrip().endswith("///"):
                line = next(lines)
            return [shlex.split(s) for s in iter(lambda: next(lines), "end")]
    raise ValueError(f"Missing input block: {first_field}")


def pid(raw):
    return raw.strip().upper().replace("-", "").replace(" ", "")


def reference(text):
    # With this tiny fixture it is easy to enumerate distinct eligible dates.
    # This deliberately does not reuse the do-file's running-maximum algorithm.
    days = defaultdict(set)
    for _, raw, site, start, end in input_rows(text, "spell_id"):
        person = pid(raw)
        try:
            lo = max(FIRST, date.fromisoformat(start))
            hi = min(LAST, date.fromisoformat(end) if end else LAST)
        except ValueError:
            continue
        if re.fullmatch(r"P\d{3}", person) and site in {"North", "South"}:
            for offset in range((hi - lo).days + 1):
                days[person, site].add(lo + timedelta(days=offset))

    counts = Counter((p, s, d.strftime("%Y-%m")) for (p, s), ds in days.items() for d in ds)
    feeds = {(s, m): int(v) for s, m, v in input_rows(text, "feed_complete")}
    versions = defaultdict(list)
    for event, raw, site, day, updated, status, minutes in input_rows(text, "event_id"):
        versions[event].append((updated, pid(raw), site, date.fromisoformat(day),
                                status, None if minutes in {"", "unknown"} else int(minutes)))
    visits, known_minutes, missing_minutes = Counter(), Counter(), set()
    conflicts = set()
    for history in versions.values():
        latest = max(row[0] for row in history)
        variants = {row[1:] for row in history if row[0] == latest}
        for person, site, d, status, duration in variants:
            key = person, site, d.strftime("%Y-%m")
            if d not in days.get((person, site), set()):
                continue
            if len(variants) > 1:
                conflicts.add(key)
            elif status == "attended":
                visits[key] += 1
                if duration is None:
                    missing_minutes.add(key)
                else:
                    known_minutes[key] += duration

    panel = {}
    for key, n_days in counts.items():
        _, site, month = key
        feed = feeds.get((site, month))
        status = ("version_conflict" if key in conflicts else "feed_missing" if feed is None
                  else "feed_partial" if not feed else "duration_missing" if key in missing_minutes
                  else "complete")
        usable = status in {"complete", "duration_missing"}
        panel[key] = (n_days, visits[key], known_minutes[key], status,
                      visits[key] if usable else None, known_minutes[key] if status == "complete" else None)
    return panel


# Hand-calculated expectations for this example, not claimed Stata output.
# (days enrolled, observed visits, known minutes, status, reported visits, reported minutes)
EXPECTED = {
    ("P001","North","2025-01"): (31,1,45,"complete",1,45),
    ("P001","North","2025-02"): (28,2,20,"duration_missing",2,None),
    ("P001","North","2025-03"): (31,0,0,"complete",0,0),
    ("P002","North","2025-01"): (12,1,25,"complete",1,25),
    ("P002","North","2025-02"): (3,1,35,"complete",1,35),
    ("P002","North","2025-03"): (31,0,0,"complete",0,0),
    ("P003","South","2025-02"): (28,1,30,"feed_partial",None,None),
    ("P003","South","2025-03"): (15,1,0,"feed_missing",None,None),
    ("P004","South","2025-01"): (31,1,20,"version_conflict",None,None),
    ("P004","South","2025-02"): (20,0,0,"feed_partial",None,None),
    ("P005","North","2025-03"): (1,1,15,"complete",1,15),
}


def read_native(path):
    """Read the do-file's exported CSV; data_status retains missingness reasons."""
    panel = {}
    def number(s):
        return None if s.strip() in {"", ".", ".u", ".m", ".c"} else float(s)
    with path.open(encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            y, m = re.fullmatch(r"(\d{4})m(\d{1,2})", row["month"].strip()).groups()
            key = row["participant_id"], row["site"], f"{y}-{int(m):02d}"
            if key in panel:
                raise ValueError(f"Duplicate exported key {key}")
            panel[key] = (number(row["days_enrolled"]), number(row["observed_visits"]),
                          number(row["observed_minutes"]), row["data_status"],
                          number(row["visits"]), number(row["total_minutes"]))
    return panel


def verify(actual):
    for key in sorted(set(EXPECTED) | set(actual)):
        if actual.get(key) != EXPECTED.get(key):
            raise ValueError(f"{key}: expected {EXPECTED.get(key)}, got {actual.get(key)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stata-csv", type=Path, help="also compare an actual native export")
    args = parser.parse_args()
    verify(reference(SOURCE.read_text(encoding="utf-8-sig")))
    print("Independent fixture check passed: 11 participant-site-months. This is not a Stata run.")
    if args.stata_csv:
        verify(read_native(args.stata_csv))
        print("Supplied CSV matches all 11 expected rows and the six checked fields.")
