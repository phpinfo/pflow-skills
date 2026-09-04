# Common Go bugs — symptom → cause → check

## Nil and zero values

- `nil pointer dereference` on a method call → receiver is nil (constructor not called, struct field never assigned, typed-nil interface). Check `if x == nil` at the call site *and* find who produced it.
- `assignment to entry in nil map` → `var m map[K]V` without `make`; nested map inner level not initialized; struct zero value used instead of constructor.
- Interface holding a typed nil: `var p *T; var i I = p; i != nil` is **true**. Functions returning `(*MyErr)(nil)` as `error` produce "error != nil but nothing wrong". Return literal `nil`.
- JSON into `*T` with `null` leaves the pointer nil; `omitempty` on a struct field never omits (use pointer or `omitzero` 1.24).
- Zero `time.Time` is year 1, not "unset"; check `t.IsZero()`.

## Slices and indexing

- `index out of range [n] with length n` → off-by-one; `len` vs `cap` confusion; `make([]T, n)` then `append` (length already n).
- Modified data you didn't touch → aliasing via `append` on a sub-slice or shared backing array; a function received a slice and appended. Fix: `slices.Clone` or full slice expression `s[a:b:b]`.
- Loop over a slice while appending to it → infinite/unexpected iterations (range evaluates once — appends aren't visited, but deletes shift).
- `copy(dst, src)` copied fewer elements → `dst` too short.
- `range` gives a copy of each element: `for _, v := range items { v.X = 1 }` changes nothing. Use index or pointers.
- `s = s[:0]` reuse keeps old elements alive (memory) and can leak into other slices.

## Strings and encoding

- `len(s)` ≠ character count; slicing by byte index breaks UTF-8; `s[i]` is a byte. Use `[]rune`, `utf8`, `strings.Builder`.
- `strings.Split("", ",")` returns `[""]` (len 1). `strings.Fields` for whitespace.
- JSON: unexported fields silently ignored; tag typo (`json:"userId"` vs `user_id`); numbers into `interface{}` become `float64`; large ints lose precision → `json.Number`/`UseNumber`.
- `%v` of a `[]byte` prints numbers; `%s` prints text. `%d` on a `time.Duration` prints nanoseconds — use `%v`/`.String()`.
- Trailing `\n` in input from `bufio.Reader.ReadString` — `strings.TrimSpace`.

## Errors

- Error ignored: `_ = f()`, `f()` as a statement (errcheck catches), `defer f.Close()` on a writer.
- `err` shadowed inside `if`/`:=` so the outer `err` is never set; the returned error is `nil` while a message was logged.
- `errors.Is` fails after `fmt.Errorf("%v")` (should be `%w`) or after converting to a string and back.
- `errors.As` with a non-pointer target → panic; target must be `*MyErr` (pointer to the type that implements `error`).
- Comparing errors with `==` after wrapping. Comparing `err.Error()` strings.
- `defer cancel()` missing → context leak (vet `lostcancel`).

## Control flow

- `defer` inside a loop → runs at function exit; file handles exhausted ("too many open files").
- `defer` evaluates arguments immediately: `defer fmt.Println(x)` prints the old `x`; `defer func() { … }()` captures by reference.
- `switch` without `fallthrough` never falls through (unlike C); `break` inside `select` in a `for` only exits the `select` — use labels.
- `for i := 0; i < len(s); i++ { s = append(s, …) }` — bound re-evaluated each iteration.
- Goroutine captures loop variable: fixed in Go 1.22+, but only if `go.mod` says `go 1.22` or newer.
- Integer division truncates; `int` overflow wraps silently; `time.Duration(n) * time.Second` when `n` is already a Duration → double scaling.
- `math.MaxInt64` comparisons with mixed types compile-fail or overflow; `uint` subtraction wraps (`len(a) - len(b)` with `uint`).

## Time

- `time.Now()` has a monotonic component; `==` on times fails, `Equal` works; JSON round-trip drops monotonic → `Equal` still true, `==` false.
- `time.Parse` layout is the reference time `2006-01-02 15:04:05` — `2006-13-02` is not a bug in the data.
- `time.Ticker` never stopped → leak. `time.After` in a `select` loop → timer garbage.
- `t.AddDate(0, 1, 0)` on Jan 31 → March 3. Use first-of-month arithmetic.
- Local vs UTC: DB stores UTC, tests run in developer TZ; force `time.UTC` or set `TZ=UTC` in tests.

## Files, processes, OS

- `os.Open` succeeds on a directory; `ReadFile` on it fails. `filepath.Join` vs `path.Join` on Windows. Relative paths depend on CWD (tests run in the package dir).
- Files not flushed/closed before reading back; `bufio.Writer` without `Flush`.
- `exec.Command("cmd", "a b")` passes one argument `"a b"`; env not inherited when `cmd.Env` is set (add `os.Environ()`).
- Signals: `signal.Notify` channel must be buffered (size ≥ 1).
- File permissions `0644` vs `0o644` — both fine; `644` (decimal) is wrong.

## Build-time surprises

- `//go:build` tag excluded the file you edited → "undefined: X". Check `go list -f '{{.GoFiles}}'`.
- Generated code stale after proto/schema change → run the generator, diff in CI.
- Method on value receiver doesn't mutate: `func (c Counter) Inc()`.
- Package initialization order / `init()` dependency on another package's state.
- Shadowed import (`url := …` then `url.Parse`), unused variables kept alive with `_ =`.

## Fast checks before deep dives

```bash
go vet ./...                                   # nil, printf, copylocks, lostcancel, unreachable
go test -race -count=1 -run 'TestX' ./pkg/...  # data races + fresh run
staticcheck ./... ; golangci-lint run ./...    # SA*, nilness, ineffassign, errcheck
go build -gcflags=-m ./pkg 2>&1 | grep escapes # unexpected heap escapes
GOFLAGS=-mod=mod go list -m all | grep dep     # which version is actually built
```
