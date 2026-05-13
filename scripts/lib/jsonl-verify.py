#!/usr/bin/env python3
"""Verify the SHA-256 hash chain in one or more JSONL files.

Each line must:
- Be valid JSON.
- Contain `prev_hash` and `hash` fields.
- Have `prev_hash` equal to the previous line's `hash` (or "GENESIS" for line 1).
- Have `hash` equal to sha256(canonical_json(record_without_hash_field)).

Legacy files (no hash fields on any line) are reported "no chain" and
do NOT fail — keeps backwards compat for jsonl produced before the
chain was introduced. Mixed-mode files (some lines with hash, some
without) DO fail — those are likely tampering or rotation accidents.

Usage:
    python3 scripts/lib/jsonl-verify.py FILE [FILE ...]

Exit:
    0  every file verified clean (chained or legacy)
    1  any file fails — line number + reason printed
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


def verify(path: Path) -> tuple[bool, str]:
    if not path.exists():
        return False, f"missing: {path}"
    lines = [
        l for l in (line.strip() for line in path.read_text(encoding="utf-8").splitlines()) if l
    ]
    if not lines:
        return True, "empty"

    # Detect chain presence: any line carries a "hash" key.
    chained = []
    for i, line in enumerate(lines, 1):
        try:
            rec = json.loads(line)
        except json.JSONDecodeError as e:
            return False, f"line {i}: invalid JSON ({e})"
        chained.append("hash" in rec and "prev_hash" in rec)

    if not any(chained):
        return True, f"no chain (legacy, {len(lines)} line(s))"
    if not all(chained):
        first_bad = chained.index(False) + 1
        return False, f"line {first_bad}: chain mode mixed with un-chained lines"

    prev = GENESIS
    for i, line in enumerate(lines, 1):
        rec = json.loads(line)
        actual_hash = rec.pop("hash")
        if rec["prev_hash"] != prev:
            return False, (
                f"line {i}: prev_hash mismatch — expected {prev[:12]}..., "
                f"got {rec['prev_hash'][:12]}..."
            )
        expected_hash = hashlib.sha256(_canonical(rec).encode("utf-8")).hexdigest()
        if expected_hash != actual_hash:
            return False, f"line {i}: hash mismatch (record content was modified)"
        prev = actual_hash

    return True, f"{len(lines)} line(s) verified"


def main() -> int:
    if len(sys.argv) < 2:
        sys.exit("Usage: jsonl-verify.py FILE [FILE ...]")

    failures: list[str] = []
    for p in sys.argv[1:]:
        ok, msg = verify(Path(p))
        prefix = "OK   " if ok else "FAIL "
        print(f"  {prefix}{p}: {msg}")
        if not ok:
            failures.append(p)

    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
