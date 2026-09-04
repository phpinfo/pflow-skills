# Testing

## Structure

- Tests live next to the code (`foo_test.go`, `package foo`); use `package foo_test` for black-box tests of the exported API and to avoid import cycles.
- Table-driven with named cases; run each as `t.Run(name, …)`. Case name is the readable description (`"empty input"`), not `case1`.
- `t.Parallel()` in the test and in each subtest when there's no shared mutable state, no `t.Setenv`, no `os.Chdir`. Package-level globals mutated by tests forbid it.
- Arrange / Act / Assert with a blank line between; one behavior per test. Assert on the full result (`cmp.Diff`, `assert.Equal` on structs), not on fields one by one.
- Fail messages: `got X, want Y` order, name the function and the input. `t.Errorf` to keep going; `t.Fatalf` only when continuing is meaningless (setup failed, nil pointer).
- Helpers call `t.Helper()` first and take `testing.TB`. Cleanup with `t.Cleanup`, not `defer` in helpers.
- Test the behavior and error semantics (`errors.Is`, type), not error strings. Don't test private functions when the public path covers them.
- Fixtures in `testdata/` (ignored by the toolchain); golden files updated via a `-update` flag. `t.TempDir()` for scratch files. `t.Setenv` for env vars (disables parallel).
- `t.Context()` (1.24) for a context canceled at test end. Fake time via an injected clock, or `testing/synctest` (1.25) for goroutine + timer scenarios.
- Test names: `TestClient_Get_notFound` or `TestParse/empty_input` — a failure line must locate the case.

## What to mock

- Mock only at real boundaries (network, DB, clock, filesystem, randomness) through small interfaces owned by the consumer. Don't mock your own domain types.
- Prefer hand-written fakes with recorded calls for tiny interfaces; generated mocks (mockery / gomock) when the interface is wide or shared. Never mock what you don't own without an adapter.
- `net/http/httptest.NewServer` for HTTP clients; `httptest.NewRecorder` for handlers. `sqlmock`/an in-memory store for repositories; a real DB (testcontainers, docker-compose) for integration tests.
- Keep integration and E2E tests behind a build tag (`//go:build e2e`) or `testing.Short()`, and run them in a separate CI job.

## Assertions

- Stdlib: `if got != want { t.Errorf(...) }`; `cmp.Diff(want, got)` for structs/slices (prints a readable diff; `cmpopts.IgnoreFields`, `EquateApproxTime`).
- testify when the project already uses it: `require` for preconditions and errors that make the rest meaningless, `assert` for the actual checks. See `lib-testify.md`.
- Floats: `InDelta`/tolerance. Time: `Equal`/`WithinDuration`. Errors: `ErrorIs`/`ErrorAs`, never string compare. JSON: unmarshal then compare, or `JSONEq`.

## Coverage, benchmarks, fuzz

- `go test -race -shuffle=on -count=1 ./...` locally and in CI; `-shuffle` catches order dependence, `-count=1` bypasses the cache.
- Coverage is a signal, not a target; gate only the packages where logic lives (`-coverpkg`, `-coverprofile`), skip `main` and generated code.
- Benchmarks: `func BenchmarkX(b *testing.B) { for b.Loop() { … } }` (1.24; `for i := 0; i < b.N; i++` before). `b.ReportAllocs()`. Compare with `benchstat old.txt new.txt` over `-count=10`.
- Fuzz parsers and decoders: `func FuzzParse(f *testing.F) { f.Add(seed); f.Fuzz(func(t *testing.T, in string) { … }) }`; keep the corpus in `testdata/fuzz`.
- `Example*` functions with `// Output:` comments double as docs and tests.
- Goroutine leaks: `goleak.VerifyNone(t)` (uber-go/goleak) in tests of code that starts goroutines.

## Flaky tests

- Never `time.Sleep` to wait; poll with `require.Eventually` / a loop with deadline, or use channels/synctest.
- No shared global state, no real network, no dependence on map order, wall clock, or locale. Seed randomness explicitly.
- A flaky test is a bug in the test or the code; don't `-count=3` it away.

## Layout of a table test

```go
func TestParse(t *testing.T) {
    t.Parallel()
    tests := []struct {
        name    string
        in      string
        want    Config
        wantErr error
    }{
        {name: "empty input", in: "", wantErr: ErrEmpty},
        {name: "single key", in: "a=1", want: Config{A: 1}},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            got, err := Parse(tt.in)
            if tt.wantErr != nil {
                if !errors.Is(err, tt.wantErr) { t.Fatalf("Parse(%q) error = %v, want %v", tt.in, err, tt.wantErr) }
                return
            }
            if err != nil { t.Fatalf("Parse(%q) unexpected error: %v", tt.in, err) }
            if diff := cmp.Diff(tt.want, got); diff != "" { t.Errorf("Parse(%q) mismatch (-want +got):\n%s", tt.in, diff) }
        })
    }
}
```
