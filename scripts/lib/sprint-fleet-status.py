#!/usr/bin/env python3
"""Cross-sprint fleet status dashboard.

Zero-arg companion to `/sprint --status` (single-sprint). Scans
runs/sprint/*/ and prints a fleet table separating in-flight sprints
(no retrospective artifacts yet) from completed ones (retrospective
files present).

Phase inference (per-sprint) mirrors workflows/sprint/SKILL.md's
"Phase Determination Logic", using local directory state only — no
network calls (gh, etc).

Usage:
    python3 scripts/lib/sprint-fleet-status.py [--runs-dir PATH]

Exit:
    0 always (empty runs directory is a valid "no sprints" state).
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

# Windows-native Python defaults stdout to cp1252, which fails on the
# box-drawing characters in the dashboard. Reconfigure once at import.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


PHASE_FALLBACK = "phase-1 (init)"


def detect_phase(sd: Path) -> str:
    """Coarse phase inference from artifact presence.

    The single-sprint dashboard does a much richer detection (PR status,
    Agent Activity, fix-loop round). This fleet view only needs enough
    to say "where in the pipeline is this sprint roughly."
    """
    if not (sd / "sprint-config.yaml").exists():
        return PHASE_FALLBACK

    retro = sd / "retrospective"
    if retro.is_dir() and any(_real_files(retro)):
        return "done"

    checkpoints = sd / "checkpoints"
    if (checkpoints / "phase-5-summary.md").exists():
        return "phase-6 (retro)"

    evals = sd / "evaluations"
    contracts = sd / "contracts"
    if evals.is_dir() and any(evals.glob("group-*.md")):
        # Some groups evaluated. Distinguish "still building" from "build done".
        if contracts.is_dir() and len(list(contracts.glob("group-*.md"))) > len(
            list(evals.glob("group-*.md"))
        ):
            return "phase-4 (build)"
        return "phase-4/5"

    if contracts.is_dir() and any(contracts.glob("group-*.md")):
        return "phase-4 (build)"

    if (sd / "approval-status.yaml").exists():
        return "phase-3 (proto)"

    tasks_dir = sd / "tasks"
    has_tasks = tasks_dir.is_dir() and any(tasks_dir.glob("**/*.md"))
    if (sd / "api-contract.yaml").exists() or has_tasks:
        return "phase-2 (spec)"

    return PHASE_FALLBACK


def _real_files(d: Path):
    for f in d.iterdir():
        if not f.is_file():
            continue
        if f.name.startswith("."):
            continue
        yield f


def count_groups(sd: Path) -> str:
    contracts = sd / "contracts"
    evals = sd / "evaluations"
    n_contracts = len(list(contracts.glob("group-*.md"))) if contracts.is_dir() else 0
    n_evals = len(list(evals.glob("group-*.md"))) if evals.is_dir() else 0
    if n_contracts == 0 and n_evals == 0:
        return "—"

    pass_count = 0
    if evals.is_dir():
        for e in evals.glob("group-*.md"):
            text = e.read_text(encoding="utf-8")
            verdict_line = _first_verdict_line(text)
            if verdict_line and "PASS" in verdict_line.upper():
                pass_count += 1
    total = max(n_contracts, n_evals)
    return f"{pass_count}/{total}"


def _first_verdict_line(text: str) -> str | None:
    """Find the first line that looks like a Verdict declaration.

    Evaluator reports vary in shape (markdown table vs prose), so we scan
    the first ~40 non-blank lines for `verdict` (case-insensitive).
    """
    seen = 0
    for line in text.splitlines():
        if not line.strip():
            continue
        seen += 1
        if seen > 40:
            break
        if "verdict" in line.lower():
            return line
    return None


def is_in_flight(sd: Path) -> bool:
    retro = sd / "retrospective"
    if not retro.is_dir():
        return True
    return not any(_real_files(retro))


def last_activity(sd: Path) -> str:
    candidates = []
    for sub in ("logs", "checkpoints", "evaluations", "contracts", "tasks", "qa-fix"):
        p = sd / sub
        if not p.is_dir():
            continue
        for f in p.rglob("*"):
            if f.is_file() and not f.name.startswith("."):
                candidates.append(f.stat().st_mtime)
    if not candidates:
        candidates.append(sd.stat().st_mtime)
    ts = max(candidates)
    return datetime.fromtimestamp(ts, tz=timezone.utc).strftime("%Y-%m-%d %H:%MZ")


def fix_loop_count(sd: Path) -> str:
    """Crude proxy: count evaluations whose body contains 'Fix Loop' iterations.

    Each evaluation report appends Fix Loop rounds; counting the maximum
    referenced round per group then summing gives a fleet-level signal.
    Returns "—" if no signal.
    """
    evals = sd / "evaluations"
    if not evals.is_dir():
        return "—"
    total = 0
    for e in evals.glob("group-*.md"):
        text = e.read_text(encoding="utf-8").lower()
        # Look for tokens like "fix loop round 1", "round 2", etc.
        rounds = []
        for line in text.splitlines():
            if "fix loop" in line or "round" in line:
                for token in line.replace(",", " ").split():
                    if token.isdigit():
                        rounds.append(int(token))
        if rounds:
            total += max(rounds)
    return str(total) if total > 0 else "—"


def gather_rows(runs_dir: Path) -> list[dict]:
    rows: list[dict] = []
    if not runs_dir.is_dir():
        return rows
    for d in sorted(runs_dir.iterdir()):
        if not d.is_dir():
            continue
        if not (d / "sprint-config.yaml").exists():
            continue
        rows.append(
            {
                "id": d.name,
                "phase": detect_phase(d),
                "groups": count_groups(d),
                "fix_loops": fix_loop_count(d),
                "last": last_activity(d),
                "in_flight": is_in_flight(d),
            }
        )
    return rows


def _print_table(rows: list[dict]) -> None:
    header = ("sprint-id", "phase", "groups", "fix-loops", "last activity")
    widths = (26, 18, 8, 9, 18)
    sep_row = "  " + "  ".join("─" * w for w in widths)
    head_row = "  " + "  ".join(h.ljust(w) for h, w in zip(header, widths))
    print(head_row)
    print(sep_row)
    for r in rows:
        cells = (
            r["id"][: widths[0]],
            r["phase"][: widths[1]],
            r["groups"][: widths[2]],
            r["fix_loops"][: widths[3]],
            r["last"],
        )
        print("  " + "  ".join(c.ljust(w) for c, w in zip(cells, widths)))


def main() -> int:
    parser = argparse.ArgumentParser(description="Cross-sprint fleet status.")
    parser.add_argument(
        "--runs-dir",
        default=None,
        help="Path to runs/sprint/. Defaults to <repo>/runs/sprint.",
    )
    args = parser.parse_args()

    if args.runs_dir:
        runs_dir = Path(args.runs_dir).resolve()
    else:
        repo_root = Path(__file__).resolve().parents[2]
        runs_dir = repo_root / "runs" / "sprint"

    rows = gather_rows(runs_dir)

    print("═" * 68)
    print("  Sprint Fleet")
    print("  Source: " + str(runs_dir))
    print("═" * 68)
    print()

    if not rows:
        print("  No sprint runs found.")
        print()
        print("═" * 68)
        return 0

    in_flight = [r for r in rows if r["in_flight"]]
    done = [r for r in rows if not r["in_flight"]]

    if in_flight:
        print(f"  In flight ({len(in_flight)}):")
        _print_table(in_flight)
    else:
        print("  No in-flight sprints.")
    print()

    if done:
        print(f"  Completed — retrospective present ({len(done)}):")
        _print_table(done)
        print()

    print("═" * 68)
    print("  Tip: /sprint <sprint-id> --status for per-sprint detail")
    print("═" * 68)
    return 0


if __name__ == "__main__":
    sys.exit(main())
