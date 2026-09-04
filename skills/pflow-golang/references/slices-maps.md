# Slices, maps, strings

## Slices

- A slice is `{ptr, len, cap}`; slicing shares the backing array. `b := a[1:3]` then `append(b, x)` may overwrite `a[3]`. Use the full slice expression `a[1:3:3]` to force a copy on append, or `slices.Clone`.
- Preallocate when the size is known: `make([]T, 0, n)` then `append`. Don't `make([]T, n)` then `append` (doubles the length).
- Growth is amortized (~2× small, ~1.25× large); repeated `append` in a loop is fine, but a known `n` saves reallocations.
- Filtering in place: `out := s[:0]; for _, v := range s { if keep(v) { out = append(out, v) } }` — mutates `s`'s array; only when `s` is yours. Otherwise `slices.DeleteFunc` (in place) or build a new slice.
- Sub-slicing a large slice keeps the whole array alive. Copy small results out of big buffers (`slices.Clone`) before storing them long-term.
- Nil slice vs empty: both `len == 0`; `range`, `append`, `len` all work on nil. Return nil for "no results"; use `[]T{}` only when JSON must be `[]`.
- Prefer `slices` package: `Contains`, `Index`, `IndexFunc`, `Sort`, `SortFunc`, `SortStableFunc`, `BinarySearch`, `Reverse`, `Compact`, `Equal`, `Max`, `Min`, `Insert`, `Delete`, `Concat`, `Chunk` (1.23), `Collect`/`Sorted`/`Values` (1.23 iterators).
- `copy(dst, src)` copies `min(len)` elements — size `dst` first.
- Arrays are values: `[3]int` copies on assignment; use them for fixed-size keys (`[16]byte`), not for lists.
- 2-D data: one flat slice with index math beats `[][]T` for performance and locality.
- Removing an element while iterating by index → iterate backwards or build a new slice.

## Maps

- Always initialize: `make(map[K]V, sizeHint)` or a literal. Writing to a nil map panics.
- Iteration order is random by design; sort keys (`slices.Sorted(maps.Keys(m))`) when order matters, or keep a separate ordered slice.
- Not safe for concurrent writes (fatal error, not recoverable). Guard with a mutex or use `sync.Map` for the narrow "disjoint keys, write-once" case.
- Deleting during `range` is safe; adding is allowed but new keys may or may not be visited.
- Keys must be comparable: structs of comparable fields are fine (`struct{a, b string}`), slices are not — use a string join or array.
- `maps` package: `Keys`, `Values` (iterators), `Clone`, `Copy`, `DeleteFunc`, `Equal`, `Collect`. `clear(m)` resets without reallocation (1.21).
- A `map[K]struct{}` is a set. `map[K]*V` when you must mutate values in place; `map[K]V` with reassignment otherwise.
- Map memory never shrinks after deletes; rebuild a fresh map for long-lived caches that churn.
- Large maps with pointer-free keys/values are GC-cheap; pointers in maps make GC scan them.

## Strings and bytes

- Strings are immutable byte sequences; `len` is bytes, not runes. `range` yields runes; index yields bytes. Use `utf8.RuneCountInString` for character counts.
- Build strings with `strings.Builder` (`Grow` when size is known), not `+=` in loops. `bytes.Buffer` when you also need `io.Reader`/`Writer`.
- `strconv` over `fmt.Sprint` for numbers (10× faster). `fmt.Sprintf` for formatting only.
- `strings.Cut`, `CutPrefix`, `CutSuffix` over `Index` + slicing. `strings.Fields` for whitespace splitting. `strings.EqualFold` for case-insensitive compare.
- Go 1.24: `strings.Lines`, `SplitSeq`, `FieldsSeq` iterators avoid allocating the whole slice.
- `[]byte(s)` and `string(b)` copy; avoid repeated conversions in loops. `unsafe.String`/`unsafe.Slice` only in measured hot paths with a comment.
- Compare `[]byte` with `bytes.Equal`; strings with `==`.
- Regexes: compile once at package level (`regexp.MustCompile`), never per call.

## Other containers

- `container/heap` for priority queues (implement 5 methods); `container/list` rarely beats a slice — measure.
- `slices.BinarySearch` on a sorted slice often replaces a tree. For LRU/TTL caches use a small library or a map + list.
- Iterators (1.23): `iter.Seq[T]` / `iter.Seq2[K,V]` for lazy sequences; `for v := range seq`. Return iterators from APIs that produce many items; accept slices for small fixed inputs.
- `weak.Pointer` (1.24) and `unique.Handle` (1.23) for caches and interning; rare — comment why.

## Pointers

- Pass small structs by value, large or mutated ones by pointer. Pointers to slices/maps are almost never needed.
- Pointer receivers are not "faster" for small types; value copies avoid heap escapes.
- Escape analysis: returning `&local` heap-allocates; `go build -gcflags=-m` shows why.
- `unsafe.Pointer` only with a documented invariant and a test; `go vet` `unsafeptr` must pass.
