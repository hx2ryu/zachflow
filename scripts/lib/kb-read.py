#!/usr/bin/env python3
"""Resolve zachflow KB query arguments to matching file paths.

This helper backs the zachflow-kb:read skill. It prints absolute paths only;
callers read file contents separately.
"""

from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml


PRODUCT_TYPE_TO_SCHEMA_TYPE = {
    "product": "product_index",
    "product_index": "product_index",
    "feature": "feature",
    "api": "api",
    "decision": "decision",
    "policy": "policy",
    "glossary": "glossary",
    "prd": "prd",
}

LEARNING_TYPES = {"pattern", "rubric", "reflection"}


def fail(message: str) -> None:
    print(f"Error: {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_args(argv: list[str]) -> dict[str, str]:
    filters: dict[str, str] = {}
    for arg in argv:
        if arg in {"-h", "--help"}:
            print(
                "Usage: python3 scripts/lib/kb-read.py "
                "type=<pattern|rubric|reflection|product|feature|api|decision|policy|glossary|prd> "
                "[filter=value ...]"
            )
            raise SystemExit(0)
        if "=" not in arg:
            fail(f"arguments must use key=value form: {arg}")
        key, value = arg.split("=", 1)
        if not key:
            fail(f"empty argument key: {arg}")
        filters[key] = value
    if "type" not in filters:
        fail("type is required")
    return filters


def repo_root() -> Path:
    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except Exception:
        fail("KB_PATH is not set and git root could not be resolved")
    return Path(out)


def resolve_kb_path() -> Path:
    raw = os.environ.get("KB_PATH")
    kb_path = Path(raw) if raw else repo_root() / ".zachflow" / "kb"
    if not kb_path.is_dir():
        fail(
            f"zachflow KB not found at {kb_path}. "
            "Run 'bash scripts/kb-bootstrap.sh' first, or set KB_PATH."
        )
    return kb_path


def read_yaml_file(path: Path) -> dict[str, Any] | None:
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except Exception as exc:
        print(f"Warning: skipping {path}: {exc}", file=sys.stderr)
        return None
    return data if isinstance(data, dict) else None


def read_frontmatter(path: Path) -> dict[str, Any] | None:
    try:
        content = path.read_text(encoding="utf-8")
    except Exception as exc:
        print(f"Warning: skipping {path}: {exc}", file=sys.stderr)
        return None
    if not content.startswith("---"):
        print(f"Warning: skipping {path}: no YAML frontmatter", file=sys.stderr)
        return None
    end = content.find("---", 3)
    if end < 0:
        print(f"Warning: skipping {path}: unterminated YAML frontmatter", file=sys.stderr)
        return None
    try:
        data = yaml.safe_load(content[3:end])
    except Exception as exc:
        print(f"Warning: skipping {path}: {exc}", file=sys.stderr)
        return None
    return data if isinstance(data, dict) else None


def as_int(value: str | None, default: int | None = None) -> int | None:
    if value is None:
        return default
    try:
        return int(value)
    except ValueError:
        fail(f"expected integer, got {value}")


def iso_timestamp(value: Any) -> float:
    if not isinstance(value, str) or not value:
        return 0.0
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return 0.0


def print_paths(paths: list[Path]) -> None:
    for path in paths:
        print(path.resolve())


def query_patterns(kb_path: Path, filters: dict[str, str]) -> list[Path]:
    pattern_dir = kb_path / "learning" / "patterns"
    if not pattern_dir.is_dir():
        return []
    min_frequency = as_int(filters.get("min_frequency"), 0) or 0
    matches: list[Path] = []
    for path in sorted(pattern_dir.glob("*.yaml")):
        data = read_yaml_file(path)
        if not data:
            continue
        if filters.get("category") and data.get("category") != filters["category"]:
            continue
        if filters.get("severity") and data.get("severity") != filters["severity"]:
            continue
        if int(data.get("frequency", 0)) < min_frequency:
            continue
        matches.append(path)
    return matches


def query_rubrics(kb_path: Path, filters: dict[str, str]) -> list[Path]:
    rubric_dir = kb_path / "learning" / "rubrics"
    if not rubric_dir.is_dir():
        return []
    status = filters.get("status", "active")
    records: list[tuple[int, Path]] = []
    for path in rubric_dir.glob("*.md"):
        data = read_frontmatter(path)
        if not data or data.get("status") != status:
            continue
        records.append((int(data.get("version", 0)), path))
    records.sort(key=lambda item: item[0], reverse=True)
    return [records[0][1]] if records else []


def query_reflections(kb_path: Path, filters: dict[str, str]) -> list[Path]:
    reflection_dir = kb_path / "learning" / "reflections"
    if not reflection_dir.is_dir():
        return []
    limit = as_int(filters.get("limit"), 3) or 3
    records: list[tuple[float, Path]] = []
    for path in reflection_dir.glob("*.md"):
        data = read_frontmatter(path)
        if not data:
            continue
        if filters.get("domain") and data.get("domain") != filters["domain"]:
            continue
        records.append((iso_timestamp(data.get("completed_at")), path))
    records.sort(key=lambda item: item[0], reverse=True)
    return [path for _, path in records[:limit]]


def product_slug(resource: Any) -> str | None:
    if not isinstance(resource, str):
        return None
    parts = resource.split("/")
    if len(parts) < 2 or parts[0] != "products":
        return None
    return parts[1]


def query_products(kb_path: Path, filters: dict[str, str]) -> list[Path]:
    products_dir = kb_path / "products"
    if not products_dir.is_dir():
        return []
    query_type = filters["type"]
    schema_type = PRODUCT_TYPE_TO_SCHEMA_TYPE[query_type]
    limit = as_int(filters.get("limit"), None)
    records: list[tuple[int, float, str, Path]] = []
    for path in products_dir.rglob("*.md"):
        if path == products_dir / "README.md":
            continue
        data = read_frontmatter(path)
        if not data:
            continue
        if data.get("type") != schema_type:
            continue
        if filters.get("product") and product_slug(data.get("resource")) != filters["product"]:
            continue
        if filters.get("status") and data.get("status") != filters["status"]:
            continue
        if filters.get("tag") and filters["tag"] not in (data.get("tags") or []):
            continue
        status_rank = 0 if data.get("status") == "active" else 1
        records.append((status_rank, -iso_timestamp(data.get("updated_at")), str(path), path))
    records.sort()
    paths = [path for _, _, _, path in records]
    return paths[:limit] if limit is not None else paths


def main(argv: list[str]) -> int:
    filters = parse_args(argv)
    query_type = filters["type"]
    supported_types = LEARNING_TYPES | set(PRODUCT_TYPE_TO_SCHEMA_TYPE)
    if query_type not in supported_types:
        fail(
            "unsupported type="
            f"{query_type}; expected one of {', '.join(sorted(supported_types))}"
        )
    kb_path = resolve_kb_path()
    if query_type == "pattern":
        paths = query_patterns(kb_path, filters)
    elif query_type == "rubric":
        paths = query_rubrics(kb_path, filters)
    elif query_type == "reflection":
        paths = query_reflections(kb_path, filters)
    else:
        paths = query_products(kb_path, filters)
    print_paths(paths)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
