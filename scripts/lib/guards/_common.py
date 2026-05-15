"""Shared helpers for failure-mode guards.

Each guard under `scripts/lib/guards/` runs at a defined phase-transition
boundary. The guards emit hash-chained records to `logs/guards.jsonl` so
that an external verifier (`scripts/lib/jsonl-verify.py`) can confirm
no record was added or modified after the fact.

Verdict vocabulary:
    pass   — guard ran, no concern
    warn   — heuristic signal; workflow caller continues but the user
             is alerted (3 of the 4 guards stop here)
    block  — deterministic violation; workflow caller MUST NOT advance
             (drift_guard is the only producer of `block` at present)

Each guard's CLI MUST exit 0 on `pass`/`warn` and 1 on `block`. Workflow
markdown reads the exit code to decide whether to proceed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

GENESIS = "GENESIS"
VERDICTS = ("pass", "warn", "block")


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
        sys.exit(
            f"Error: {path} has legacy (un-chained) lines. Rotate the file "
            f"(e.g. mv {path} {path}.legacy) before chained append."
        )
    return rec["hash"]


def append_event(log_path: Path, payload: dict) -> None:
    """Append a record to the hash chain at log_path."""
    if "hash" in payload or "prev_hash" in payload:
        raise ValueError("payload must not contain 'hash' or 'prev_hash'")
    prev = _last_hash(log_path)
    record = dict(payload)
    record["prev_hash"] = prev
    record["hash"] = _compute_hash(record)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as f:
        f.write(_canonical(record) + "\n")


def now_iso() -> str:
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def resolve_project_root(sprint_dir: Path) -> Path:
    """Walk up from a sprint dir until we find a `runs/` parent."""
    for ancestor in [sprint_dir, *sprint_dir.parents]:
        if (ancestor / ".git").exists() or (ancestor / "runs").is_dir():
            return ancestor
    return sprint_dir.parent


def resolve_sprint_dir(arg: str | None) -> Path:
    """Resolve --sprint-dir argument or auto-detect from cwd."""
    if arg:
        p = Path(arg).resolve()
        if not p.is_dir():
            sys.exit(f"Error: sprint dir not found: {p}")
        return p
    # Auto-detect: look for runs/sprint/* under cwd's git root.
    cwd = Path.cwd().resolve()
    for ancestor in [cwd, *cwd.parents]:
        runs = ancestor / "runs" / "sprint"
        if runs.is_dir():
            candidates = sorted([p for p in runs.iterdir() if p.is_dir()])
            if len(candidates) == 1:
                return candidates[0]
            if len(candidates) > 1:
                sys.exit(
                    f"Error: multiple sprint dirs under {runs}; pass --sprint-dir explicitly"
                )
    sys.exit("Error: cannot auto-detect sprint dir; pass --sprint-dir")


def guards_log_path(sprint_dir: Path) -> Path:
    """All four guards write to `<project>/logs/guards.jsonl`.

    Why project-scoped (not sprint-scoped): a single chain across sprints
    makes longitudinal pattern detection trivial. Rotate by renaming if
    the chain ever breaks (see docs/logs-hash-chain.md).
    """
    project = resolve_project_root(sprint_dir)
    return project / "logs" / "guards.jsonl"


def emit_and_exit(guard: str, verdict: str, sprint_dir: Path, group: int | None,
                  payload: dict, *, message: str = "") -> int:
    """Standard exit path: emit jsonl event, print one-line summary, return exit code.

    `verdict` must be one of {"pass", "warn", "block"}.
    Returns the exit code (0 for pass/warn, 1 for block).
    """
    if verdict not in VERDICTS:
        raise ValueError(f"invalid verdict {verdict!r}")
    log_path = guards_log_path(sprint_dir)
    record = {
        "ts": now_iso(),
        "event": f"guard.{guard}",
        "guard": guard,
        "verdict": verdict,
        "sprint_id": sprint_dir.name,
    }
    if group is not None:
        record["group"] = group
    record.update(payload)
    append_event(log_path, record)

    icon = {"pass": "✓", "warn": "⚠", "block": "✗"}[verdict]
    summary = message or record.get("summary", "")
    print(f"{icon} {guard}: {verdict}" + (f" — {summary}" if summary else ""))
    return 0 if verdict in ("pass", "warn") else 1


def base_argparser(prog: str, *, requires_group: bool = True) -> argparse.ArgumentParser:
    """Shared argparse boilerplate. Each guard adds its own flags on top."""
    parser = argparse.ArgumentParser(
        prog=prog,
        description=__doc__.splitlines()[0] if __doc__ else "",
    )
    parser.add_argument("--sprint-dir", default=None,
                        help="Path to runs/sprint/<id>/ (auto-detect if omitted)")
    if requires_group:
        parser.add_argument("--group", type=int, required=True,
                            help="Group number (Build Loop §4)")
    parser.add_argument("--strict", action="store_true",
                        help="Treat 'warn' as 'block' (exit 1 instead of 0)")
    return parser
