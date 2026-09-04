# Trigger evals — which skill should fire

Run each prompt in a Go project with the three skills installed. Expected: the named skill is loaded (or none). Record misses and adjust descriptions.

| # | Prompt | Expected |
| --- | --- | --- |
| 1 | Add a `users list` command to the CLI that prints a table | pflow-golang (+ lib-urfave-cli) |
| 2 | Write tests for `internal/usecase/import.go` | pflow-golang (+ lib-testify, lib-mockery) |
| 3 | Review this PR diff for Go idioms | pflow-golang |
| 4 | Refactor `Load` to return typed errors instead of strings | pflow-golang |
| 5 | Make this loop concurrent with a limit of 8 workers | pflow-golang |
| 6 | Bump the module to Go 1.26 and modernize | pflow-golang |
| 7 | Why does this panic with nil pointer dereference? | pflow-golang-troubleshoot |
| 8 | `TestImport` passes alone but fails in `task test` | pflow-golang-troubleshoot |
| 9 | The service leaks memory after a few hours | pflow-golang-troubleshoot |
| 10 | `go build` says ambiguous import after upgrading a dep | pflow-golang-troubleshoot |
| 11 | Set up golangci-lint for this repo | pflow-golang-setup |
| 12 | Create a GitHub Actions workflow that runs the tests | pflow-golang-setup |
| 13 | Start a new Go CLI project with a good layout | pflow-golang-setup |
| 14 | Add a Taskfile with build/test/lint targets | pflow-golang-setup |
| 15 | Write a Python script to parse this CSV | none |
| 16 | Explain how Go's GC works | none (answer directly) |
| 17 | Commit these changes | pflow-commit, not a golang skill |
