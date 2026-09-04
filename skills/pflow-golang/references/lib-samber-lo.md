# samber/lo — when and how

## Rule zero: stdlib first

Use the standard library when it has the function; reach for `lo` only for what stdlib lacks.

| Want | Use |
| --- | --- |
| contains / index / sort / reverse / min / max / compact / equal | `slices.*`, `min()`, `max()` |
| keys / values / clone / copy | `maps.Keys` + `slices.Collect`, `maps.Clone`, `maps.Copy` |
| default value | `cmp.Or(v, def)` |
| Map / Filter / Reduce / FlatMap | `lo.Map`, `lo.Filter`, `lo.Reduce`, `lo.FlatMap` |
| GroupBy / KeyBy / PartitionBy / CountBy | `lo` |
| Uniq / UniqBy / Chunk / Flatten / Interleave | `lo` (`slices.Chunk` exists since 1.23) |
| Ternary / Coalesce / Must / ToPtr / FromPtr / Empty | `lo` |
| Async helpers, debounce, retry, `Attempt` | `lo` (check `lo/parallel`) |

Iterators (Go 1.23+) reduce the need for `lo.Map` chains on large data: `slices.Collect(func…)` or `loi`.

## Idioms

- Callbacks take `(item T, index int)`: `lo.Map(users, func(u User, _ int) string { return u.Name })`. Ignore the index with `_`.
- `lo` functions return **new** slices/maps; inputs are never mutated. `lom` (mutable) exists only for measured hot paths.
- `lo.Filter` then `lo.Map` allocates twice; for hot paths use `lo.FilterMap` or a plain loop.
- `lo.Must(f())` panics on error — only in `main`/init for constants and regexes, never in request paths. Prefer explicit `if err != nil`.
- `lo.Ternary(cond, a, b)` evaluates both branches; use `lo.TernaryF` for lazy/expensive/panicky values. Don't nest ternaries; use `switch`.
- `lo.ToPtr(v)` for optional struct fields in API payloads; `lo.FromPtrOr(p, def)` to read them.
- `lo.Coalesce(a, b, c)` returns the first non-zero — good for config layering; `cmp.Or` does the same in stdlib (1.22).
- `lo.KeyBy(items, func(i Item) ID { return i.ID })` for index maps; `lo.GroupBy` for one-to-many; `lo.Associate` for key-value transforms.
- `lo.Uniq` keeps first occurrence order; `lo.UniqBy` for structs by key.
- `lo.Chunk(s, n)` for batching API calls; `lo.Flatten` to merge; `lo.Partition`/`lo.PartitionBy` to split by predicate.
- `lo.Contains`/`lo.IndexOf` are redundant with `slices` — use stdlib.
- Errors: `lo.Try`, `lo.TryCatch`, `lo.Validate` exist; they obscure control flow — prefer explicit Go error handling.

## Parallel (`lo/parallel`, alias `lop`)

- `lop.Map`, `lop.ForEach`, `lop.GroupBy` spawn one goroutine per element; only for CPU-bound or I/O-bound work over modest-size inputs. For thousands of network calls use `errgroup` with `SetLimit`.
- No error return in `lop` callbacks; collect errors yourself or use `errgroup`.

## Review flags

- Long `lo` chains that replace a 5-line loop with 5 allocations — rewrite as a loop.
- `lo.Must` outside startup. `lo.Ternary` with side effects. `lo.Map` where `slices.Collect(maps.Values(m))` or a `for range` is clearer.
- Importing `lo` in a package that uses one function once — a loop is fine.
- Mixing `lo` and `x/exp` versions of the same helpers; `x/exp/slices|maps` are deprecated → stdlib.
