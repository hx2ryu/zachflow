# recall

Interactive recall over project artifacts. Ask Claude about past sprint work, decisions, and lessons from a fresh session — get answers in interview mode.

## What it does

`/recall:ask` enters a stateful interview mode. Successive `/recall:ask` calls within 30 minutes continue the same session — same sprint focus, accumulating context. Idle past 30 minutes or call `--reset` to start fresh.

It searches two sources:
1. **Sprint artifacts** — your sprint output tree (`PRD.md`, `retrospective/`, `evaluations/`, `contracts/`, `tasks/`)
2. **Knowledge base** (optional) — reflections and patterns

## Install

```bash
git clone <this-repo>
cd <this-repo>
bash plugins/recall/scripts/install.sh
```

This symlinks `~/.claude/skills/recall` to `plugins/recall`. Restart Claude Code.

## Configure

Create `.recall.yaml` (CWD or `~/`):

```yaml
sources:
  sprints:
    path: ./runs                     # required
  kb:
    path: ${KB_PATH:-./.zachflow/kb} # optional
    layout: zachflow-kb              # zachflow-kb | none
```

See `plugins/recall/config/recall.example.yaml` for the full schema.

## Usage

```
/recall:ask                   enter mode
/recall:ask <question>        ask immediately
/recall:ask --reset           end session
/recall:ask --status          show session metadata
```

Examples:
- `/recall:ask how did the unblock toast issue end up being resolved?`
- `/recall:ask which sprints touched feature X so far?`
- `/recall:ask --reset`

Every answer ends with a **Sources** block listing the files Claude read — so you can verify.

## Tests

```bash
bash plugins/recall/tests/test_session.sh
bash plugins/recall/tests/test_config.sh
```

## License

MIT (or whatever the parent repo uses).
