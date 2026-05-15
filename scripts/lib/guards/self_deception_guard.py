#!/usr/bin/env python3
"""Self-deception guard — verify the Evaluator stayed independent and rigorous.

Runs after Build Loop §4.4 standard Evaluate completes. Three checks,
none of which is fully deterministic — all WARN (heuristic):

  A. Same-author check: the commits that produced `evaluations/group-N.md`
     should NOT share author identity with the implementation commits.
     If they do, the same agent both wrote and judged the code, which
     §1 (Planner-Generator-Evaluator separation) explicitly forbids.

  B. Evaluator-touched-source check: the Evaluator's commits must not
     modify any file outside `runs/<sprint-id>/evaluations/` and
     `runs/<sprint-id>/logs/`. Anything else is a read-only violation
     (§ agent-team.md Read-only Constraint).

  C. PASS-without-evidence check: when the verdict is PASS, the report
     should contain at least one `file:line` citation. A PASS with zero
     citations means the Evaluator did not perform Logic Tracing
     (§4 Active Evaluation).

Usage:
    python3 scripts/lib/guards/self_deception_guard.py \\
        --sprint-dir runs/sprint/<id> --group N \\
        [--repo PATH] [--source-dirs DIR ...]

Exit:
    0  pass / warn
    1  --strict + warn
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import base_argparser, emit_and_exit, resolve_sprint_dir  # noqa: E402

FILE_LINE_CITATION = re.compile(r"`?([a-zA-Z0-9_./\-]+\.(?:ts|tsx|js|jsx|py|md|yaml|yml|json|css|html|sh)):(\d+)`?")
VERDICT_LINE = re.compile(r"^\s*-?\s*(?:Verdict|Score)\s*:\s*(PASS|ISSUES|FAIL)", re.IGNORECASE | re.MULTILINE)


def _git_authors_for_path(repo: Path, path: str) -> list[str]:
    """Return distinct author emails who committed `path`."""
    try:
        out = subprocess.run(
            ["git", "-C", str(repo), "log", "--format=%ae", "--", path],
            capture_output=True, text=True, check=True, encoding="utf-8",
        ).stdout
    except subprocess.CalledProcessError:
        return []
    seen: list[str] = []
    for line in out.splitlines():
        line = line.strip()
        if line and line not in seen:
            seen.append(line)
    return seen


def _git_files_changed_by_author(repo: Path, author_email: str, since: str | None) -> list[str]:
    cmd = ["git", "-C", str(repo), "log", f"--author={author_email}",
           "--name-only", "--format="]
    if since:
        cmd.append(f"{since}..HEAD")
    try:
        out = subprocess.run(cmd, capture_output=True, text=True,
                             check=True, encoding="utf-8").stdout
    except subprocess.CalledProcessError:
        return []
    files = sorted({l.strip() for l in out.splitlines() if l.strip()})
    return files


def main() -> int:
    parser = base_argparser("self_deception_guard.py")
    parser.add_argument("--repo", default=".",
                        help="Path to the git repo containing runs/ (default: cwd)")
    parser.add_argument("--source-dirs", nargs="+", default=["backend", "app"],
                        help="Directories Evaluator must NOT modify (relative to repo)")
    args = parser.parse_args()

    sprint_dir = resolve_sprint_dir(args.sprint_dir)
    repo = Path(args.repo).resolve()
    eval_path_abs = sprint_dir / "evaluations" / f"group-{args.group}.md"
    # Path *relative to repo* is what `git log -- <path>` expects.
    try:
        eval_path_rel = str(eval_path_abs.resolve().relative_to(repo))
    except ValueError:
        sys.exit(f"Error: eval path {eval_path_abs} is not inside repo {repo}")

    findings: list[str] = []

    # --- A. Same-author -----------------------------------------------------
    eval_authors = _git_authors_for_path(repo, eval_path_rel)
    impl_authors: list[str] = []
    for sd in args.source_dirs:
        rel_dir = f"runs/{sprint_dir.name}/../../{sd}"  # symbolic — see below
        # Source dirs may live in sibling worktrees; we can't always git-log
        # them from the harness repo. Use the harness repo's source dirs if
        # they exist directly.
        impl_path_rel = sd
        if (repo / impl_path_rel).exists():
            impl_authors.extend(_git_authors_for_path(repo, impl_path_rel))
    shared = sorted(set(eval_authors) & set(impl_authors))
    if shared:
        findings.append(
            f"same-author: {len(shared)} email(s) wrote both eval and impl: " + ", ".join(shared)
        )

    # --- B. Evaluator-touched-source ---------------------------------------
    if eval_authors:
        for evaluator_email in eval_authors:
            touched = _git_files_changed_by_author(repo, evaluator_email, since=None)
            off_limits = []
            for f in touched:
                for sd in args.source_dirs:
                    if f.startswith(sd + "/") or f == sd:
                        off_limits.append(f)
                        break
            if off_limits:
                # Trim to first 5 examples to keep payload small
                head = off_limits[:5]
                findings.append(
                    f"evaluator-touched-source: {evaluator_email} modified "
                    f"{len(off_limits)} source file(s) "
                    + ", ".join(head) + (" ..." if len(off_limits) > 5 else "")
                )

    # --- C. PASS-without-evidence ------------------------------------------
    citations_count = 0
    verdict_text: str | None = None
    if eval_path_abs.is_file():
        text = eval_path_abs.read_text(encoding="utf-8")
        citations_count = len(FILE_LINE_CITATION.findall(text))
        m = VERDICT_LINE.search(text)
        if m:
            verdict_text = m.group(1).upper()
        if verdict_text == "PASS" and citations_count == 0:
            findings.append(
                "pass-without-evidence: verdict PASS but zero `file:line` citations in report"
            )
    else:
        findings.append(f"missing-report: {eval_path_rel} not found")

    payload = {
        "eval_path": eval_path_rel,
        "verdict_in_report": verdict_text,
        "citation_count": citations_count,
        "eval_authors": eval_authors,
        "findings": findings,
    }

    if not findings:
        verdict = "pass"
        summary = f"verdict={verdict_text}, citations={citations_count}, eval authors={len(eval_authors)}"
    else:
        verdict = "block" if args.strict else "warn"
        summary = f"{len(findings)} signal(s): " + " | ".join(findings)

    return emit_and_exit("self_deception", verdict, sprint_dir, args.group,
                         payload, message=summary)


if __name__ == "__main__":
    sys.exit(main())
