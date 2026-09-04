---
name: pflow-golang-troubleshoot
description: Systematic root-cause debugging for Go programs — panics, wrong results, failing or flaky tests, deadlocks, data races, goroutine leaks, memory or CPU blow-ups, build and module errors. Detects the project's toolchain, debug tools and test entry points, then guides the investigation with pprof, the race detector, delve and targeted tests. Use when Go code misbehaves and the cause is unknown. Not for writing new code (pflow-golang).
license: MIT
allowed-tools:
  - Bash(.agents/skills/pflow-golang-troubleshoot/scripts/troubleshoot-context.sh)
---

If `troubleshoot-context.sh` fails (non-zero exit or `"status":"error"` in its JSON) print `⚠️ <error.message>` and stop. Other failing commands are evidence — record and continue.

## Steps

1. Run `.agents/skills/pflow-golang-troubleshoot/scripts/troubleshoot-context.sh` → `{toolchain, goos, goarch, cgo_enabled, debug_tools[], task_runner, test_targets[], test_files, test_dirs[], test_build_tags, hint}`.
2. Read `references/methodology.md`, then the file for the symptom:

   | Symptom | Read |
   | --- | --- |
   | panic, wrong output, nil pointer, index out of range | `common-bugs.md` |
   | hangs, deadlock, race report, leak, "all goroutines are asleep" | `concurrency-debug.md` |
   | slow, high memory, high CPU, GC pressure | `pprof-delve.md` |
   | test fails, flaky, passes alone but fails together, coverage gaps | `testing-debug.md` |
   | does not compile, `go mod` / vet / lint errors | `build-errors.md` |

3. Reproduce first, with the narrowest command available: a `test_targets` entry from the project runner, else `go test -run 'TestX' -race -count=1 ./pkg/...`. Respect `test_build_tags` (e.g. `-tags e2e` needs its backend — ask before running).
4. Form one hypothesis at a time, prove it with evidence (log, test, profile, `dlv`), fix the root cause, add a regression test, rerun the reproduction and the project gate.
5. Report: symptom → root cause → fix → proof (test name / command output). Never report "fixed" without the reproduction passing.

Paths are relative to `.agents/skills/pflow-golang-troubleshoot/`.

## Gotchas

- `hint` non-null means `CGO_ENABLED=0`; `-race` may need `CGO_ENABLED=1 go test -race`.
- Missing `dlv`/`benchstat`/`govulncheck` in `debug_tools`: propose `go install …@latest` or `go run …@latest`; don't assume they exist.
- Don't change behavior to make a symptom disappear; if the fix widens beyond the cause, say so and stop for confirmation.
