#!/usr/bin/env python3
"""Context guard — confirm phase checkpoints exist and are non-anemic.

Runs at any phase transition. The Sprint workflow's §8 (Context
checkpoint) requires every phase or group transition to produce a
structured summary file. Without it, the next phase falls back on raw
prior artifacts and the context window fills with irrelevant detail.

The guard checks that the just-completed phase's checkpoint:
  - exists at `runs/<sprint-id>/checkpoints/phase-<N>-summary.md`
    (or `group-<NNN>-summary.md` / `group-<N>-summary.md` for Build Loop
    groups — the guard accepts either zero-padded or bare numeric),
  - is at least `--min-bytes` long (default 100),
  - contains at least one markdown heading (`#`, `##`, ...).

When entering Phase 4 or later, also verifies that ALL prior phase
checkpoints exist. Missing chain = context discipline broke earlier.

Usage:
    python3 scripts/lib/guards/context_guard.py \\
        --sprint-dir runs/sprint/<id> \\
        (--phase-completed N | --group N) \\
        [--next-phase N] [--min-bytes 100]

Exit:
    0  pass / warn
    1  --strict + warn
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import base_argparser, emit_and_exit, resolve_sprint_dir  # noqa: E402

# Phases are numbered 1..6 in zachflow's Sprint workflow:
#   1 init / 2 spec / 3 prototype / 4 build / 5 pr / 6 retro
# Chain check fires when entering phase 4 (build) or later, since that
# is the first phase that consumes prior-phase checkpoints heavily.
HEADING_RE = re.compile(r"^#{1,6}\s+\S", re.MULTILINE)


def _resolve_group_checkpoint(checkpoints_dir: Path, group: int) -> Path:
    """zachflow uses zero-padded `group-NNN-summary.md` per sprint SKILL.md, but some
    older runs and the build-loop's free-form reference use bare `group-N-summary.md`.
    Try padded first, fall back to bare. Always return *something* (the padded form
    is what we'll report if neither exists)."""
    padded = checkpoints_dir / f"group-{group:03d}-summary.md"
    if padded.is_file():
        return padded
    bare = checkpoints_dir / f"group-{group}-summary.md"
    if bare.is_file():
        return bare
    return padded


def _check_checkpoint(path: Path, min_bytes: int) -> tuple[bool, str]:
    """Return (ok, reason_if_not_ok)."""
    if not path.is_file():
        return False, f"missing: {path.name}"
    size = path.stat().st_size
    if size < min_bytes:
        return False, f"anemic: {path.name} is {size} bytes (< {min_bytes})"
    text = path.read_text(encoding="utf-8")
    if not HEADING_RE.search(text):
        return False, f"unstructured: {path.name} has no markdown headings"
    return True, ""


def main() -> int:
    parser = base_argparser("context_guard.py", requires_group=False)
    parser.add_argument("--phase-completed", type=int, default=None,
                        help="Phase number (1..6) whose checkpoint must exist")
    parser.add_argument("--group", type=int, default=None,
                        help="Build Loop group number; checks group-N-summary.md (padded or bare)")
    parser.add_argument("--next-phase", type=int, default=None,
                        help="Phase number we are about to enter (≥4 enables chain check)")
    parser.add_argument("--min-bytes", type=int, default=100,
                        help="Minimum checkpoint size in bytes (default 100)")
    args = parser.parse_args()

    if args.phase_completed is None and args.group is None:
        sys.exit("Error: pass --phase-completed N or --group N")

    sprint_dir = resolve_sprint_dir(args.sprint_dir)
    checkpoints_dir = sprint_dir / "checkpoints"

    findings: list[str] = []

    # 1. Primary check: the just-completed checkpoint exists.
    if args.group is not None:
        target = _resolve_group_checkpoint(checkpoints_dir, args.group)
    else:
        target = checkpoints_dir / f"phase-{args.phase_completed}-summary.md"
    ok, reason = _check_checkpoint(target, args.min_bytes)
    if not ok:
        findings.append(reason)

    # 2. Chain check: when entering phase 4 (build) or later, prior phase
    # checkpoints all exist.
    chain_missing: list[str] = []
    if args.next_phase is not None and args.next_phase >= 4:
        for prior in range(1, args.next_phase):
            p = checkpoints_dir / f"phase-{prior}-summary.md"
            if not p.is_file():
                chain_missing.append(f"phase-{prior}")
        if chain_missing:
            findings.append(
                f"chain-broken: prior phase checkpoint(s) missing: {', '.join(chain_missing)}"
            )

    payload = {
        "checkpoint_path": str(target.relative_to(sprint_dir.parent.parent))
        if target.is_relative_to(sprint_dir.parent.parent) else str(target),
        "exists": target.is_file(),
        "size_bytes": target.stat().st_size if target.is_file() else 0,
        "next_phase": args.next_phase,
        "chain_missing": chain_missing,
        "findings": findings,
    }

    if not findings:
        verdict = "pass"
        summary = f"{target.name} OK ({payload['size_bytes']} bytes)"
    else:
        verdict = "block" if args.strict else "warn"
        summary = "; ".join(findings)

    return emit_and_exit("context", verdict, sprint_dir, args.group, payload,
                         message=summary)


if __name__ == "__main__":
    sys.exit(main())
