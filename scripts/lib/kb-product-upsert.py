#!/usr/bin/env python3
"""Create or update OKF-compatible product KB Markdown docs."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import jsonschema
import yaml


TYPE_TO_DIR = {
    "feature": "features",
    "api": "apis",
    "decision": "decisions",
    "policy": "policies",
    "glossary": "glossary",
    "prd": "prds",
}


def fail(message: str) -> None:
    print(f"Error: {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_args(argv: list[str]) -> dict[str, str]:
    args: dict[str, str] = {}
    for arg in argv:
        if arg in {"-h", "--help"}:
            print(
                "Usage: python3 scripts/lib/kb-product-upsert.py "
                "type=<feature|api|decision|policy|glossary|prd> "
                "product=<slug> slug=<slug> title=<title> "
                "source_sprint=<sprint> source_files=<path[,path...]> "
                "[status=active] [confidence=inferred] [tags=a,b] "
                "[updated_at=ISO8601] [summary=text]"
            )
            raise SystemExit(0)
        if "=" not in arg:
            fail(f"arguments must use key=value form: {arg}")
        key, value = arg.split("=", 1)
        if not key:
            fail(f"empty argument key: {arg}")
        args[key] = value
    return args


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
    kb_path.mkdir(parents=True, exist_ok=True)
    (kb_path / "products").mkdir(parents=True, exist_ok=True)
    return kb_path


def script_repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def slug(value: str, field: str) -> str:
    if not value:
        fail(f"{field} is required")
    import re

    if not re.match(r"^[a-z0-9][a-z0-9-]*$", value):
        fail(f"{field} must be a lowercase slug: {value}")
    return value


def split_csv(value: str | None, field: str, required: bool = False) -> list[str]:
    if value is None:
        if required:
            fail(f"{field} is required")
        return []
    items = [item.strip() for item in value.split(",") if item.strip()]
    if required and not items:
        fail(f"{field} must contain at least one value")
    return items


def now_utc() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def read_frontmatter(path: Path) -> dict[str, Any] | None:
    try:
        content = path.read_text(encoding="utf-8")
    except Exception:
        return None
    if not content.startswith("---"):
        return None
    end = content.find("---", 3)
    if end < 0:
        return None
    try:
        data = yaml.safe_load(content[3:end])
    except Exception:
        return None
    return data if isinstance(data, dict) else None


def find_existing_path(products_dir: Path, resource: str) -> Path | None:
    for path in products_dir.rglob("*.md"):
        if path == products_dir / "README.md":
            continue
        fm = read_frontmatter(path)
        if fm and fm.get("resource") == resource:
            return path
    return None


def load_schema() -> dict[str, Any]:
    schema_path = script_repo_root() / "schemas" / "products" / "product-doc.schema.json"
    with schema_path.open(encoding="utf-8") as fp:
        return json.load(fp)


def validate_frontmatter(frontmatter: dict[str, Any]) -> None:
    schema = load_schema()
    try:
        jsonschema.validate(frontmatter, schema)
    except jsonschema.ValidationError as exc:
        fail(f"frontmatter schema validation failed: {exc.message}")


def resource_from_args(args: dict[str, str]) -> tuple[str, str, str]:
    doc_type = args.get("type", "")
    if doc_type not in TYPE_TO_DIR:
        fail(f"type must be one of {', '.join(sorted(TYPE_TO_DIR))}")
    product = slug(args.get("product", ""), "product")
    doc_slug = slug(args.get("slug", ""), "slug")
    resource = args.get("resource") or f"products/{product}/{TYPE_TO_DIR[doc_type]}/{doc_slug}"
    return product, doc_slug, resource


def frontmatter_from_args(args: dict[str, str], resource: str) -> dict[str, Any]:
    title = args.get("title", "").strip()
    if not title:
        fail("title is required")

    source_sprint = args.get("source_sprint", "").strip()
    if not source_sprint:
        fail("source_sprint is required")

    source_files = split_csv(args.get("source_files"), "source_files", required=True)
    tags = split_csv(args.get("tags"), "tags")
    related_resources = split_csv(args.get("related_resources"), "related_resources")

    frontmatter: dict[str, Any] = {
        "schema_version": 1,
        "type": args["type"],
        "title": title,
        "resource": resource,
        "status": args.get("status", "active"),
        "updated_at": args.get("updated_at", now_utc()),
        "confidence": args.get("confidence", "inferred"),
        "source_sprint": source_sprint,
        "source_files": source_files,
    }
    if tags:
        frontmatter["tags"] = tags
    if related_resources:
        frontmatter["related_resources"] = related_resources
    if args.get("superseded_by"):
        frontmatter["superseded_by"] = args["superseded_by"]
    if frontmatter["status"] == "superseded" and "superseded_by" not in frontmatter:
        fail("superseded docs require superseded_by")
    validate_frontmatter(frontmatter)
    return frontmatter


def markdown_body(title: str, summary: str) -> str:
    summary = summary.strip()
    if not summary:
        fail("summary is required")
    return f"# {title}\n\n{summary}\n"


def write_doc(path: Path, frontmatter: dict[str, Any], body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fm = yaml.safe_dump(
        frontmatter,
        sort_keys=False,
        allow_unicode=False,
        default_flow_style=False,
    )
    path.write_text(f"---\n{fm}---\n\n{body}", encoding="utf-8")


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    product, doc_slug, resource = resource_from_args(args)
    frontmatter = frontmatter_from_args(args, resource)
    body = markdown_body(frontmatter["title"], args.get("summary", ""))
    kb_path = resolve_kb_path()
    products_dir = kb_path / "products"
    existing_path = find_existing_path(products_dir, resource)
    target_path = existing_path or products_dir / product / TYPE_TO_DIR[args["type"]] / f"{doc_slug}.md"
    write_doc(target_path, frontmatter, body)
    print(target_path.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
