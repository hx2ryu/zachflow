#!/usr/bin/env bash
# parse-config.sh — Shared helpers for reading sprint-config.yaml.
#
# Source this file (do not execute) and call:
#   parse_meta <config-path>   → prints two lines: sprint_id, branch_prefix
#   parse_repos <config-path>  → prints tab-separated rows: role\tsource\tbase\tmode
#
# Uses a minimal YAML-subset parser (no PyYAML dependency). Supports:
#   - scalar keys at root (sprint_id, branch_prefix, defaults.base)
#   - nested map under `repositories:` with per-role {source, base, mode}
# Values may be quoted ("..." or '...') or unquoted. ~ is expanded on source.

# This file must be sourced, not executed
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  echo "Error: ${BASH_SOURCE[0]} must be sourced, not executed directly." >&2
  exit 1
fi

_parse_config_py() {
  python3 - "$1" "$2" <<'PY'
import sys, os, re

path, mode = sys.argv[1], sys.argv[2]

with open(path) as f:
    raw = f.read()

def unquote(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in ("'", '"'):
        v = v[1:-1]
    return v

def indent_of(line):
    return len(line) - len(line.lstrip(" "))

# Strip comments (simple: # outside quotes). Keep # inside quoted strings alone.
def strip_comment(line):
    out = []
    in_s = None
    for ch in line:
        if in_s:
            out.append(ch)
            if ch == in_s:
                in_s = None
        else:
            if ch in ("'", '"'):
                in_s = ch
                out.append(ch)
            elif ch == "#":
                break
            else:
                out.append(ch)
    return "".join(out).rstrip()

lines = []
for raw_line in raw.splitlines():
    line = strip_comment(raw_line)
    if line.strip() == "":
        continue
    lines.append(line)

# Walk the tree. Track path of (indent, key).
stack = []  # list of (indent, key)
tree = {}   # nested dict

def set_path(keys, value):
    d = tree
    for k in keys[:-1]:
        d = d.setdefault(k, {})
    d[keys[-1]] = value

def ensure_path(keys):
    d = tree
    for k in keys:
        if k not in d or not isinstance(d[k], dict):
            d[k] = {}
        d = d[k]
    return d

for line in lines:
    ind = indent_of(line)
    content = line.strip()
    # Pop stack to current indent
    while stack and stack[-1][0] >= ind:
        stack.pop()

    m = re.match(r"^([A-Za-z0-9_\-]+)\s*:\s*(.*)$", content)
    if not m:
        continue
    key, rest = m.group(1), m.group(2)
    path_keys = [s[1] for s in stack] + [key]

    if rest == "":
        ensure_path(path_keys)
        stack.append((ind, key))
    else:
        set_path(path_keys, unquote(rest))

if mode == "meta":
    print(tree.get("sprint_id", ""))
    print(tree.get("branch_prefix", "sprint"))
elif mode == "repos":
    default_base = (tree.get("defaults") or {}).get("base", "main")
    repos = tree.get("repositories") or {}
    if not isinstance(repos, dict):
        sys.exit(0)
    for role, spec in repos.items():
        if not isinstance(spec, dict):
            continue
        source = os.path.expanduser(str(spec.get("source", "")))
        base = spec.get("base", default_base)
        mode_v = spec.get("mode", "worktree")
        print(f"{role}\t{source}\t{base}\t{mode_v}")
PY
}

parse_meta() {
  _parse_config_py "$1" "meta"
}

parse_repos() {
  _parse_config_py "$1" "repos"
}
