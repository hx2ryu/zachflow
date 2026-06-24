#!/usr/bin/env python3
"""Import/export local OKF-compatible product KB bundles."""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path
from typing import Any

import jsonschema
import yaml


def repo_root() -> Path:
    return Path(__file__).resolve().parents[3]


def fail(message: str) -> None:
    print(f"Error: {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_frontmatter(path: Path) -> dict[str, Any]:
    content = path.read_text(encoding="utf-8")
    if not content.startswith("---"):
        fail(f"{path}: no YAML frontmatter")
    end = content.find("---", 3)
    if end < 0:
        fail(f"{path}: unterminated YAML frontmatter")
    data = yaml.safe_load(content[3:end])
    if not isinstance(data, dict):
        fail(f"{path}: frontmatter must be a mapping")
    return data


def load_schema(name: str) -> dict[str, Any]:
    with (repo_root() / "schemas" / "products" / name).open(encoding="utf-8") as fp:
        return json.load(fp)


def validate_bundle(bundle_dir: Path, product: str) -> None:
    if not bundle_dir.is_dir():
        fail(f"bundle directory not found: {bundle_dir}")
    if not (bundle_dir / "index.md").is_file():
        fail(f"{bundle_dir}: product bundle must include index.md")

    doc_schema = load_schema("product-doc.schema.json")
    index_schema = load_schema("product-index.schema.json")
    count = 0

    for path in bundle_dir.rglob("*.md"):
        if path.name == "README.md" and path.parent == bundle_dir:
            continue
        fm = parse_frontmatter(path)
        schema = index_schema if path.name == "index.md" and path.parent == bundle_dir else doc_schema
        try:
            jsonschema.validate(fm, schema)
        except jsonschema.ValidationError as exc:
            fail(f"{path}: {exc.message}")
        resource = fm.get("resource", "")
        if not isinstance(resource, str) or not resource.startswith(f"products/{product}"):
            fail(f"{path}: resource must start with products/{product}")
        count += 1

    if count == 0:
        fail(f"{bundle_dir}: no product markdown files found")


def copy_bundle(source: Path, target: Path, force: bool) -> None:
    if target.exists():
        if not force:
            fail(f"target already exists: {target}; rerun with --force to replace")
        shutil.rmtree(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(source, target)


def import_bundle(args: argparse.Namespace) -> None:
    source = Path(args.source).resolve()
    kb_path = Path(args.kb_path).resolve()
    target = kb_path / "products" / args.product
    validate_bundle(source, args.product)
    copy_bundle(source, target, args.force)
    validate_bundle(target, args.product)
    print(target)


def export_bundle(args: argparse.Namespace) -> None:
    kb_path = Path(args.kb_path).resolve()
    source = kb_path / "products" / args.product
    target = Path(args.destination).resolve() / args.product
    validate_bundle(source, args.product)
    copy_bundle(source, target, args.force)
    validate_bundle(target, args.product)
    print(target)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    import_parser = subparsers.add_parser("import", help="import local OKF bundle")
    import_parser.add_argument("--source", required=True)
    import_parser.add_argument("--product", required=True)
    import_parser.add_argument("--kb-path", default="./.zachflow/kb")
    import_parser.add_argument("--force", action="store_true")
    import_parser.set_defaults(func=import_bundle)

    export_parser = subparsers.add_parser("export", help="export local OKF bundle")
    export_parser.add_argument("--product", required=True)
    export_parser.add_argument("--destination", required=True)
    export_parser.add_argument("--kb-path", default="./.zachflow/kb")
    export_parser.add_argument("--force", action="store_true")
    export_parser.set_defaults(func=export_bundle)

    return parser


def main(argv: list[str]) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
