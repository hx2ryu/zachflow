# recall:ask smoke scenarios

Run these manually after install. Verify each behaves as described in the spec
(`docs/superpowers/specs/2026-04-28-recall-ask-design.md`).

## Pre-req

```bash
bash plugins/recall/scripts/install.sh
# Restart Claude Code session.
# Ensure CWD is the zachflow repo root so .recall.yaml is picked up.
rm -f ~/.recall/session.yaml
```

## Scenarios

### 1. Explicit sprint-id

```
/recall:ask how was the unblock toast handled in qa-2?
```

Expected: Stage 1 short-circuits (Track A finds `qa-2` substring → maps to a sprint id like `<example-sprint>-qa-2`). Stage 2 reads PRD/retrospective/evaluations matching "unblock toast". Answer + **Sources** block shown.

### 2. Ambiguous query → candidate list

```
/recall:ask --reset
/recall:ask unblock toast
```

Expected: 2-3 candidates listed with one-line reasons. State file updated with `recent_candidates`. Skill stops, awaits user pick.

### 3. Continue session (sprint_focus retained)

After scenario 1:
```
/recall:ask also show me the related KB pattern for that decision
```

Expected: `sprint_focus` retained from state. KB `learning/reflections` + `learning/patterns` matched + read. Answer + Sources.

### 4. Idle timeout

```bash
# Manually set last_turn_at to 45min ago:
python3 -c "
import datetime, yaml, os
p = os.path.expanduser('~/.recall/session.yaml')
d = yaml.safe_load(open(p))
d['last_turn_at'] = (datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)-datetime.timedelta(minutes=45)).strftime('%Y-%m-%dT%H:%M:%SZ')
yaml.safe_dump(d, open(p, 'w'))
"
```
Then:
```
/recall:ask how did the nickname sort end up in sprint 003?
```

Expected: Skill detects idle, starts fresh. `sprint_focus` set to the matched sprint id via Stage 1.

### 5. No match

```
/recall:ask this topic definitely does not exist zzz
```

Expected: `No matches found. Show full sprint list?` followed by sprint dir list.

### 6. Status

```
/recall:ask --status
```

Expected: prints `started_at / turn_count / sprint_focus / topic_focus / last_sources count`. Or `No active session.` if reset.

### 7. Reset

```
/recall:ask --reset
```

Expected: `Session ended.` State file deleted. `/recall:ask --status` afterward → `No active session.`

## Pass criteria

All 7 scenarios behave as expected. Any deviation → file an issue with screenshot of the answer + state file contents.
