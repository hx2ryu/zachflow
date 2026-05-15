#!/usr/bin/env python3
"""Drift guard — catch incidental scope expansion.

Runs at the boundary between Build Loop §4.3 (group merge) and §4.4
(standard Evaluate). The signal that the Generator drifted from the
Contract has one **deterministic** form and one **heuristic** form:

  1. Deterministic (BLOCK): a commit on the group branch contains an
     "admission phrase" — natural-language patterns by which agents
     openly disclose that they also touched something outside scope.
     Catalog at ADMISSION_PHRASES below.

  2. Heuristic (WARN): when `--check-scope` is given and the Sprint
     Contract names explicit file paths (backtick-quoted), any file
     changed outside that set is flagged.

The guard reads git history; it does not need code state. Run against
each repo the group touched (backend/, app/, ...).

Usage:
    python3 scripts/lib/guards/drift_guard.py \\
        --sprint-dir runs/sprint/<id> --group N --base <base-ref> \\
        [--repo PATH] [--check-scope]

Exit:
    0  pass / warn
    1  block (admission phrase) OR --strict + warn
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import base_argparser, emit_and_exit, resolve_sprint_dir  # noqa: E402

# Each phrase is matched case-insensitively against full commit messages.
# Keep this list small and high-precision — false positives turn a guard
# into a nuisance. If a phrase produces a false alarm in real use,
# remove it (false negatives are recoverable, false blocks erode trust).
ADMISSION_PHRASES = (
    "while i'm here",
    "while i am here",
    "while we're at it",
    "while we are at it",
    "while i was at it",
    "also fix",       # matches "also fixed", "also fixes"
    "drive-by",
    "drive by fix",
    "side cleanup",
    "incidental cleanup",
    "incidental fix",
)


def _git_log_since(base: str, repo: Path) -> list[tuple[str, str]]:
    """Return [(short_sha, full_message), ...] for commits since `base`."""
    try:
        out = subprocess.run(
            ["git", "-C", str(repo), "log", "--format=%h%x1f%B%x1e",
             f"{base}..HEAD"],
            capture_output=True, text=True, check=True, encoding="utf-8",
        ).stdout
    except subprocess.CalledProcessError as e:
        sys.exit(f"Error: git log failed in {repo}: {e.stderr.strip()}")
    rows: list[tuple[str, str]] = []
    for entry in out.split("\x1e"):
        entry = entry.strip()
        if not entry:
            continue
        sha, _, msg = entry.partition("\x1f")
        rows.append((sha.strip(), msg.strip()))
    return rows


def _git_changed_files(base: str, repo: Path) -> list[str]:
    try:
        out = subprocess.run(
            ["git", "-C", str(repo), "diff", "--name-only", f"{base}..HEAD"],
            capture_output=True, text=True, check=True, encoding="utf-8",
        ).stdout
    except subprocess.CalledProcessError as e:
        sys.exit(f"Error: git diff failed in {repo}: {e.stderr.strip()}")
    return [l.strip() for l in out.splitlines() if l.strip()]


PATH_IN_BACKTICKS = re.compile(
    r"`([a-zA-Z0-9_./\-]+\.(?:ts|tsx|js|jsx|py|md|yaml|yml|json|css|html|sh))`"
)


def _scope_paths_from_contract(contract_path: Path) -> set[str]:
    if not contract_path.is_file():
        return set()
    text = contract_path.read_text(encoding="utf-8")
    return {m.group(1) for m in PATH_IN_BACKTICKS.finditer(text)}


def _detect_admissions(commits: list[tuple[str, str]]) -> list[tuple[str, str, str]]:
    """Return [(sha, phrase, snippet), ...] matches."""
    hits: list[tuple[str, str, str]] = []
    for sha, msg in commits:
        low = msg.lower()
        for phrase in ADMISSION_PHRASES:
            idx = low.find(phrase)
            if idx >= 0:
                snippet = msg[max(0, idx - 20): idx + len(phrase) + 40].replace("\n", " ")
                hits.append((sha, phrase, snippet))
                break  # one hit per commit is enough
    return hits


def _detect_scope_violations(changed: list[str], scope: set[str]) -> list[str]:
    if not scope:
        return []
    return sorted(set(changed) - scope)


def main() -> int:
    parser = base_argparser("drift_guard.py")
    parser.add_argument("--base", required=True,
                        help="Base ref to diff/log against (e.g. main, origin/main)")
    parser.add_argument("--repo", default=".",
                        help="Path to the git repo to scan (default: cwd)")
    parser.add_argument("--check-scope", action="store_true",
                        help="Also warn on files changed outside Contract's named paths")
    args = parser.parse_args()

    sprint_dir = resolve_sprint_dir(args.sprint_dir)
    repo = Path(args.repo).resolve()

    commits = _git_log_since(args.base, repo)
    admissions = _detect_admissions(commits)

    scope_violations: list[str] = []
    if args.check_scope:
        contract = sprint_dir / "contracts" / f"group-{args.group}.md"
        scope = _scope_paths_from_contract(contract)
        if scope:
            changed = _git_changed_files(args.base, repo)
            scope_violations = _detect_scope_violations(changed, scope)

    payload: dict = {
        "base": args.base,
        "repo": str(repo),
        "commits_scanned": len(commits),
        "admissions": [
            {"sha": sha, "phrase": phrase, "snippet": snippet}
            for sha, phrase, snippet in admissions
        ],
        "scope_violations": scope_violations,
    }

    if admissions:
        verdict = "block"
        summary = (
            f"{len(admissions)} admission phrase(s) in commit messages: "
            + ", ".join(sorted({h[1] for h in admissions}))
        )
    elif scope_violations:
        verdict = "block" if args.strict else "warn"
        summary = f"{len(scope_violations)} file(s) changed outside Contract scope"
    else:
        verdict = "pass"
        summary = f"{len(commits)} commit(s), no admission phrases"

    return emit_and_exit("drift", verdict, sprint_dir, args.group, payload,
                         message=summary)


if __name__ == "__main__":
    sys.exit(main())
