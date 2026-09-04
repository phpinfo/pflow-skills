# Modern Go — apply only up to the module's `go` version

Tooling: `go fix ./...` (1.25+ applies modernizers) or `go run golang.org/x/tools/gopls/internal/analysis/modernize/cmd/modernize@latest -fix -test ./...`; golangci-lint linters `modernize`, `intrange`, `copyloopvar`, `exptostd`, `usetesting`, `perfsprint`, `testifylint`.

## Language

| Since | Rule |
| --- | --- |
| 1.18 | `any` instead of `interface{}`. Generics for containers/algorithms instead of `interface{}` + assertions. |
| 1.21 | Built-ins `min`, `max`, `clear`. Packages `slices`, `maps`, `cmp`, `log/slog`. |
| 1.22 | `for i := range n` instead of `for i := 0; i < n; i++`. Loop vars are per-iteration: delete `v := v` copies. `math/rand/v2` (`rand.IntN`, `rand.N`); no seeding needed. |
| 1.23 | Range-over-func iterators: `for k, v := range maps.All(m)`, `slices.Values`, `slices.Collect`, `slices.Sorted(maps.Keys(m))`. `iter.Seq`/`Seq2` in APIs that yield many items. |
| 1.24 | Generic type aliases. `for b.Loop()` in benchmarks. `t.Context()`. `omitzero` JSON tag. `strings.Lines/SplitSeq/FieldsSeq`. `weak` package. `go tool` directive replaces `tools.go`. |
| 1.25 | `wg.Go(f)`. `testing/synctest`. `encoding/json/v2` (GOEXPERIMENT). `sync.WaitGroup.Go`. |
| 1.26 | `errors.AsType[T](err)`. `new(expr)` with a value. Check the release notes of the exact version for anything newer. |

## Replacements the modernizer applies

- `interface{}` → `any`.
- `sort.Slice(s, func(i, j int) bool { return s[i] < s[j] })` → `slices.Sort(s)`; `sort.Strings/Ints` → `slices.Sort`; custom → `slices.SortFunc(s, cmp.Compare)`.
- Hand-written contains/index loops → `slices.Contains`, `slices.Index`, `slices.IndexFunc`.
- `append(s[:i], s[i+1:]...)` → `slices.Delete(s, i, i+1)`. `append(append([]T{}, a...), b...)` → `slices.Concat(a, b)`.
- `for k := range m { delete(m, k) }` → `clear(m)`. Map copy loops → `maps.Copy`, `maps.Clone`. Keys collection loop → `slices.Collect(maps.Keys(m))`.
- `if a < b { x = a } else { x = b }` → `x = min(a, b)`.
- `strings.Split` only to iterate → `strings.SplitSeq`. `strings.HasPrefix` + `TrimPrefix` → `strings.CutPrefix`. `strings.Index` + slicing → `strings.Cut`.
- `fmt.Sprintf("%s", s)` / `%d` of an int → `s` / `strconv.Itoa`. `[]byte(fmt.Sprintf(...))` → `fmt.Appendf`.
- `x := x` in loops → delete. `for i := 0; i < n; i++` → `for i := range n`.
- `reflect.TypeOf((*T)(nil)).Elem()` → `reflect.TypeFor[T]()`.
- `wg.Add(1); go func() { defer wg.Done(); … }()` → `wg.Go(func() { … })`.
- `context.WithCancel(context.Background())` in tests → `t.Context()`. `os.MkdirTemp` in tests → `t.TempDir()`. `os.Setenv` → `t.Setenv`.
- `errors.As(err, &target)` with a throwaway var → `errors.AsType[T](err)` (1.26).
- `ioutil.*` → `io.*` / `os.*`. `rand.Seed` → delete (auto-seeded since 1.20). `golang.org/x/exp/slices|maps|constraints` → stdlib.
- `atomic.AddInt64(&x, 1)` → `atomic.Int64` field. `sync.Once` + value → `sync.OnceValue`.
- `http.Handle("/x", …)` + manual method check → method-aware patterns `mux.HandleFunc("GET /x/{id}", …)` and `r.PathValue("id")` (1.22).
- Struct tag `json:",omitempty"` on structs/time → `omitzero` (1.24) when zero-value skipping is meant.

## Deprecations and go.mod

- Read `go vet` and `staticcheck` SA1019 warnings; replace deprecated APIs at the call site instead of suppressing.
- Bump the `go` directive deliberately; it changes language semantics (loopvar 1.22) and the default GODEBUG set. Check `//go:debug` needs.
- `toolchain` line: keep unless you need to pin; `GOTOOLCHAIN=auto` fetches newer toolchains on demand.
- Remove `// +build` lines (only `//go:build` since 1.17). Remove `tools.go` in favor of `tool` directives (1.24).
- Prefer `go install pkg@version` / `go tool pkg` over globally installed binaries in scripts.

## When not to modernize

- Generated code (`// Code generated … DO NOT EDIT.`) — fix the generator.
- Public API signatures of a library other modules import — a `[]T` → `iter.Seq[T]` change is breaking.
- Where the module's `go` line is lower than the feature's version, or a build target pins an older toolchain.
