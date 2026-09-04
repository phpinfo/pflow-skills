---
name: pflow-golang
description: Idiomatic Go coding rules for writing, reviewing, or refactoring Go code — naming, errors, interfaces, concurrency, tests, modern stdlib — plus library idioms for urfave/cli, testify, mockery, samber/lo and connectrpc when the project uses them. Use whenever a task touches .go files, go.mod, or asks how to do something in Go. Not for debugging failures (pflow-golang-troubleshoot) or project scaffolding (pflow-golang-setup).
license: MIT
allowed-tools:
  - Bash(.agents/skills/pflow-golang/scripts/go-stack.sh)
---

On any failure (non-zero exit, or an `error` field / `"status":"error"` in the JSON) print `⚠️ <message>` and stop.

## Steps

1. Run `.agents/skills/pflow-golang/scripts/go-stack.sh` → `{go_version, toolchain, cli, rpc, testing[], other[], golangci_config, task_runner, lib_references[]}`.
2. Read the topic references that match the task (table below) and every file in `lib_references`. Skip the rest.
3. Write or review the code. Apply modern-Go rules only up to `go_version` from step 1; each rule in `modernize.md` names its minimum version.
4. Before finishing, run the project's own gate when `task_runner` has one (`task check`, `make lint`, …); otherwise `gofmt -l .`, `go vet ./...`, and `golangci-lint run ./...` when `golangci_config` is set.

| Task | Read |
| --- | --- |
| Any new or changed code | `style-naming.md`, `errors-safety.md` |
| Types, constructors, APIs | `structs-interfaces.md`, `patterns.md` |
| Goroutines, channels, ctx, timeouts | `concurrency-context.md` |
| Slices, maps, strings, allocations | `slices-maps.md`, `performance.md` (only when a hot path is named) |
| Tests, mocks, fixtures | `testing.md` |
| Old code, deprecations, upgrade | `modernize.md` |
| Input, files, crypto, secrets, exec | `security.md` |
| Code review | `style-naming.md`, `errors-safety.md`, `security.md`, then the task-specific files |

Paths are relative to this skill: `.agents/skills/pflow-golang/references/`.

## Iron rules

- Handle every error once: wrap with `%w` and context, or handle it — never both, never `_`.
- Accept interfaces, return structs. Define interfaces where they are consumed, keep them 1–3 methods.
- `context.Context` is the first parameter, never a struct field. Every goroutine has an owner that knows when it stops.
- Make the zero value useful; no `init()`, no package-level mutable state.
- Follow the project's conventions (AGENTS.md, existing packages) over these rules when they conflict — and say so.
- Prefer stdlib (`slices`, `maps`, `cmp`, `log/slog`, `errors`) over a dependency that does the same.
