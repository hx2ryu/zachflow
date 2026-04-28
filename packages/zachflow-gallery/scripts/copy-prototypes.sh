#!/usr/bin/env bash
# copy-prototypes.sh — copy runs/sprint/**/prototypes/*.html into Astro public/.
#
# Runs as part of `npm run build` (gallery package). The destination
# (public/prototypes/) is gitignored — generated each build.

set -euo pipefail

GALLERY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="$(cd "$GALLERY_ROOT/../.." && pwd)"

RUNS_DIR="$PROJECT_ROOT/runs/sprint"
DEST_DIR="$GALLERY_ROOT/public/prototypes"

# Always start clean — stale copies confuse the build.
rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

if [ ! -d "$RUNS_DIR" ]; then
  echo "copy-prototypes: no runs/sprint/ directory at $RUNS_DIR; nothing to copy."
  exit 0
fi

count=0
for run_dir in "$RUNS_DIR"/*/; do
  [ -d "$run_dir" ] || continue
  run_name=$(basename "$run_dir")
  proto_dir="${run_dir}prototypes"
  [ -d "$proto_dir" ] || continue

  while IFS= read -r -d '' html_file; do
    rel_path="${html_file#$proto_dir/}"
    dest="$DEST_DIR/$run_name/$rel_path"
    mkdir -p "$(dirname "$dest")"
    cp "$html_file" "$dest"
    count=$((count + 1))
  done < <(find "$proto_dir" -type f -name '*.html' -print0)
done

echo "copy-prototypes: copied $count file(s) to $DEST_DIR."
