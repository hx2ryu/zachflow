#!/usr/bin/env python3
"""Migrate Pattern schema v1 -> v2 in place.

v2 adds optional lifecycle fields used by the pattern curator:
    state, pinned, created_by, use_count, last_referenced_at

Existing v1 patterns are treated as already-vetted KB entries — they are
seeded with `state: stable` so they participate in archive-on-staleness
but never in the draft -> stable promotion path.

Idempotent: running on a v2 file is a no-op. Validates each migrated
file against schemas/learning/pattern.schema.json before writing.

Usage:
    python3 scripts/lib/migrate-pattern-v1-to-v2.py --kb-path PATH [--dry-run]

Exit:
    0  success (including no-op)
    1  validation failure or IO error
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import yaml
import jsonschema


def _load_schema(repo_root: Path) -> dict:
    schema_path = repo_root / "schemas" / "learning" / "pattern.schema.json"
    if not schema_path.exists():
        sys.exit(f"Error: schema missing at {schema_path}")
    return json.loads(schema_path.read_text(encoding="utf-8"))


def _migrate_one(data: dict) -> tuple[dict, bool]:
    """Return (migrated_data, changed)."""
    sv = data.get("schema_version")
    if sv == 2:
        return data, False
    if sv != 1:
        raise ValueError(f"unexpected schema_version: {sv!r}")
    data = dict(data)
    data["schema_version"] = 2
    data.setdefault("state", "stable")
    data.setdefault("pinned", False)
    data.setdefault("created_by", "agent")
    data.setdefault("use_count", 0)
    data.setdefault("last_referenced_at", None)
    return data, True


def main() -> int:
    parser = argparse.ArgumentParser(description="Migrate pattern v1 -> v2.")
    parser.add_argument("--kb-path", required=True, help="Path to .zachflow/kb")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print decisions without writing")
    args = parser.parse_args()

    kb = Path(args.kb_path).resolve()
    patterns_dir = kb / "learning" / "patterns"
    if not patterns_dir.is_dir():
        sys.exit(f"Error: {patterns_dir} not found")

    repo_root = Path(__file__).resolve().parents[2]
    schema = _load_schema(repo_root)

    migrated = 0
    skipped = 0
    errors = 0
    for path in sorted(patterns_dir.glob("*.yaml")):
        try:
            data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
            new_data, changed = _migrate_one(data)
            if not changed:
                skipped += 1
                continue
            jsonschema.validate(new_data, schema)
            if args.dry_run:
                print(f"would migrate: {path.name}")
            else:
                path.write_text(
                    yaml.safe_dump(new_data, sort_keys=False, default_flow_style=False),
                    encoding="utf-8",
                )
                print(f"migrated: {path.name}")
            migrated += 1
        except (ValueError, jsonschema.ValidationError) as e:
            errors += 1
            print(f"error: {path.name}: {e}", file=sys.stderr)

    print(f"\nSummary: migrated={migrated} skipped={skipped} errors={errors}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
