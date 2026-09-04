# Build, module, vet and lint errors

## Compile errors — read the first one

- Go stops at the first ~10 errors and later ones are often consequences. Fix the first, rebuild: `go build ./... && go vet ./...`.
- `undefined: X` → wrong package/import, unexported name (`x` vs `X`), build tag excluding the file, or generated code missing. `go list -f '{{.GoFiles}} {{.IgnoredGoFiles}}' ./pkg`.
- `declared and not used` / `imported and not used` → delete it; don't `_ =` unless temporary.
- `cannot use x (variable of type A) as B value` → interface not satisfied: check pointer vs value receiver (`*T` implements, `T` doesn't), method signature drift (`ctx` param, return type). `go vet` shows the missing method: "missing method M" or "wrong type for method".
- `invalid operation: mismatched types int and int64` → explicit conversion; `time.Duration` math with untyped ints is fine, with typed ints is not.
- `missing return` → add `return` after the loop/switch; Go doesn't infer exhaustiveness.
- `cannot assign to struct field m[k].f in map` → map values aren't addressable; use `map[K]*T` or copy-modify-store.
- `assignment mismatch: 2 variables but f returns 1 value` → API changed; read the current signature (`go doc pkg.Func`).
- `initialization cycle` / `import cycle not allowed` → move shared types to a leaf package; interfaces belong to the consumer.
- `x.Method undefined (type T has no field or method Method)` after a dependency upgrade → check the module version actually selected: `go list -m all | grep dep`, `go mod graph | grep dep`.
- Generics: `T does not satisfy comparable` / `cannot infer T` → add a constraint or spell the type argument.
- cgo errors (`gcc not found`, `ld: …`) → `CGO_ENABLED=0` if no cgo deps; else install a C toolchain; cross-compiling with cgo needs a cross-compiler (`zig cc`, `xgo`).

## Modules

- `go: updates to go.mod needed` / `missing go.sum entry` → `go mod tidy`. In CI use `go mod tidy -diff` (1.23+) or `git diff --exit-code go.mod go.sum` after tidy.
- `ambiguous import: found package X in multiple modules` → two modules provide the same path (usually a v1→v2 split or a fork); pick one, `go get -u` the right module, `replace` only as a last resort.
- `module declares its path as X but was required as Y` → module path changed (v2 suffix missing, repo moved); update import paths.
- `verifying module: checksum mismatch` → someone rewrote a tag; `GOFLAGS=-mod=mod go clean -modcache` then re-tidy; if it persists, the dependency's history was force-pushed — pin a different version.
- `go: inconsistent vendoring` → `go mod vendor` or delete `vendor/`; `-mod=mod` to bypass temporarily.
- `package X is not in std` → import path typo or a Go version older than the package (`net/netip`, `slices`, `iter`). Check `go` line and `toolchain`.
- Private modules: `GOPRIVATE=github.com/acme/*`, `GONOSUMDB`, `GOPROXY=direct` for those paths; git credentials via `.netrc`/SSH `insteadOf`.
- `go.work` present → local replaces apply; `GOWORK=off` to test the standalone module.
- `toolchain` too new: `GOTOOLCHAIN=auto` downloads; `GOTOOLCHAIN=local` refuses. Pin with `go get go@1.x toolchain@go1.x.y`.
- Which version wins? Minimal Version Selection: the highest version *required by anyone* in the graph. `go mod why -m dep`, `go mod graph | grep ' dep@'`. Downgrade with `go get dep@vX` — may be forced back up by another requirement.

## vet and lint

- `go vet` is non-negotiable: `printf` (wrong verbs), `copylocks` (mutex copied — pass by pointer), `lostcancel` (missing `cancel()`), `unusedresult`, `nilness`, `loopclosure` (pre-1.22), `stdmethods` (wrong `String()`/`Error()` signature), `structtag` (bad tag syntax), `unreachable`.
- golangci-lint: read the linter name in each line (`errcheck`, `staticcheck SA1019`, `govet shadow`, `gocritic`) and fix the cause. `//nolint:linter // reason` only with a reason, on the specific line, when the linter is wrong — `nolintlint` enforces this.
- `SA1019: X is deprecated` → follow the pointer in the doc comment to the replacement.
- `SA4006: this value of err is never used` → shadowed/overwritten error → likely a real bug.
- `errcheck` on `defer f.Close()` → handle it (`defer func() { err = errors.Join(err, f.Close()) }()`) for writers; explicitly `_ = r.Close()` with a comment for readers.
- Config problems: `.golangci.yml` v1 syntax with golangci-lint v2 → migrate (`golangci-lint migrate`); `version: "2"` at the top. Linter renamed/removed → check `golangci-lint help linters`. Lint binary version must match CI (pin via `go tool` or a version in the task runner).
- `gofmt -l .` non-empty → files not formatted; `gofumpt`/`goimports` if the project uses them (read `.golangci.yml` `formatters`).

## Generated code

- Proto/Connect/mockery/stringer out of date → regenerate with the project task (`task proto:generate`, `task mocks`, `go generate ./...`), then `git diff` — CI should fail on drift.
- Generator binary version differs → different output; pin via `go tool` directives or a versioned install in the task runner.
- Never hand-edit files with `// Code generated … DO NOT EDIT.`; fix the source or the generator config.
