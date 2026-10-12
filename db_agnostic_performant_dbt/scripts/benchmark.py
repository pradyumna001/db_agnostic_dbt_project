"""Summarise dbt run_results.json files as a Markdown table, one column per platform.

    python scripts/benchmark.py --run-results target/postgres/run_results.json --label postgres \
                                --run-results target/oracle/run_results.json --label oracle
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def load(path: str) -> dict[str, float]:
    data = json.loads(Path(path).read_text())
    return {
        r["unique_id"].split(".")[-1]: r["execution_time"]
        for r in data["results"]
        if r["unique_id"].startswith("model.")
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run-results", action="append", required=True)
    ap.add_argument("--label", action="append", required=True)
    args = ap.parse_args()
    if len(args.run_results) != len(args.label):
        raise SystemExit("--run-results and --label must be given the same number of times")
    runs = {label: load(p) for label, p in zip(args.label, args.run_results, strict=True)}
    models = sorted({m for r in runs.values() for m in r})
    labels = list(runs)
    print("| model | " + " | ".join(f"{label} (s)" for label in labels) + " |")
    print("|---|" + "---:|" * len(labels))
    for m in models:
        print(f"| {m} | " + " | ".join(f"{runs[label].get(m, float('nan')):.2f}" for label in labels) + " |")
    print("| **total** | " + " | ".join(f"**{sum(runs[label].values()):.2f}**" for label in labels) + " |")


if __name__ == "__main__":
    main()
