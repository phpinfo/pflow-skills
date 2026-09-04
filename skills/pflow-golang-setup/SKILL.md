---
name: pflow-golang-setup
description: Scaffolds or audits Go project infrastructure — directory layout, go.mod hygiene and tool pinning, golangci-lint v2 config, Taskfile or Makefile quality gate, GitHub Actions CI, .gitignore and repo hygiene. Detects what the project already has and fills the gaps. Use when starting a Go project, adding lint/CI/task runner, or reviewing project structure. Not for writing application code (pflow-golang) or debugging (pflow-golang-troubleshoot). Invoked manually.
license: MIT
allowed-tools:
  - Bash(.agents/skills/pflow-golang-setup/scripts/setup-context.sh)
---

On any failure (non-zero exit, or an `error` field / `"status":"error"` in the JSON) print `⚠️ <message>` and stop.

## Steps

1. Run `.agents/skills/pflow-golang-setup/scripts/setup-context.sh` → `{go_version, toolchain, golangci_config, golangci_config_version, task_runner, github_workflows[], remote_host, dirs[], main_packages, files_present[], go_tools, dependabot, renovate, missing[]}`.
2. Tell the user what exists and what `missing` lists. Ask which gaps to fill; never overwrite an existing file — propose a diff instead.
3. Read the reference for each chosen item and generate the files:

   | Item | Read |
   | --- | --- |
   | New project, directory structure, multiple binaries, monorepo | `layout.md` |
   | `go.mod`, `go` line, `tool` directives, versions, vendoring | `go-mod.md` |
   | `.golangci.yml` (v2), formatters, `nolint` policy | `golangci.md` |
   | Taskfile / Makefile: build, test, lint, race, coverage, gate | `task-runner.md` |
   | CI workflow, caching, release, Dependabot/Renovate (when `remote_host` is `github`) | `ci-github-actions.md` |

4. Match the project's existing choices: same task runner, same Go version as `go_version`, same generator tools from `go_tools`. Every generated gate must run locally with one command (`task check` / `make check`) and identically in CI.
5. Finish by running the new gate once and reporting the result, or listing the exact command the user should run if it needs tools not installed.

Paths are relative to `.agents/skills/pflow-golang-setup/`.

## Gotchas

- `golangci_config_version` empty or `1` with a modern golangci-lint means a v1 config: propose `golangci-lint migrate`, don't rewrite by hand.
- Templates here are starting points; drop anything the project has no use for (a library needs no Dockerfile, a CLI needs no `api/`).
