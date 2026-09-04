# Debugging tests

## Run exactly what you need

```bash
go test -count=1 -v -run '^TestParse$/^empty_input$' ./internal/parser/   # one subtest, no cache
go test -count=1 -race -shuffle=on ./...                                  # randomize order, print seed
go test -count=1 -shuffle=1712345678 ./pkg                                # replay a seed
go test -count=1 -failfast -timeout 60s ./...                             # stop at first failure, dump on hang
go test -count=1 -run TestX -tags e2e ./tests/e2e/                       # tagged tests (need their env)
go test -json ./... | gotestsum   # or `gotestsum --format testname` if installed
go vet ./... && go test -count=1 -cover -coverprofile=c.out ./... && go tool cover -html=c.out
```

- `-count=1` always while debugging: cached "ok" hides flakes. `-v` shows `t.Log` output and subtest names.
- Subtest names in `-run` are regexes joined with `/`; spaces become `_`.
- `-run` with `-bench` needs `-run '^$'` to skip tests.
- Prefer the project's runner target when it sets env/tags (`task test`, `make test-race`); read it to learn the exact flags.

## Failure patterns

| Symptom | Likely cause | Check |
| --- | --- | --- |
| Passes alone, fails in package run | shared global state, package-level var mutated, env var, CWD/file left behind, `t.Setenv` + `t.Parallel` | `-shuffle=on`, run pair of tests together, grep package-level `var` |
| Passes locally, fails in CI | TZ/locale, `CGO_ENABLED`, missing tool/binary, race detector on in CI, fewer CPUs (`-cpu 1`), slower machine → timing | `TZ=UTC GOMAXPROCS=1 go test -race -cpu 1` |
| Fails randomly | timing (`time.Sleep`, real clock), map iteration order, goroutine scheduling, unseeded assumptions, shared temp files | `-count=50 -race`, `-cpu=1,2,8`, replace sleeps with `Eventually`/synctest |
| Hangs | unbuffered channel without reader, missing `ctx` cancel, `wg` mismatch, blocked `httptest` handler | `-timeout 30s` → goroutine dump; `concurrency-debug.md` |
| `panic: test timed out` with no useful stack | many goroutines; find yours by module path in the dump | `GOTRACEBACK=all`, grep module path |
| Wrong `want` vs `got` in table tests | copy-paste case data, expected/actual swapped, comparing pointers | print with `%+v`/`cmp.Diff`, check assertion argument order |
| Mock says "unexpected call" / "expectations not met" | interface changed, call order/count changed, matcher too strict (`ctx` literal instead of `mock.Anything`) | read the mock's diff; regenerate mocks |
| `undefined: X` only in tests | `//go:build` tag, `_test` package importing unexported, file excluded by GOOS suffix | `go list -f '{{.TestGoFiles}} {{.XTestGoFiles}}' ./pkg` |
| Coverage ignores a package | no `_test.go` in it, `-coverpkg` not set, generated code counted | `-coverpkg=./...`, exclude `gen/` in coverage tooling |
| `httptest` test fails with connection refused | server closed before client, or client uses the real URL | use `srv.URL`, `defer srv.Close()` after all requests |
| Golden file mismatch after harmless change | nondeterministic ordering/timestamps in output | sort output, freeze clock, update goldens via `-update` flag |

## Techniques

- Make the failing case first in the table and run only it. Then binary-search the table if the interaction matters.
- `t.Log` everything you assert on; `t.Logf("%+v", got)`. `t.Skip` other cases temporarily — never commit skips without an issue link.
- Deterministic inputs: `rand.New(rand.NewPCG(1, 2))` injected; fixed `time.Time` via injected clock; `t.TempDir()` for files; `t.Setenv` for env (disables parallel; if the code reads env at init, refactor).
- Isolate side effects: does the test write to a real DB/network? Move behind a tag and fake it in unit tests.
- Diff structures with `cmp.Diff(want, got, cmpopts.IgnoreFields(T{}, "UpdatedAt"), cmpopts.EquateEmpty())`.
- Run with the race detector before declaring a test "flaky"; most flakiness is a race.
- Delve: `dlv test ./pkg -- -test.run '^TestX$'`, break at the assertion, inspect `got`.
- `testing.Short()` guards slow tests: `go test -short` for the fast loop.
- After the fix: `go test -count=20 -race -run TestX ./pkg` to confirm stability.

## Test infra smells to fix while you're there

- `time.Sleep` for synchronization; `init()` in tests; global mutable fixtures; tests depending on ordering; `os.Exit` in test helpers; `panic` in table data setup; ignored `Close()` errors on temp resources; tests that print instead of asserting.
