# Errors and defensive coding

## Creating errors

- Sentinels for conditions callers branch on: `var ErrNotFound = errors.New("user not found")`. Compare with `errors.Is`, never `==` after wrapping.
- Custom types when callers need data: `type ValidationError struct{ Field string }` with `Error() string`. Return pointer receivers consistently. Extract with `errors.As(err, &target)`; Go 1.26+: `errors.AsType[*ValidationError](err)`.
- `fmt.Errorf` for one-off messages. Message: lowercase, no trailing punctuation, no "error:"/"failed to" prefixes — the caller adds context.
- Never return `nil, nil`. Never use in-band values (`-1`, `""`) instead of an error or `(v, ok)`.

## Wrapping and handling

- Add context at each layer once, in the caller's vocabulary: `fmt.Errorf("load config %q: %w", path, err)`. Don't repeat what the callee already said.
- `%w` when the caller may inspect the cause; `%v` when you deliberately hide implementation details at an API boundary. Document which sentinels you re-expose.
- Handle an error exactly once: log **or** return, never both. Logging and re-returning double-reports.
- `errors.Join(errs...)` to aggregate independent failures (validation, cleanup). `errors.Is` sees through joins.
- Check `Close()` errors on writers (`defer` + named result, or explicit close before return). Read-only closes may be ignored with a comment.
- Don't check error strings. Compare with `errors.Is`/`As`; add a typed error if none exists.
- Return early; keep the success path unindented. A `switch` on `errors.Is` cases beats nested `if`.
- Convert at boundaries: domain errors → HTTP status / exit code / `connect.NewError` in the outermost layer only.

## Panics

- Panic only for programmer errors that cannot happen at runtime (invariant violation, `Must*` in package init of constants/regexes). Never for I/O, input, or network.
- Recover only at goroutine or request boundaries to convert to an error and keep the process alive; re-panic on `runtime.Error` you can't handle.
- Don't `recover` to hide bugs. Log the stack (`debug.Stack()`) when you do recover.

## Logging (log/slog)

- Structured, key-value: `slog.Error("save user", "id", id, "err", err)`. No `fmt.Sprintf` into the message.
- Log at the top of the stack where you stop propagating. Lower layers return errors, they don't log.
- Pass `context.Context` variants (`slog.ErrorContext`) so handlers can add trace IDs. Never log secrets, tokens, full request bodies.

## Nil safety

- Check the interface value, not the pointer inside: a typed nil pointer in an interface is non-nil. Return explicit `nil` for interfaces (`var e *MyErr; return e` is the classic bug).
- Methods on pointer receivers may be called on nil; make them safe (`if c == nil { return default }`) only when nil is a documented valid state.
- Maps: reading a nil map is fine, writing panics — always `make` or use a literal. Nested maps need the inner one initialized.
- Slices: `s[i]` panics on out-of-range; guard with `len`. `s[:0]` on nil is fine.
- Type assertions: always two-value `v, ok := x.(T)` unless a panic is intended and commented.
- Close a channel only from the single sender; closing twice or sending on closed panics. `nil` channel blocks forever — useful in `select` to disable a case.

## Value semantics traps

- `append` may alias the backing array: results of `a[:2]` and `append(a[:2], x)` overwrite `a[2]`. Copy (`slices.Clone`) at API boundaries when you return or store a slice you didn't create.
- Maps and slices are references: copy before mutating data received from callers or stored in structs shared across goroutines.
- Never compare floats with `==`; use a tolerance or `math.Abs(a-b) < eps`. Money and IDs are integers or `decimal`, never `float64`.
- Zero-value `sync.Mutex`, `bytes.Buffer`, `strings.Builder`, `sync.WaitGroup` are ready to use; never copy them after first use (`go vet` copylocks).
- `time.Time` comparisons via `Equal`, not `==` (monotonic clock, location).
- Loop variables are per-iteration since Go 1.22; before that, copy before capturing in goroutines/closures.
- `defer` in a loop runs at function end — wrap the body in a function or call `Close` explicitly.
- Integer overflow is silent; check before multiplying user-provided sizes. `int` width is platform-dependent; use sized types in wire formats.
