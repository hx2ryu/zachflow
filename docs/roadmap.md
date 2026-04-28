# Roadmap

## v1.0 (current — Sprints 0–4)

- [x] Sprint 0 — Bootstrap: clean repo + sanitized core
- [x] Sprint 1 — KB embedded mode + skill rename (`zzem-kb:*` → `zachflow-kb:*`)
- [ ] Sprint 2 — Workflow split: `workflows/{sprint,qa-fix,_shared}/` + `/qa-fix` first-class
- [ ] Sprint 3 — Stack adapter: placeholder templates + `init-project.sh` wizard
- [x] Sprint 4a — `plugins/<name>/` pattern + `plugins/recall/` ported + `docs/plugin-authoring.md`
- [x] Sprint 4b — `zachflow-gallery` package
- [ ] Sprint 4c — `create-zachflow` npm wrapper + LICENSE/CI/v1.0 release

**Ship gate:** Empty zachflow repo can bootstrap a working sprint runner on Claude Code, verified end-to-end. v1.0 also ships with one reference plugin (`recall:ask`) demonstrating the plugin authoring pattern.

## v1.x (post v1.0)

- KB embedded → remote migration wizard
- External stack adapter examples (community PRs)
- Multi-LLM platform support (informed by `zzem-orchestrator` Codex experimentation — see [`llm-platform-coupling.md`](llm-platform-coupling.md))
- Official docs site
- Sprint Gallery content system generalization
- Additional plugins (Notion sync, Slack notifications, etc.) following the `plugins/recall/` reference pattern
- KB validation hardening — adopt JSONSchema config validation pattern from recall plugin
- KB unit test expansion — adopt shell-based `test_*.sh` pattern from recall plugin

## v2.0 (deferred)

- Workflow yaml DSL / plugin lifecycle hooks
- Plugin system for KB backends (sqlite, cloud)
- Multi-language teammate templates (stack pack catalog)
