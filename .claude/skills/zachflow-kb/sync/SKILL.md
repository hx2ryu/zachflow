---
name: zachflow-kb:sync
description: Sync the local KB with its source. In embedded mode (default), this is a no-op since the KB lives in the project repo. In remote mode (v1.x roadmap), it pulls from the configured remote. Invoke at the start of every sprint phase before reading or writing KB content (cheap if no-op).
---

# zachflow-kb:sync

## Behavior by mode

zachflow KB has two modes:

- **Embedded** (default, v1.0): KB lives at `<git-root>/.zachflow/kb/`. No remote, no fetch — `sync` is a no-op. The skill simply confirms the KB exists and reports embedded mode.
- **Remote** (v1.1+ roadmap): when `KB_PATH` env var points to a separate clone of an external KB git repo, `sync` runs `git fetch && git pull --ff-only`.

## Steps

1. **Resolve KB_PATH** (standard prologue)

   ```bash
   KB_PATH="${KB_PATH:-$(git rev-parse --show-toplevel 2>/dev/null)/.zachflow/kb}"
   if [ -z "${KB_PATH##*/}" ] || [ ! -d "$KB_PATH" ]; then
     echo "Error: zachflow KB not found at $KB_PATH" >&2
     exit 1
   fi
   ```

2. **Detect mode**
   - If `${KB_PATH}/.git` exists → potentially a separate KB repo (remote mode candidate).
   - Otherwise → embedded mode (KB is part of the parent project's repo).

3. **Embedded mode** — print status and exit:

   ```
   echo "zachflow KB: embedded mode at $KB_PATH — nothing to sync."
   exit 0
   ```

4. **Remote mode** (v1.1+ — currently a stub):

   In v1.0 the remote branch is a stub. If `${KB_PATH}/.git` exists AND the user has explicitly opted in to remote mode (env var `ZACHFLOW_KB_MODE=remote`), the skill performs a fetch + fast-forward pull. If the env var is NOT set, the skill assumes embedded mode and reports "no-op".

   ```bash
   if [ -d "${KB_PATH}/.git" ] && [ "${ZACHFLOW_KB_MODE:-embedded}" = "remote" ]; then
     cd "$KB_PATH"
     git checkout main 2>/dev/null || true
     git pull --ff-only || { echo "Warning: KB pull failed; using cached state" >&2; exit 0; }
     git rev-parse --short HEAD
   fi
   ```

   Full remote-mode workflow (clone, push, conflict handling) is the v1.1 roadmap.

## Failure handling
- KB not found → abort with bootstrap instructions.
- Network failure (remote mode) → log warning, continue with cached state. Reads remain valid.

## Verification (smoke)
- Embedded mode: skill outputs `zachflow KB: embedded mode at ... — nothing to sync.` and exits 0.
- Remote mode: skipped in v1.0.
