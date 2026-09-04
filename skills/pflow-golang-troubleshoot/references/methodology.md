# Debugging methodology

## Loop

1. **Observe.** Capture the exact failure: full panic text with stack, test output with `-v`, the input, the environment (`toolchain`, `GOOS/GOARCH`, flags, env vars). Don't paraphrase error messages — read them; Go's are precise (`nil map`, `index out of range [3] with length 3`, `send on closed channel`).
2. **Reproduce.** Shrink to the smallest deterministic command: one test (`-run '^TestX$/case'`), `-count=1` (no cache), `-race`, `-shuffle=on -shuffle=SEED` to replay ordering. If it needs prod data, write a fixture from a redacted sample. A bug you can't reproduce is a bug you can't prove fixed.
3. **Localize.** Read the stack top-down: first frame in *your* module is the suspect. Bisect: `git bisect run go test -run TestX ./pkg` when it used to work. Add `t.Log`/`slog.Debug` with values, not "here". Delve for stateful bugs.
4. **Hypothesize.** State it in one sentence that predicts an observation ("if `cache.Get` returns a stale pointer, then logging the address on both sides will match"). Test that prediction before changing code.
5. **Fix the cause**, not the site: a nil check where the nil was dereferenced hides the reason the nil was produced.
6. **Prove.** Regression test fails before, passes after. Rerun with `-race -count=3`. Run the project gate.
7. **Widen.** Search for the same pattern elsewhere (`grep`, `gopls references`); fix siblings or file them.

## Reading a panic

```
panic: runtime error: invalid memory address or nil pointer dereference
[signal SIGSEGV: segmentation violation code=0x1 addr=0x0 pc=0x…]

goroutine 18 [running]:
github.com/acme/tool/internal/usecase.(*Service).Load(0xc0000a4000, {0x…, 0x…}, {0xc0000b2000, 0x4})
        /…/internal/usecase/load.go:42 +0x1e5
```

- Line 1 = kind. `addr=0x0` → nil receiver or nil field. `addr=0x18` → field at offset 0x18 of a nil struct pointer.
- First frame under your module path + line number is where to look; frames above are stdlib/deps that were *called* with bad input.
- `goroutine N [running]` — if N ≠ 1 the panic came from a goroutine you started; find its `go` statement lower in the trace (`created by`).
- `fatal error: …` (not `panic:`) = runtime-level (concurrent map writes, out of memory, all goroutines asleep). Not recoverable; see `concurrency-debug.md`.
- `GOTRACEBACK=all` prints every goroutine; `GOTRACEBACK=system` includes runtime frames.

## Instrumenting

- Temporary logs: `slog.Debug("load", "id", id, "len", len(items))` with `slog.SetLogLoggerLevel(slog.LevelDebug)`; `%#v` / `%+v` for structs; `spew`/`litter` only if already a dependency.
- `runtime/debug.PrintStack()` to learn who called you; `debug.Stack()` into an error.
- `testing.Verbose()` guards noisy test output. Remove instrumentation before the fix commit — or keep it as proper debug-level logging.
- Environment knobs worth trying: `GODEBUG=gctrace=1`, `GODEBUG=http2debug=2`, `GOFLAGS=-mod=mod`, `GOMAXPROCS=1` (surfaces scheduling assumptions), `GOGC=off` (rules the GC in/out).

## Common root-cause classes (check in this order)

1. Nil where a value was assumed (uninitialized map/field, typed nil in interface, error not checked).
2. Aliasing: shared slice backing array, map held by two owners, struct copied with a mutex/slice inside.
3. Concurrency: unsynchronized access, missing cancellation, closed channel, lock ordering.
4. Boundary values: empty input, one element, max size, negative, unicode, timezone/DST, leap day, month rollover.
5. Environment: different `GOOS`, file permissions, `PATH`, locale, env var unset in CI, cached test results, stale generated code.
6. Dependencies: version bump changed behavior (`go mod graph`, `git diff go.sum`), replaced module, cgo build differences.

## Stop conditions

- You changed code but can't explain *why* it fixes the issue → not done.
- The fix requires behavior changes the user didn't ask for → describe and ask.
- Flaky reproduction → treat as a concurrency or environment bug; don't retry-loop it away.
