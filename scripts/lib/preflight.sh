#!/usr/bin/env bash
# preflight.sh — verify init-project.sh prerequisites before the wizard runs.
#
# Sourced (not exec'd) by scripts/init-project.sh. Reports every missing tool
# in one pass so the user can fix them all before retrying, rather than
# discovering them one at a time mid-wizard.
#
# Exit semantics when run directly (`bash scripts/lib/preflight.sh`):
#   0 — all required tools present
#   1 — at least one missing
#
# When sourced, callers should call `run_preflight` and check its return code.

set -u

# ─── Tool detection helpers ─────────────────────────────────────────

_preflight_have() { command -v "$1" >/dev/null 2>&1; }

_preflight_python_version_ok() {
  # Require 3.8+ (matches scripts/lib/*.py f-strings and pyyaml/jsonschema deps).
  python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' 2>/dev/null
}

_preflight_has_pyyaml() { python3 -c 'import yaml' >/dev/null 2>&1; }

_preflight_os() {
  case "$(uname -s 2>/dev/null)" in
    Darwin*)  echo "macos" ;;
    Linux*)   echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *)        echo "other" ;;
  esac
}

# ─── Per-tool install hints ─────────────────────────────────────────

_preflight_hint_python3() {
  case "$(_preflight_os)" in
    macos)   echo "  install: brew install python@3.11   (or download from python.org)" ;;
    linux)   echo "  install: sudo apt install python3   (Debian/Ubuntu) — distro-specific" ;;
    windows) echo "  install: https://www.python.org/downloads/windows/ (check 'Add to PATH')" ;;
    *)       echo "  install: https://www.python.org/downloads/" ;;
  esac
}

_preflight_hint_pyyaml() {
  echo "  install (pick one):"
  case "$(_preflight_os)" in
    macos)
      echo "    • pipx install pyyaml                          (recommended; isolated env)"
      echo "    • python3 -m pip install --user pyyaml         (often blocked on macOS 12+ by PEP 668;"
      echo "                                                    add --break-system-packages if so)"
      echo "    • brew install pyyaml                          (system-wide)"
      ;;
    linux)
      echo "    • sudo apt install python3-yaml                (Debian/Ubuntu)"
      echo "    • pipx install pyyaml                          (any distro)"
      echo "    • python3 -m pip install --user pyyaml"
      ;;
    *)
      echo "    • pipx install pyyaml"
      echo "    • python3 -m pip install --user pyyaml"
      ;;
  esac
}

_preflight_hint_git() {
  case "$(_preflight_os)" in
    macos)   echo "  install: brew install git   (or xcode-select --install)" ;;
    linux)   echo "  install: sudo apt install git   (distro-specific)" ;;
    windows) echo "  install: https://git-scm.com/download/win" ;;
    *)       echo "  install: https://git-scm.com/downloads" ;;
  esac
}

_preflight_hint_node() {
  echo "  install: https://nodejs.org/ (LTS) — only needed if you re-run create-zachflow"
}

# ─── Main check ─────────────────────────────────────────────────────

run_preflight() {
  # run_preflight [--quiet]
  # Returns 0 when all required tools are present, 1 otherwise.
  local quiet=0
  [ "${1:-}" = "--quiet" ] && quiet=1

  local missing=()
  local warnings=()

  # Required: git
  if ! _preflight_have git; then
    missing+=("git|$(_preflight_hint_git)")
  fi

  # Required: python3 (3.8+)
  if ! _preflight_have python3; then
    missing+=("python3|$(_preflight_hint_python3)")
  elif ! _preflight_python_version_ok; then
    local ver
    ver=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))' 2>/dev/null || echo "?")
    missing+=("python3 >= 3.8 (found $ver)|$(_preflight_hint_python3)")
  fi

  # Required: pyyaml (only check if python3 is present and version-okay)
  if _preflight_have python3 && _preflight_python_version_ok; then
    if ! _preflight_has_pyyaml; then
      missing+=("python3 module: yaml (pyyaml)|$(_preflight_hint_pyyaml)")
    fi
  fi

  # Optional warning: node 18+ (only matters for create-zachflow re-runs).
  if _preflight_have node; then
    local node_major
    node_major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo "0")
    if [ "$node_major" -lt 18 ] 2>/dev/null; then
      warnings+=("node $node_major.x detected — create-zachflow needs node 18+. The init wizard itself does not.|$(_preflight_hint_node)")
    fi
  fi

  # Optional warning: bash < 4 on Linux. Script is tested for bash 3.2 so this
  # is informational only.
  if [ -n "${BASH_VERSION:-}" ]; then
    local bash_major="${BASH_VERSION%%.*}"
    if [ "$(_preflight_os)" = "macos" ] && [ "$bash_major" -lt 4 ]; then
      :  # macOS ships bash 3.2 by design; we support it. Do not warn.
    elif [ "$bash_major" -lt 4 ]; then
      warnings+=("bash $BASH_VERSION detected (< 4.0). Supported but uncommon — file a bug if anything misbehaves.| ")
    fi
  fi

  # Report.
  if [ ${#missing[@]} -eq 0 ] && [ ${#warnings[@]} -eq 0 ]; then
    [ $quiet -eq 1 ] || echo "preflight: all prerequisites present"
    return 0
  fi

  if [ ${#warnings[@]} -gt 0 ]; then
    echo "preflight: warnings"
    for entry in "${warnings[@]}"; do
      local name="${entry%%|*}"
      local hint="${entry#*|}"
      echo "  ⚠ $name"
      [ -n "$hint" ] && echo "$hint"
    done
  fi

  if [ ${#missing[@]} -gt 0 ]; then
    echo "preflight: missing prerequisites" >&2
    for entry in "${missing[@]}"; do
      local name="${entry%%|*}"
      local hint="${entry#*|}"
      echo "  ✗ $name" >&2
      [ -n "$hint" ] && echo "$hint" >&2
    done
    echo >&2
    echo "Re-run scripts/init-project.sh after installing the missing items, or pass" >&2
    echo "  --skip-preflight to bypass this check at your own risk." >&2
    return 1
  fi

  # Warnings only — non-fatal.
  return 0
}

# ─── Direct-execution mode (`bash scripts/lib/preflight.sh`) ──────────

# Only run when executed directly, not when sourced.
if [ "${BASH_SOURCE[0]:-}" = "${0:-}" ]; then
  run_preflight
fi
