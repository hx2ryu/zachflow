# `logs/*.jsonl` hash chain

## What it is

Every line appended to a sprint's `logs/events.jsonl` (or any other JSONL
written via `scripts/lib/jsonl-append.py`) carries two extra fields:

| Field | Source |
|-------|--------|
| `prev_hash` | The previous line's `hash`, or `"GENESIS"` for line 1. |
| `hash` | `sha256(canonical_json(record))` where the record includes `prev_hash` but excludes `hash`. |

Tamper detection is one-line: change any byte of any record (or delete a
row, or insert a row), and `scripts/lib/jsonl-verify.py` surfaces the
break with a line number and a reason.

## What it is NOT

This is a **minimum tamper-detection floor**, not SOC2-grade audit. A
real audit log adds offline storage, signed time-stamped attestation, and
a chain of custody outside the producing machine. The hash chain here
detects local modification of a file you trust to begin with — useful as
a forensic signal, not as a compliance guarantee.

If you need real audit, ship `logs/*.jsonl` lines to an append-only sink
(S3 Object Lock, an SIEM, a managed audit log service) at write time.
This chain is the floor that catches accidental edits and the simplest
tampering attempts.

## Producers

- `scripts/hook-handler.sh` — Claude Code hooks (`SubagentStart`,
  `SubagentStop`, `TaskCreated`, `TaskCompleted`) append to the active
  sprint's `logs/events.jsonl`.
- `scripts/lib/curator.py` — the pattern curator appends a
  `pattern.state_changed` record per transition to
  `logs/curator.jsonl`. This file is **kb-scoped, not sprint-bounded**:
  one chain spans the lifetime of the KB. Rotate it like any other
  chained file if the chain ever breaks.
- Other workflow scripts can append by shelling out to
  `python3 scripts/lib/jsonl-append.py FILE 'JSON_PAYLOAD'`.

The payload must not already contain `hash` or `prev_hash` — those are
the chain's responsibility.

## Verifying

```bash
python3 scripts/lib/jsonl-verify.py runs/sprint/<id>/logs/events.jsonl
```

Exit 0 on a clean chain (or on a legacy file with no hash fields). Exit
1 with a line number + reason on a chain break.

Multiple files in one call:

```bash
python3 scripts/lib/jsonl-verify.py runs/sprint/*/logs/events.jsonl
```

## Legacy files (pre-hash-chain sprints)

A file with **no** hash fields on any line is reported `"no chain
(legacy)"` and exits 0. The chain protocol only activates the moment
the first chained line is written.

A file with **mixed** chained and un-chained lines fails verification —
those are either tampering or rotation accidents. To start a chain on a
previously-legacy file:

```bash
mv events.jsonl events.jsonl.legacy
# next jsonl-append.py call seeds GENESIS → new chain
```

`jsonl-append.py` will refuse to append to a legacy file directly, with
an error pointing at this rotation step.

## When the chain is broken

The first failure surfaced is the **earliest** break. Possible causes:

| Symptom | Likely cause |
|---------|--------------|
| `line N: hash mismatch (record content was modified)` | Someone edited a field. |
| `line N: prev_hash mismatch — expected X..., got Y...` | A line was deleted or inserted before this one. |
| `line N: chain mode mixed with un-chained lines` | A producer bypassed `jsonl-append.py`. |
| `line N: invalid JSON` | File corruption or a stray write. |

To recover: rotate the file (`mv → .broken`) and start a new chain. The
broken file is preserved as evidence — do not delete it.
