#!/usr/bin/env python3
"""Regression guard — confirm KB rubric clauses fed into the Sprint Contract.

Runs at the boundary between Build Loop §4.1 (Contract draft) and §4.2
(Implement). The §9 (Cross-session knowledge) principle says rubric
clauses promoted from prior sprints must be **injected into the next
Sprint Contract** — otherwise hard-won lessons get re-learned.

Two checks (both heuristic, both WARN):

  A. Active rubric has clauses but Contract references none. The active
     rubric is the one with `status: active` under
     `<kb>/learning/rubrics/v{N}.md`; clauses appear as `### C1.`, `### C2.`,
     etc. in the body. The Contract should mention at least one `C\\d+`.

  B. Frozen Snapshot block missing. The `--- FROZEN SNAPSHOT ---` /
     `--- END SNAPSHOT ---` markers must surround the inlined KB +
     design data the Generator reads. No snapshot = ad-hoc context =
     drift risk.

Usage:
    python3 scripts/lib/guards/regression_guard.py \\
        --sprint-dir runs/sprint/<id> --group N \\
        [--kb-path PATH]

Exit:
    0  pass / warn
    1  --strict + warn
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _common import base_argparser, emit_and_exit, resolve_project_root, resolve_sprint_dir  # noqa: E402

import yaml  # noqa: E402

CLAUSE_HEADING = re.compile(r"^###\s+(C\d+)\.\s+", re.MULTILINE)
CLAUSE_REF = re.compile(r"\bC(\d+)\b")
SNAPSHOT_OPEN = "--- FROZEN SNAPSHOT ---"
SNAPSHOT_CLOSE = "--- END SNAPSHOT ---"


def _split_frontmatter(content: str) -> tuple[dict, str]:
    if not content.startswith("---"):
        return {}, content
    end = content.find("---", 3)
    if end < 0:
        return {}, content
    fm = yaml.safe_load(content[3:end]) or {}
    body = content[end + 3:].lstrip("\n")
    return fm, body


def _find_active_rubric(rubrics_dir: Path) -> tuple[Path | None, set[str]]:
    """Return (path_to_active_rubric, set_of_clause_ids_in_clauses_section)."""
    if not rubrics_dir.is_dir():
        return None, set()
    for p in sorted(rubrics_dir.glob("v*.md")):
        try:
            fm, body = _split_frontmatter(p.read_text(encoding="utf-8"))
        except Exception:
            continue
        if fm.get("status") == "active" and fm.get("superseded_by") is None:
            # Only count clauses in the ## Clauses section, not the Promotion Log.
            in_clauses = False
            clauses: set[str] = set()
            for line in body.splitlines():
                if line.startswith("## Clauses"):
                    in_clauses = True
                    continue
                if in_clauses and line.startswith("## "):
                    break
                if in_clauses:
                    m = CLAUSE_HEADING.match(line)
                    if m:
                        clauses.add(m.group(1))
            return p, clauses
    return None, set()


def main() -> int:
    parser = base_argparser("regression_guard.py")
    parser.add_argument("--kb-path", default=None,
                        help="Path to .zachflow/kb (default: <project>/.zachflow/kb)")
    args = parser.parse_args()

    sprint_dir = resolve_sprint_dir(args.sprint_dir)
    project = resolve_project_root(sprint_dir)
    kb = Path(args.kb_path).resolve() if args.kb_path else project / ".zachflow" / "kb"
    contract = sprint_dir / "contracts" / f"group-{args.group}.md"

    findings: list[str] = []
    payload: dict = {
        "contract_path": str(contract.relative_to(project)) if contract.is_relative_to(project) else str(contract),
        "kb_path": str(kb),
    }

    if not contract.is_file():
        findings.append(f"missing-contract: {contract.name} not found")
        return emit_and_exit(
            "regression", "block" if args.strict else "warn",
            sprint_dir, args.group, {**payload, "findings": findings},
            message=findings[0],
        )

    text = contract.read_text(encoding="utf-8")

    # --- A. Rubric injection ------------------------------------------------
    rubric_path, available_clauses = _find_active_rubric(kb / "learning" / "rubrics")
    contract_clause_refs = {f"C{m}" for m in CLAUSE_REF.findall(text)}
    payload["active_rubric"] = rubric_path.name if rubric_path else None
    payload["available_clauses"] = sorted(available_clauses)
    payload["contract_refs"] = sorted(contract_clause_refs)
    if available_clauses and not (contract_clause_refs & available_clauses):
        findings.append(
            f"rubric-not-injected: active rubric has {len(available_clauses)} clause(s) "
            f"({', '.join(sorted(available_clauses))}) but Contract references none"
        )

    # --- B. Frozen Snapshot ------------------------------------------------
    has_open = SNAPSHOT_OPEN in text
    has_close = SNAPSHOT_CLOSE in text
    payload["snapshot_open"] = has_open
    payload["snapshot_close"] = has_close
    if not (has_open and has_close):
        findings.append(
            "missing-snapshot: Contract is missing `--- FROZEN SNAPSHOT ---` "
            "/ `--- END SNAPSHOT ---` markers"
        )

    payload["findings"] = findings

    if not findings:
        verdict = "pass"
        summary = (
            f"rubric={rubric_path.name if rubric_path else 'none'}, "
            f"clauses referenced={len(contract_clause_refs & available_clauses)}, snapshot OK"
        )
    else:
        verdict = "block" if args.strict else "warn"
        summary = "; ".join(findings)

    return emit_and_exit("regression", verdict, sprint_dir, args.group,
                         payload, message=summary)


if __name__ == "__main__":
    sys.exit(main())
