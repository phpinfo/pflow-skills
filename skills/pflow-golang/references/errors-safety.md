# Errors and defensive coding

## Creating errors

- Sentinels for conditions callers branch on: `var ErrNotFound = errors.New("user not found")`. Compare with
  `errors.Is`, never `==` or error strings; add a typed error if none exists.
- Custom types when callers need data: `type ValidationError struct{ Field string }`, pointer receivers consistently.
  Extract with `errors.AsType[*ValidationError](err)` (Go 1.26+), else `errors.As`.
- Message text: lowercase, no trailing punctuation, no `error:`/`failed to`/`cannot` prefixes, no package prefix
  (`"user not found"`, not `"store: user not found"`) — the caller adds context.
- Never return `nil, nil`. Never use in-band values (`-1`, `""`) instead of an error or `(v, ok)`.

## Wrapping and handling

- Add context at each layer once, in the caller's vocabulary. Don't repeat what the callee already said. Template — what
  happened, then `key=value` pairs separated by `; `, then the cause last:
  ```go
  fmt.Errorf("load config: path=%q; env=%q: %w", path, env, err)
  ```
- Sentinel born here: the sentinel says what happened, details follow, an underlying cause goes last:
  ```go
  fmt.Errorf("%w: limit=%d; actual=%d", ErrTooManyJobs, limit, n)
  fmt.Errorf("%w: step=start; stderr=%q: %w", ErrProcessing, stderr, err)
  ```
  No operation text after a sentinel (`"%w: renew lease"` → `"renew lease: %w"`, or a `step=` key). Nothing after the
  last `%w`.
- Values only as `key=value`, never inside the phrase: `"result missing: preset=%q"`, not `"result %s is missing"`.
  Strings `%q` (shows empty values, escapes separators and newlines), numbers `%d`, `Stringer` types `%s`.
- Nested values use a path as the key: `a.field` (literal), `a[%d]` for slices, `a[%q]` for string map keys —
  `presets["thumb"].mode="crop2"`. When the value is hidden (secret, validation constraint) put the path in `field=`:
  `field=database.dsn_file; constraint=required`. Each layer adds its own segment: the caller `presets[%q]: %w`, the
  callee `mode=%q`.
- `%w` when the caller may inspect the cause; `%v` when you deliberately hide implementation details at an API boundary.
  Document which sentinels you re-expose.
- `errors.Join(errs...)` to aggregate independent failures (validation, cleanup). `errors.Is` sees through joins.
- Check `Close()` errors on writers (`defer` + named result, or explicit close before return). Read-only closes may be
  ignored with a comment.
- Convert at boundaries: domain errors → HTTP status / exit code / `connect.NewError` in the outermost layer only.

## Panics

- Panic only for programmer errors (invariant violation, `Must*` for constant regexes/templates at init). Never for
  I/O, input, or network.
- Recover only at goroutine or request boundaries: convert to an error, log `debug.Stack()`, re-panic on
  `runtime.Error` you can't handle. Never `recover` to hide bugs.

## Logging (log/slog)

- Structured, key-value: `slog.Error("save user", "id", id, "err", err)`. No `fmt.Sprintf` into the message.
- Log **or** return, never both: log once at the top of the stack where you stop propagating; lower layers return.
- Pass `context.Context` variants (`slog.ErrorContext`) so handlers can add trace IDs. Never log secrets, tokens, full
  request bodies.

## Nil safety

- Check the interface value, not the pointer inside: a typed nil pointer in an interface is non-nil. Return explicit
  `nil` for interfaces (`var e *MyErr; return e` is the classic bug).
- Methods on pointer receivers may be called on nil; make them safe (`if c == nil { return default }`) only when nil is
  a documented valid state.
- Close a channel only from the single sender; closing twice or sending on closed panics. `nil` channel blocks forever —
  useful in `select` to disable a case.

## Value traps

- Copy maps and slices before mutating data received from callers or shared across goroutines.
- Floats: never `==`, use a tolerance; money and IDs are integers or `decimal`. `time.Time`: `Equal`, not `==`.
- Never copy `sync.Mutex`, `sync.WaitGroup`, `bytes.Buffer`, `strings.Builder` after first use (zero values are ready).
- `defer` in a loop runs at function end — wrap the body in a function or close explicitly.
- Integer overflow is silent: check before multiplying user-provided sizes; sized ints in wire formats.
