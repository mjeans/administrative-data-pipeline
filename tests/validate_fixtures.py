"""Validate the committed synthetic fixtures before analytic code runs."""

from __future__ import annotations

import csv
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"

EXPECTED_HEADERS = {
    "enrollment.csv": [
        "raw_id",
        "site_code",
        "enroll_date",
        "dob",
        "gender",
        "language",
        "baseline_score",
    ],
    "service_events.csv": [
        "event_id",
        "participant_id",
        "service_date",
        "minutes",
        "mode",
    ],
    "outcomes.csv": [
        "assessment_id",
        "participant_id",
        "assessment_date",
        "outcome_score",
        "assessment_type",
    ],
    "site_crosswalk.csv": [
        "site_code",
        "site_id",
        "region",
        "urbanicity",
    ],
}


def read_rows(name: str) -> list[dict[str, str]]:
    with (RAW / name).open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != EXPECTED_HEADERS[name]:
            raise ValueError(
                f"{name}: expected {EXPECTED_HEADERS[name]!r}; "
                f"received {reader.fieldnames!r}"
            )
        return list(reader)


def normalized(value: str) -> str:
    return value.strip().upper()


def main() -> None:
    files = set(EXPECTED_HEADERS)
    actual = {path.name for path in RAW.glob("*.csv")}
    if actual != files:
        raise ValueError(f"Unexpected fixture set: {sorted(actual)!r}")

    enrollment = read_rows("enrollment.csv")
    services = read_rows("service_events.csv")
    outcomes = read_rows("outcomes.csv")
    sites = read_rows("site_crosswalk.csv")

    site_codes = [normalized(row["site_code"]) for row in sites]
    if len(site_codes) != len(set(site_codes)):
        raise ValueError("Site crosswalk contains duplicate source codes.")

    participant_ids = [
        normalized(row["raw_id"])
        for row in enrollment
        if normalized(row["raw_id"])
    ]
    participant_counts = Counter(participant_ids)
    if participant_counts["P003"] != 2:
        raise ValueError("Expected duplicate enrollment fixture is missing.")

    event_counts = Counter(
        normalized(row["event_id"]) for row in services
    )
    if event_counts["E003"] != 2:
        raise ValueError("Expected duplicate service fixture is missing.")

    assessment_counts = Counter(
        normalized(row["assessment_id"]) for row in outcomes
    )
    if assessment_counts["A013"] != 2:
        raise ValueError("Expected duplicate outcome fixture is missing.")

    if not any(not normalized(row["raw_id"]) for row in enrollment):
        raise ValueError("Expected blank participant ID fixture is missing.")

    print(
        "Validated four fixture schemas and all intentional test conditions."
    )


if __name__ == "__main__":
    main()
