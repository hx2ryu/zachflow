# zachflow demo source

A throwaway sample repo for trying out zachflow without wiring up your own codebase.

`scripts/init-project.sh --demo` copies this directory to a temp location,
runs `git init`, and points a single backend role at it. You can then run
`/sprint demo-1` in Claude Code to walk through a full sprint pipeline
against this scratch project. Delete the temp directory when you're done —
zachflow prints its path at the end of the wizard.
