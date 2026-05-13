#!/usr/bin/env python3
"""Bump active Evaluator rubric v(N) -> v(N+1).

Consolidates accumulated Promotion Log entries into the new Clauses section.
Each row's `source_pattern` is looked up in
${KB_PATH}/learning/patterns/{pattern-id}.yaml and its `contract_clause` is
inlined verbatim into the new rubric. The old v(N) is marked
`status: superseded`, `superseded_by: N+1`.

Usage:
    python3 scripts/lib/bump-rubric.py --kb-path PATH [--force] [--changelog "..."]

Exit:
    0  bump applied OR nothing to promote (when not --force)
    1  error (missing pattern, dup active, validation fail, ...)
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import yaml
import jsonschema


def _split_frontmatter(content: str) -> tuple[dict, str]:
    if not content.startswith("---"):
        raise ValueError("no YAML frontmatter")
    end = content.find("---", 3)
    if end < 0:
        raise ValueError("unterminated frontmatter")
    fm = yaml.safe_load(content[3:end])
    body = content[end + 3 :].lstrip("\n")
    return fm or {}, body


def find_active_rubric(rubrics_dir: Path) -> tuple[Path, dict, str]:
    matches = []
    for p in sorted(rubrics_dir.glob("v*.md")):
        try:
            fm, body = _split_frontmatter(p.read_text(encoding="utf-8"))
        except ValueError:
            continue
        if fm.get("status") == "active" and fm.get("superseded_by") is None:
            matches.append((p, fm, body))
    if not matches:
        sys.exit("Error: no active rubric found in " + str(rubrics_dir))
    if len(matches) > 1:
        names = ", ".join(m[0].name for m in matches)
        sys.exit(f"Error: multiple active rubrics found: {names}")
    return matches[0]


def parse_promotion_log(body: str) -> list[tuple[str, str, str, str]]:
    """Return non-baseline Promotion Log rows as (date, sprint, clause_full, pattern_id)."""
    rows: list[tuple[str, str, str, str]] = []
    in_log = False
    for line in body.splitlines():
        if line.startswith("## Promotion Log"):
            in_log = True
            continue
        if in_log and line.startswith("## "):
            break
        if not in_log or not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 4:
            continue
        if cells[0].lower() == "date" or cells[0].startswith("--"):
            continue
        # Baseline row uses em-dashes in date/sprint and "(baseline)" in clause cell.
        if cells[0] == "—" and cells[2].lower().startswith("(baseline"):
            continue
        rows.append((cells[0], cells[1], cells[2], cells[3]))
    return rows


def extract_clauses_body(body: str) -> str:
    out: list[str] = []
    in_clauses = False
    for line in body.splitlines():
        if line.startswith("## Clauses"):
            in_clauses = True
            continue
        if in_clauses and line.startswith("## "):
            break
        if in_clauses:
            out.append(line)
    return "\n".join(out).strip()


def load_pattern_clause(patterns_dir: Path, pattern_id: str) -> tuple[str, str]:
    p = patterns_dir / f"{pattern_id}.yaml"
    if not p.exists():
        sys.exit(f"Error: pattern file missing: {p}")
    data = yaml.safe_load(p.read_text(encoding="utf-8")) or {}
    clause = data.get("contract_clause")
    if not clause or not clause.strip():
        sys.exit(f"Error: pattern {pattern_id} has no contract_clause")
    return data.get("title", pattern_id), clause.strip()


def build_clauses_section(existing: str, promoted, patterns_dir: Path) -> str:
    parts: list[str] = []
    if existing and "No clauses yet" not in existing:
        parts.append(existing)
    for date_, sprint, clause_full, pattern_id in promoted:
        m = re.match(r"^(\S+)\s+(.*)$", clause_full.strip())
        if m:
            clause_id, log_title = m.group(1), m.group(2).strip()
        else:
            clause_id, log_title = clause_full.strip(), ""
        ptitle, body = load_pattern_clause(patterns_dir, pattern_id)
        title = log_title or ptitle
        parts.append(
            f"### {clause_id}. {title}\n\n"
            f"{body}\n\n"
            f"> Promoted from `{pattern_id}` in sprint `{sprint}` ({date_})."
        )
    return "\n\n".join(parts) if parts else "(No clauses yet.)"


def build_new_rubric(new_version: int, changelog: str, clauses_body: str) -> str:
    fm = {
        "version": new_version,
        "status": "active",
        "superseded_by": None,
        "schema_version": 1,
        "changelog": changelog,
    }
    fm_yaml = yaml.safe_dump(fm, sort_keys=False, default_flow_style=False).strip()
    return (
        f"---\n{fm_yaml}\n---\n\n"
        f"# Evaluator Rubric v{new_version}\n\n"
        f"The active Evaluator rubric. New clauses are promoted from observed patterns\n"
        f"(see `zachflow-kb:promote-rubric`). Version bumps consolidate the Promotion\n"
        f"Log into the Clauses section — automated by `zachflow-kb:bump-rubric`.\n\n"
        f"## Clauses\n\n"
        f"{clauses_body}\n\n"
        f"## Promotion Log\n\n"
        f"| Date | Sprint | Clause Added | Source Pattern |\n"
        f"|------|--------|--------------|----------------|\n"
        f"| —    | —      | (baseline)   | —              |\n"
    )


def supersede(path: Path, new_version: int) -> None:
    content = path.read_text(encoding="utf-8")
    fm, body = _split_frontmatter(content)
    fm["status"] = "superseded"
    fm["superseded_by"] = new_version
    fm_yaml = yaml.safe_dump(fm, sort_keys=False, default_flow_style=False).strip()
    path.write_text(f"---\n{fm_yaml}\n---\n\n{body}", encoding="utf-8")


def validate_rubric(path: Path, schema_path: Path) -> None:
    content = path.read_text(encoding="utf-8")
    fm, _ = _split_frontmatter(content)
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    try:
        jsonschema.validate(fm, schema)
    except jsonschema.ValidationError as e:
        sys.exit(f"Error: {path} failed schema validation: {e.message}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Bump active rubric v(N) -> v(N+1).")
    parser.add_argument("--kb-path", required=True, help="Path to .zachflow/kb")
    parser.add_argument("--force", action="store_true",
                        help="Bump even if Promotion Log has < 2 non-baseline rows")
    parser.add_argument("--changelog", default=None,
                        help="Custom changelog for the new version frontmatter")
    args = parser.parse_args()

    kb = Path(args.kb_path).resolve()
    rubrics_dir = kb / "learning" / "rubrics"
    patterns_dir = kb / "learning" / "patterns"
    if not rubrics_dir.is_dir():
        sys.exit(f"Error: {rubrics_dir} not found")

    repo_root = Path(__file__).resolve().parents[2]
    schema_path = repo_root / "schemas" / "learning" / "rubric.schema.json"
    if not schema_path.exists():
        sys.exit(f"Error: schema missing at {schema_path}")

    active_path, fm, body = find_active_rubric(rubrics_dir)
    current_version = int(fm["version"])
    new_version = current_version + 1
    new_path = rubrics_dir / f"v{new_version}.md"
    if new_path.exists():
        sys.exit(f"Error: {new_path} already exists — cleanup needed before bump")

    promoted = parse_promotion_log(body)
    print(f"Active rubric: {active_path.name}")
    print(f"Promotion Log entries (non-baseline): {len(promoted)}")

    if not promoted and args.force:
        sys.exit("Error: --force given but Promotion Log is empty; nothing to consolidate")
    if len(promoted) < 2 and not args.force:
        print("Nothing to promote (< 2 entries). Use --force to bump anyway.")
        return 0

    existing_clauses = extract_clauses_body(body)
    new_clauses = build_clauses_section(existing_clauses, promoted, patterns_dir)
    changelog = args.changelog or (
        f"v{new_version} — promoted {len(promoted)} clause(s) from "
        f"v{current_version} Promotion Log."
    )
    new_path.write_text(build_new_rubric(new_version, changelog, new_clauses), encoding="utf-8")
    supersede(active_path, new_version)

    validate_rubric(new_path, schema_path)
    validate_rubric(active_path, schema_path)

    print(f"Wrote {new_path.name} with {len(promoted)} promoted clause(s).")
    print(f"Marked {active_path.name} as superseded_by={new_version}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
