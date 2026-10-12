"""Print row counts of every vault/gold relation as JSON (used for idempotency checks in CI)."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "data_generator"))
from load import connect  # noqa: E402

MANIFEST = Path(__file__).resolve().parents[1] / "target" / "manifest.json"


def relations(target: str) -> list[str]:
    nodes = json.loads(MANIFEST.read_text())["nodes"].values()
    out = []
    for n in nodes:
        if n["resource_type"] != "model" or n["config"]["materialized"] not in ("table", "incremental"):
            continue
        out.append(n["alias"] if target == "oracle" else f"{n['schema']}.{n['alias']}")
    return sorted(out)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", default=os.getenv("DBT_TARGET", "postgres"))
    args = ap.parse_args()
    conn = connect(args.target)
    cur = conn.cursor()
    counts = {}
    for rel in relations(args.target):
        cur.execute(f"select count(*) from {rel}")
        counts[rel] = cur.fetchone()[0]
    print(json.dumps(counts, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
