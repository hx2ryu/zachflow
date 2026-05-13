#!/usr/bin/env python3
"""Append a record to a JSONL file with a SHA-256 hash chain.

Each appended line carries `prev_hash` and `hash` fields. `prev_hash`
points at the previous line's `hash` (or the sentinel "GENESIS" if the
file is empty). `hash` is `sha256(canonical_json(record))` where the
record includes `prev_hash` but excludes `hash`.

Tamper detection is one-line: change any byte of any record (or delete
or insert a row), and `jsonl-verify.py` will surface the break.

This is a minimum tamper-detection floor, not SOC2-grade audit. A real
audit log adds offline storage, time-stamped attestation, and a chain
of custody. This gives us "did something change after it was written?"
and nothing more — appropriate for zachflow's solo / small-team frame.

Usage:
    python3 scripts/lib/jsonl-append.py FILE 'JSON_PAYLOAD'

`JSON_PAYLOAD` is a JSON object string. Must not already contain
`hash` or `prev_hash` keys (those are the chain's responsibility).
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

GENESIS = "GENESIS"


def _canonical(record: dict) -> str:
    return json.dumps(record, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def _compute_hash(record: dict) -> str:
    return hashlib.sha256(_canonical(record).encode("utf-8")).hexdigest()


def _last_hash(path: Path) -> str:
    if not path.exists() or path.stat().st_size == 0:
        return GENESIS
    last = None
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            stripped = line.strip()
            if stripped:
                last = stripped
    if not last:
        return GENESIS
    try:
        rec = json.loads(last)
    except json.JSONDecodeError as e:
        sys.exit(f"Error: last line of {path} is not valid JSON: {e}")
    if "hash" not in rec:
        # Legacy file (pre-hash-chain) — refuse to append in chain mode.
        # The operator must rotate / re-seed the file to start a new chain.
        sys.exit(
            f"Error: {path} has legacy (un-chained) lines. Rotate the file "
            f"(e.g. mv {path} {path}.legacy) before chained append."
        )
    return rec["hash"]


def main() -> int:
    if len(sys.argv) != 3:
        sys.exit("Usage: jsonl-append.py FILE 'JSON_PAYLOAD'")

    path = Path(sys.argv[1])
    try:
        payload = json.loads(sys.argv[2])
    except json.JSONDecodeError as e:
        sys.exit(f"Error: payload is not valid JSON: {e}")
    if not isinstance(payload, dict):
        sys.exit("Error: payload must be a JSON object")
    if "hash" in payload or "prev_hash" in payload:
        sys.exit("Error: payload must not contain 'hash' or 'prev_hash' fields")

    prev = _last_hash(path)
    record = dict(payload)
    record["prev_hash"] = prev
    record["hash"] = _compute_hash(record)

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(_canonical(record) + "\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
