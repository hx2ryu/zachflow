#!/usr/bin/env python3
"""Pattern lifecycle curator.

Two modes:

1. Auto mode (default) — scans every pattern under
   `${KB_PATH}/learning/patterns/*.yaml`, counts references in jsonl logs
   under the project root, and applies the lifecycle rules:

     - promote: state == "draft"  && use_count >= 3                 -> "stable"
     - archive: state == "stable" && use_count == archive_threshold
                                  && discovered_at older than ttl_days -> "archived"

   `pinned: true` patterns bypass both transitions. Archive moves the
   file into `${KB_PATH}/learning/patterns/.archive/`.

   Every transition is appended to `${project_root}/logs/curator.jsonl`
   as a hash-chained record. `use_count` and `last_referenced_at` are
   refreshed in place whether or not a transition fired.

2. Manual mode (--pattern-id ID --target-state STATE) — bypasses the
   rule engine and forces a single transition. Used by the
   `zachflow-kb:promote-pattern` / `archive-pattern` skills.

Usage:
    python3 scripts/lib/curator.py --kb-path PATH [--apply]
        [--ttl-days 90] [--archive-threshold 0]
        [--pattern-id ID --target-state {draft,stable,archived}]
        [--pinned {true,false}]

Exit:
    0  success (including dry-run that suggests transitions)
    1  validation, IO, or argument error
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

import yaml
import jsonschema

GENESIS = "GENESIS"
VALID_STATES = ("draft", "stable", "archived")


# ---------- jsonl hash chain (inlined from jsonl-append.py) ----------------

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
    if "hash" in payload or "prev_hash" in payload:
        raise ValueError("payload must not contain 'hash' or 'prev_hash'")
    prev = _last_hash(log_path)
    record = dict(payload)
    record["prev_hash"] = prev
    record["hash"] = _compute_hash(record)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as f:
        f.write(_canonical(record) + "\n")


# ---------- pattern IO -----------------------------------------------------

def _load_schema(repo_root: Path) -> dict:
    schema_path = repo_root / "schemas" / "learning" / "pattern.schema.json"
    if not schema_path.exists():
        sys.exit(f"Error: schema missing at {schema_path}")
    return json.loads(schema_path.read_text(encoding="utf-8"))


def _load_pattern(path: Path) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def _write_pattern(path: Path, data: dict) -> None:
    path.write_text(
        yaml.safe_dump(data, sort_keys=False, default_flow_style=False),
        encoding="utf-8",
    )


# ---------- log scan -------------------------------------------------------

def _iter_log_files(project_root: Path):
    for pattern in ("logs/**/*.jsonl", "runs/**/*.jsonl"):
        for p in project_root.glob(pattern):
            if p.is_file():
                yield p


def scan_use_counts(project_root: Path) -> tuple[dict[str, int], dict[str, str]]:
    """Return (counts_by_id, last_seen_iso_by_id) from jsonl logs.

    Counts only structured references: a record's `pattern_id` (string) or
    `pattern_ids` (list of strings). Free-text body matches are ignored to
    avoid false positives from agents naming patterns in prose.
    """
    counts: dict[str, int] = {}
    last_seen: dict[str, str] = {}
    for log in _iter_log_files(project_root):
        try:
            text = log.read_text(encoding="utf-8")
        except OSError:
            continue
        for line in text.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(rec, dict):
                continue
            ids: list[str] = []
            v = rec.get("pattern_id")
            if isinstance(v, str):
                ids.append(v)
            v = rec.get("pattern_ids")
            if isinstance(v, list):
                ids.extend(x for x in v if isinstance(x, str))
            if not ids:
                continue
            ts = rec.get("ts") or rec.get("timestamp")
            for pid in ids:
                counts[pid] = counts.get(pid, 0) + 1
                if isinstance(ts, str) and ts > last_seen.get(pid, ""):
                    last_seen[pid] = ts
    return counts, last_seen


# ---------- decision -------------------------------------------------------

def _parse_iso(ts: str) -> datetime:
    return datetime.fromisoformat(ts.replace("Z", "+00:00"))


def decide(data: dict, use_count: int, ttl_days: int, archive_threshold: int,
           now: datetime) -> str | None:
    if data.get("pinned"):
        return None
    state = data.get("state")
    if state == "draft" and use_count >= 3:
        return "stable"
    if state == "stable" and use_count == archive_threshold:
        try:
            age = (now - _parse_iso(data["discovered_at"])).days
        except (KeyError, ValueError):
            return None
        if age > ttl_days:
            return "archived"
    return None


# ---------- transitions ----------------------------------------------------

def _now_iso() -> str:
    return datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def apply_transition(path: Path, data: dict, target_state: str,
                     patterns_dir: Path) -> Path:
    """Write the new state. For archive, also move the file. Returns final path."""
    if target_state not in VALID_STATES:
        raise ValueError(f"invalid target_state {target_state!r}")
    data["state"] = target_state
    _write_pattern(path, data)
    if target_state == "archived":
        archive_dir = patterns_dir / ".archive"
        archive_dir.mkdir(parents=True, exist_ok=True)
        dest = archive_dir / path.name
        shutil.move(str(path), str(dest))
        return dest
    return path


def refresh_usage(path: Path, data: dict, use_count: int,
                  last_seen: str | None) -> bool:
    """Mutate use_count / last_referenced_at on disk. Return True if changed."""
    old_count = int(data.get("use_count", 0) or 0)
    old_last = data.get("last_referenced_at") or ""
    new_last = last_seen if (last_seen and last_seen > old_last) else (old_last or None)
    if old_count == use_count and (old_last or None) == new_last:
        return False
    data["use_count"] = use_count
    data["last_referenced_at"] = new_last
    _write_pattern(path, data)
    return True


# ---------- main -----------------------------------------------------------

def _auto_mode(args, patterns_dir: Path, project_root: Path,
               schema: dict, log_path: Path) -> int:
    use_counts, last_seen = scan_use_counts(project_root)
    now = datetime.now(tz=timezone.utc)
    rc = 0
    for path in sorted(patterns_dir.glob("*.yaml")):
        try:
            data = _load_pattern(path)
        except yaml.YAMLError as e:
            print(f"skip (yaml error): {path.name}: {e}", file=sys.stderr)
            rc = 1
            continue
        if data.get("schema_version") != 2:
            print(f"skip (not schema v2): {path.name}")
            continue
        pid = data.get("id", "")
        new_count = use_counts.get(pid, 0)
        new_last = last_seen.get(pid)
        target = decide(data, new_count, args.ttl_days, args.archive_threshold, now)

        old_state = data.get("state", "draft")
        if args.apply:
            changed = refresh_usage(path, data, new_count, new_last)
            if target:
                apply_transition(path, data, target, patterns_dir)
                jsonschema.validate(data, schema)
                append_event(log_path, {
                    "ts": _now_iso(),
                    "event": "pattern.state_changed",
                    "pattern_id": pid,
                    "from_state": old_state,
                    "to_state": target,
                    "use_count": new_count,
                    "reason": ("promote: use_count>=3" if target == "stable"
                               else f"archive: use_count=={args.archive_threshold} ttl>{args.ttl_days}d"),
                })
                print(f"{pid}: {old_state} -> {target} (use_count={new_count})")
            elif changed:
                jsonschema.validate(data, schema)
                print(f"{pid}: state={old_state} use_count={new_count} (no transition)")
        else:
            if target:
                print(f"{pid}: would {old_state} -> {target} (use_count={new_count})")
            else:
                print(f"{pid}: state={old_state} use_count={new_count} (no change)")
    return rc


def _manual_mode(args, patterns_dir: Path, project_root: Path,
                 schema: dict, log_path: Path) -> int:
    pid = args.pattern_id
    matches = list(patterns_dir.glob(f"{pid}.yaml"))
    if not matches:
        sys.exit(f"Error: pattern {pid!r} not found in {patterns_dir}")
    path = matches[0]
    data = _load_pattern(path)
    if data.get("schema_version") != 2:
        sys.exit(f"Error: pattern {pid!r} is not schema v2; migrate first")
    old_state = data.get("state", "draft")
    target = args.target_state  # may be None (pinned-only toggle)
    if target and data.get("pinned") and target == "archived":
        sys.exit(f"Error: pattern {pid!r} is pinned; archive refused")

    will_transition = bool(target) and target != old_state
    will_pin = args.pinned is not None and (args.pinned == "true") != bool(data.get("pinned"))

    if not will_transition and not will_pin:
        print(f"{pid}: no change (state={old_state} pinned={data.get('pinned')})")
        return 0

    if args.pinned is not None:
        data["pinned"] = (args.pinned == "true")

    if args.apply:
        if will_transition:
            apply_transition(path, data, target, patterns_dir)
        else:
            _write_pattern(path, data)
        jsonschema.validate(data, schema)
        if will_transition:
            append_event(log_path, {
                "ts": _now_iso(),
                "event": "pattern.state_changed",
                "pattern_id": pid,
                "from_state": old_state,
                "to_state": target,
                "use_count": int(data.get("use_count", 0) or 0),
                "reason": "manual",
            })
        msg = f"{pid}: {old_state}" + (f" -> {target}" if will_transition else "")
        if will_pin:
            msg += f" pinned={data['pinned']}"
        print(msg)
    else:
        msg = f"{pid}: would " + (f"{old_state} -> {target}" if will_transition else "no-op")
        if will_pin:
            msg += f" pinned={data['pinned']}"
        print(msg)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Pattern lifecycle curator.")
    parser.add_argument("--kb-path", required=True, help="Path to .zachflow/kb")
    parser.add_argument("--apply", action="store_true",
                        help="Apply transitions (default: dry-run, print decisions)")
    parser.add_argument("--ttl-days", type=int, default=90,
                        help="Days a stable pattern can sit unused before archive (default 90)")
    parser.add_argument("--archive-threshold", type=int, default=0,
                        help="use_count at-or-below threshold for archive eligibility (default 0)")
    parser.add_argument("--pattern-id", default=None,
                        help="Manual mode: target pattern id (forces transition, bypasses rules)")
    parser.add_argument("--target-state", default=None, choices=VALID_STATES,
                        help="Manual mode: state to transition to")
    parser.add_argument("--pinned", default=None, choices=["true", "false"],
                        help="Manual mode: toggle pinned flag (independent of state)")
    args = parser.parse_args()

    manual = args.pattern_id is not None
    if not manual:
        if args.target_state or args.pinned is not None:
            sys.exit("Error: --target-state and --pinned require --pattern-id")
    else:
        if args.target_state is None and args.pinned is None:
            sys.exit("Error: --pattern-id requires --target-state or --pinned")

    kb = Path(args.kb_path).resolve()
    patterns_dir = kb / "learning" / "patterns"
    if not patterns_dir.is_dir():
        sys.exit(f"Error: {patterns_dir} not found")

    project_root = kb.parent.parent  # .zachflow/kb -> project
    repo_root = Path(__file__).resolve().parents[2]
    schema = _load_schema(repo_root)
    log_path = project_root / "logs" / "curator.jsonl"

    if manual:
        return _manual_mode(args, patterns_dir, project_root, schema, log_path)
    return _auto_mode(args, patterns_dir, project_root, schema, log_path)


if __name__ == "__main__":
    sys.exit(main())
