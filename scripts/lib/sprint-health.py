#!/usr/bin/env python3
"""Per-sprint deep-dive health aggregator.

Companion to `scripts/lib/sprint-fleet-status.py` (cross-sprint summary)
and `/sprint <id> --status` (per-sprint phase/group detail). This script
focuses on **outcomes**: what verdicts came back, how many fix loops
fired, what the failure-mode guards caught, and which patterns the
sprint contributed.

Data sources (all read-only):
  - `runs/sprint/<id>/contracts/group-*.md` — group count
  - `runs/sprint/<id>/evaluations/group-*.md` — standard verdicts
  - `runs/sprint/<id>/evaluations/group-*.adversarial.md` — adversarial verdicts
  - `runs/sprint/<id>/logs/evaluator.jsonl` — evaluation round count per group
  - `runs/sprint/<id>/logs/events.jsonl` — time span
  - `<project>/logs/guards.jsonl` — filtered by `sprint_id == <id>`
  - `<project>/.zachflow/kb/learning/patterns/*.yaml` — filtered by
    `source_sprint == <id>` (patterns this sprint contributed)
  - `<project>/logs/curator.jsonl` — curator transitions on those patterns

Output formats:
  - markdown (default) — human-readable, suitable for posting to a PR or
    pasting into a Retro note
  - json — structured snapshot, suitable for piping into other tools

Usage:
    python3 scripts/lib/sprint-health.py [--sprint-dir PATH] [--format {markdown,json}]

Exit:
    0 always (missing sub-files are reported as gaps, not failures).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

VERDICT_RE = re.compile(
    r"^\s*-?\s*(?:Verdict|Score)\s*:\s*(PASS|ISSUES|FAIL)",
    re.IGNORECASE | re.MULTILINE,
)
GROUP_RE = re.compile(r"^group-(\d+)\.md$")
GROUP_ADV_RE = re.compile(r"^group-(\d+)\.adversarial\.md$")


def _parse_verdict(path: Path) -> str | None:
    if not path.is_file():
        return None
    m = VERDICT_RE.search(path.read_text(encoding="utf-8"))
    return m.group(1).upper() if m else None


def _iter_jsonl(path: Path):
    if not path.is_file():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            yield json.loads(line)
        except json.JSONDecodeError:
            continue


def _resolve_project(sprint_dir: Path) -> Path:
    for ancestor in [sprint_dir, *sprint_dir.parents]:
        if (ancestor / ".git").exists() or (ancestor / "runs").is_dir():
            return ancestor
    return sprint_dir.parent


def _resolve_sprint_dir(arg: str | None) -> Path:
    if arg:
        p = Path(arg).resolve()
        if not p.is_dir():
            sys.exit(f"Error: sprint dir not found: {p}")
        return p
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


def collect(sprint_dir: Path) -> dict:
    project = _resolve_project(sprint_dir)
    sprint_id = sprint_dir.name

    contracts_dir = sprint_dir / "contracts"
    evals_dir = sprint_dir / "evaluations"
    logs_dir = sprint_dir / "logs"

    # --- Groups ----------------------------------------------------------
    contract_groups = sorted(
        int(p.stem.split("-")[1])
        for p in contracts_dir.glob("group-*.md")
        if p.stem.split("-")[1].isdigit()
    ) if contracts_dir.is_dir() else []

    group_rows: list[dict] = []
    for n in contract_groups:
        std_verdict = _parse_verdict(evals_dir / f"group-{n}.md")
        adv_verdict = _parse_verdict(evals_dir / f"group-{n}.adversarial.md")
        group_rows.append({"group": n, "standard": std_verdict, "adversarial": adv_verdict})

    # --- Evaluation rounds (fix-loop proxy) ------------------------------
    rounds_per_group: dict[int, int] = {}
    for rec in _iter_jsonl(logs_dir / "evaluator.jsonl"):
        if rec.get("phase") not in ("evaluating", "completed"):
            continue
        subj = rec.get("task", "")
        m = re.search(r"group[-\s_]?(\d+)", subj.lower())
        if m:
            g = int(m.group(1))
            rounds_per_group[g] = rounds_per_group.get(g, 0) + 1
    for row in group_rows:
        rounds = rounds_per_group.get(row["group"], 0)
        # "Rounds" counts evaluator-tagged events; fix_loops ≈ max(rounds-1, 0)
        row["eval_rounds"] = rounds
        row["fix_loops"] = max(rounds - 1, 0)

    # --- Time span -------------------------------------------------------
    timestamps: list[str] = []
    for jl in (logs_dir / "events.jsonl",
               logs_dir / "evaluator.jsonl",
               logs_dir / "evaluator-adversarial.jsonl"):
        for rec in _iter_jsonl(jl):
            ts = rec.get("ts") or rec.get("timestamp")
            if isinstance(ts, str):
                timestamps.append(ts)
    time_span = {
        "first_ts": min(timestamps) if timestamps else None,
        "last_ts": max(timestamps) if timestamps else None,
    }

    # --- Guards (project-scoped, filter on sprint_id) -------------------
    guards_buckets = {
        "drift": {"pass": 0, "warn": 0, "block": 0},
        "self_deception": {"pass": 0, "warn": 0, "block": 0},
        "context": {"pass": 0, "warn": 0, "block": 0},
        "regression": {"pass": 0, "warn": 0, "block": 0},
    }
    guards_path = project / "logs" / "guards.jsonl"
    for rec in _iter_jsonl(guards_path):
        if rec.get("sprint_id") != sprint_id:
            continue
        name = rec.get("guard")
        verdict = rec.get("verdict")
        if name in guards_buckets and verdict in guards_buckets[name]:
            guards_buckets[name][verdict] += 1

    # --- Patterns contributed by this sprint ----------------------------
    patterns_dir = project / ".zachflow" / "kb" / "learning" / "patterns"
    sprint_patterns: list[str] = []
    if patterns_dir.is_dir():
        import yaml  # local import — only needed if KB exists
        for p in patterns_dir.glob("*.yaml"):
            try:
                data = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
            except yaml.YAMLError:
                continue
            if data.get("source_sprint") == sprint_id:
                sprint_patterns.append(data.get("id", p.stem))

    # --- Curator transitions on this sprint's patterns ------------------
    curator_path = project / "logs" / "curator.jsonl"
    curator_transitions: list[dict] = []
    for rec in _iter_jsonl(curator_path):
        if rec.get("pattern_id") in sprint_patterns:
            curator_transitions.append({
                "ts": rec.get("ts"),
                "pattern_id": rec.get("pattern_id"),
                "from_state": rec.get("from_state"),
                "to_state": rec.get("to_state"),
                "reason": rec.get("reason"),
            })

    # --- Aggregates ------------------------------------------------------
    std_counts = {"PASS": 0, "ISSUES": 0, "FAIL": 0, "pending": 0}
    adv_counts = {"PASS": 0, "ISSUES": 0, "absent": 0}
    for row in group_rows:
        std_counts[row["standard"] or "pending"] = std_counts.get(row["standard"] or "pending", 0) + 1
        if row["adversarial"] is None:
            adv_counts["absent"] += 1
        else:
            adv_counts[row["adversarial"]] = adv_counts.get(row["adversarial"], 0) + 1

    return {
        "sprint_id": sprint_id,
        "sprint_dir": str(sprint_dir),
        "project_root": str(project),
        "time_span": time_span,
        "groups": group_rows,
        "standard_counts": std_counts,
        "adversarial_counts": adv_counts,
        "guards": guards_buckets,
        "sprint_patterns": sprint_patterns,
        "curator_transitions": curator_transitions,
    }


def render_markdown(snapshot: dict) -> str:
    lines: list[str] = []
    lines.append(f"# Sprint Health: {snapshot['sprint_id']}")
    lines.append("")

    # Overview
    ts = snapshot["time_span"]
    span = "—" if not ts["first_ts"] else f"{ts['first_ts']} → {ts['last_ts']}"
    lines.append("## Overview")
    lines.append(f"- Sprint dir: `{snapshot['sprint_dir']}`")
    lines.append(f"- Time span: {span}")
    g = snapshot["groups"]
    sc = snapshot["standard_counts"]
    evald = sum(v for k, v in sc.items() if k != "pending")
    lines.append(f"- Groups: {evald}/{len(g)} evaluated")
    lines.append("")

    # Verdicts table
    lines.append("## Build Loop verdicts")
    if not g:
        lines.append("(no contracts in this sprint yet)")
    else:
        lines.append("| Group | Standard | Adversarial | Eval rounds | Fix loops |")
        lines.append("|------:|---------:|------------:|------------:|----------:|")
        for row in g:
            lines.append(
                f"| {row['group']} | {row['standard'] or '—'} | "
                f"{row['adversarial'] or '—'} | "
                f"{row.get('eval_rounds', 0)} | {row.get('fix_loops', 0)} |"
            )
        lines.append("")
        lines.append(
            f"Standard: PASS={sc.get('PASS', 0)} / ISSUES={sc.get('ISSUES', 0)} / "
            f"FAIL={sc.get('FAIL', 0)} / pending={sc.get('pending', 0)}"
        )
        ac = snapshot["adversarial_counts"]
        lines.append(
            f"Adversarial: PASS={ac.get('PASS', 0)} / ISSUES={ac.get('ISSUES', 0)} / "
            f"absent={ac.get('absent', 0)}"
        )
    lines.append("")

    # Guards
    lines.append("## Failure-mode guards (this sprint)")
    lines.append("| Guard | pass | warn | block |")
    lines.append("|-------|-----:|-----:|------:|")
    for name, buckets in snapshot["guards"].items():
        lines.append(
            f"| {name} | {buckets['pass']} | {buckets['warn']} | {buckets['block']} |"
        )
    lines.append("")

    # Patterns
    lines.append("## Patterns contributed")
    sp = snapshot["sprint_patterns"]
    if sp:
        lines.append(f"{len(sp)} new pattern(s) with `source_sprint: {snapshot['sprint_id']}`:")
        for pid in sorted(sp):
            lines.append(f"- `{pid}`")
    else:
        lines.append("(none recorded yet)")
    lines.append("")

    ct = snapshot["curator_transitions"]
    if ct:
        lines.append("### Curator transitions on those patterns")
        lines.append("| When | Pattern | From | To | Reason |")
        lines.append("|------|---------|------|----|--------|")
        for t in ct:
            lines.append(
                f"| {t.get('ts') or '—'} | `{t['pattern_id']}` | "
                f"{t.get('from_state') or '—'} | {t.get('to_state') or '—'} | "
                f"{t.get('reason') or '—'} |"
            )
        lines.append("")

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Per-sprint health snapshot.")
    parser.add_argument("--sprint-dir", default=None,
                        help="Path to runs/sprint/<id>/ (auto-detected if omitted)")
    parser.add_argument("--format", default="markdown",
                        choices=("markdown", "json"))
    args = parser.parse_args()

    sprint_dir = _resolve_sprint_dir(args.sprint_dir)
    snapshot = collect(sprint_dir)

    if args.format == "json":
        print(json.dumps(snapshot, indent=2, ensure_ascii=False))
    else:
        print(render_markdown(snapshot))
    return 0


if __name__ == "__main__":
    sys.exit(main())
