---
name: recall:ask
description: Interactive recall over workflow run artifacts and knowledge-base. Use when the user wants to query past sprint / qa-fix work, decisions, or lessons from a fresh session ("recall how the unblock toast was handled in <example-sprint-id>", "show me every run that touched nickname sort"). Enters interview mode — successive `/recall:ask` calls within 30 minutes continue the same session.
---

# recall:ask

Interactive recall over workflow run artifacts + knowledge base. Enters a stateful interview mode the user can continue across multiple turns.

## Invocation

```
/recall:ask                   # enter mode, await question
/recall:ask <question>        # enter and run Stage 1 immediately
/recall:ask --reset           # end session (delete state file)
/recall:ask --status          # show active session metadata
```

## Inputs

- `<question>` (optional, free-text) — the user's natural-language question
- `--reset` — explicit session termination
- `--status` — read-only inspection of current session

## Preconditions

- A `.recall.yaml` config file is resolvable (env > CWD > home > example fallback). When invoked from the zachflow project root the repo-root `.recall.yaml` is auto-picked up.
- Helper scripts at `~/.claude/skills/recall/scripts/session.sh` and `~/.claude/skills/recall/scripts/load-config.sh` are sourceable.

## Entry Flow

When `/recall:ask` is invoked, follow exactly this sequence:

1. **Resolve config**

   Run via Bash:
   ```
   source ~/.claude/skills/recall/scripts/load-config.sh && load_config_path
   ```
   If output is empty, use built-in defaults: `sources.runs.path = ./runs`, `sources.runs.workflows = [sprint, qa-fix]`, no KB, `session.state_file = ~/.recall/session.yaml`. Otherwise Read the resolved YAML path and parse.

2. **Inspect session state**

   Run via Bash:
   ```
   source ~/.claude/skills/recall/scripts/session.sh && session_active && echo ACTIVE || echo INACTIVE
   ```

3. **Branch on flags**

   - `--reset`: run `session_reset`, reply `Session ended.`, stop.
   - `--status` and ACTIVE: read state via `session_read`, echo `started_at / turn_count / run_focus / topic_focus / last_sources count`. Stop.
   - `--status` and INACTIVE: reply `No active session.`, stop.

4. **Branch on session activity**

   - INACTIVE → start new session: write minimal state (`active: true`, `started_at: <now>`, `last_turn_at: <now>`, `turn_count: 0`).
   - ACTIVE → continue: read existing state into memory.

5. **Handle question presence**

   - No question text and entering mode: reply with greeting + recent run hint (list top 5 run dirs across configured workflows) + invitation to ask. Stop.
   - Question text present: proceed to Stage 1.

## State File Management

The state file at `~/.recall/session.yaml` is written **at the end of every turn that produced an answer**. Update fields:

- `last_turn_at` → current UTC timestamp
- `turn_count` → +1
- `run_focus` → set when user confirms a candidate (Stage 1) or implied by run-id in query. Stored as `<workflow>/<run-id>` (e.g., `sprint/example-sprint-001`).
- `topic_focus` → keep latest user-mentioned topic
- `last_sources` → list of file paths Read this turn
- `recent_candidates` → from Stage 1 if multiple candidates were shown

If the existing state file fails to parse (yaml error), call `session_backup_corrupt` and start a new session silently.

## Stage 1 — Discovery (cheap)

Run **two tracks in parallel** (separate Bash/Read calls in one assistant message). Track A may short-circuit; Track B always runs.

### Track A — Run focus

The set of run roots to scan is `${sources.runs.path}/<workflow>/` for each `workflow` in `${sources.runs.workflows}` — typically `runs/sprint/*` and `runs/qa-fix/*`.

1. **Explicit run-id in question?**

   Glob run dir names from each configured workflow root and check whether the question text contains any of them as substring.
   - Yes → set `run_focus = <workflow>/<matched id>`, skip to Stage 2.

2. **Existing run_focus in state?**

   - Yes, AND user did not say "another run" / "different sprint" / "different qa-fix" → keep, proceed to Stage 2.

3. **Otherwise — derive candidates**

   For each `<workflow>/<run-id>` under `${sources.runs.path}`:
   - Read `<run>/sprint-config.yaml` (or workflow-equivalent config file) if present (full file, small).
   - Read `<run>/retrospective/*.md` first 30 lines only (use `Read` with `limit: 30`).
   - Score by lexical/substring match between question keywords and (a) run-id, (b) config name/title, (c) retrospective heading text.

   Produce **top 3-5** candidates ranked by score.

4. **Multiple candidates?**

   If top score is not clearly higher than next, ask the user to confirm:

   ```
   Which of these should I look at first?
   1) <workflow>/<run-id-A> — <one-line reason>
   2) <workflow>/<run-id-B> — <one-line reason>
   3) <workflow>/<run-id-C> — <one-line reason>
   ```

   Persist `recent_candidates` to state. **Stop** — wait for the user's next `/recall:ask` turn.

5. **Single confident match** → set `run_focus`, proceed to Stage 2.

### Track B — KB matching (always runs)

If `sources.kb.path` is set (the resolved value of `${KB_PATH:-./.zachflow/kb}`):

1. Glob `${kb.path}/learning/reflections/*.md`.
2. Read frontmatter + first 20 lines of each. The `domain` field is a free string matching `^[a-z][a-z0-9-]*$` — there is no hardcoded enum. Lexical-match the question keywords against `domain`, title, and the first heading.
3. Glob `${kb.path}/learning/patterns/*.yaml`. Match against `name` / `tags` / `category`.
4. Pick top **K=3** of each. Stage 2 will full-read them.

Track B never blocks Track A's clarification — KB matches accompany the answer, they don't decide run focus.

## Stage 2 — Targeted retrieval (full)

For the confirmed `run_focus` (i.e., `${sources.runs.path}/<workflow>/<run-id>/`), full-Read these paths:

| Path | When to Read |
|---|---|
| `PRD.md` | Always (if exists) |
| `retrospective/*.md` | Always |
| `evaluations/*.md` | If question topic keyword appears in any filename or first 50 lines |
| `contracts/*.md` | If question touches API / data shape (keywords: API, contract, schema, type, response, payload) |
| `tasks/*.md` | If question is task-shaped ("which task", "what was done about X") |
| `prototypes/*` | Skip by default (large). Only if user explicitly asks for prototypes. |
| `logs/*` | Skip by default. Only on explicit ask. |
| `checkpoints/*` | Skip by default. Only on explicit ask. |

The `always_read` / `conditional_read` / `skip_by_default` lists in `sources.runs.artifact_layout` (when present in config) override this default mapping.

For KB Track B candidates from Stage 1: full-Read them (they were already filtered to top K).

After Reads, synthesize the answer.

**Important:** track every absolute file path you Read this turn — they go into `last_sources` and the user-facing **Sources** block.

## Output Format (per answer turn)

```
<answer body — natural language, short and direct. Cite files as file_path:line>

---
**Sources**
- <abs-path-1>
- <abs-path-2>

**Suggested follow-ups** (1-3, optional)
- "..."
```

- `Sources` is **always** shown — verification + hallucination guard.
- `follow-up` only when there's a natural next question.

## End-of-Turn

After replying with an answer, immediately update the state file via Bash:

```bash
source ~/.claude/skills/recall/scripts/session.sh
session_write "$(cat <<EOF
active: true
started_at: <existing-or-now>
last_turn_at: <now>
turn_count: <prev+1>
run_focus: <workflow>/<id-or-null>
topic_focus: <topic>
last_sources:
  - <path-1>
  - <path-2>
recent_candidates:
  - <id-or-empty>
EOF
)"
```

## Failure Modes

| Situation | Action |
|---|---|
| 0 run candidates after Track A | Reply: `Not found. Want me to list all available runs?` Show top-level dir list across configured workflows. |
| State file parse error | Run `session_backup_corrupt`, start fresh session silently. |
| Individual file Read fails (Stage 1 or 2) | Skip + log a one-liner; never abort. |
| KB path missing or `layout` not `zachflow-kb` | Skip Track B silently. |
| `sprint-config.yaml` (or workflow-equivalent) missing | Use dir name + retrospective only for that candidate. |
| `--status` with no active session | Reply: `No active session.` |
| Session stale (> 7 days) | `session_active` returns INACTIVE; Entry Flow starts a fresh session silently. |
| Legacy KB layout (e.g., `events.yaml`) | Print a one-line deprecation note and continue. |

## Out of Scope (v1)

- Application source code grep
- External issue-tracker lookup
- Git commit history search
- Semantic search (v1 is lexical/substring)
- Multi-run comparison answers
