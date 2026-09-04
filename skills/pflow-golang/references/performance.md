# Performance — measure first, then optimize the measured bottleneck

Do nothing from this file without a benchmark or profile that names the hot spot. Correct and clear code first.

## Workflow

1. Reproduce with `go test -bench=X -benchmem -count=10 -run=^$ ./pkg > old.txt`.
2. Profile: `go test -bench=X -cpuprofile=cpu.out -memprofile=mem.out`, then `go tool pprof -http=:0 cpu.out` (flame graph, top, list). For services: `import _ "net/http/pprof"` on an internal port, `curl :6060/debug/pprof/profile?seconds=30`.
3. Change one thing. `benchstat old.txt new.txt`. Keep it only if the p-value and delta are convincing.
4. Add `b.ReportAllocs()`; allocations/op is usually the first number to drive down.

## Allocation reduction

- Preallocate slices and maps with known sizes; reuse buffers with `sync.Pool` or a caller-provided `[]byte`.
- Avoid `fmt.Sprintf` in hot paths: `strconv.AppendInt`, `strings.Builder`, `fmt.Appendf`.
- Escape analysis (`go build -gcflags='-m'`): values that escape are heap-allocated. Return values, not pointers to small structs; avoid storing pointers in interfaces in loops (interface conversion of non-pointer values allocates).
- `[]byte` ↔ `string` conversions copy; keep one representation. Map lookups with `m[string(b)]` are optimized (no copy).
- Closures capturing variables allocate; method values (`x.Method`) allocate; pass funcs explicitly.
- `time.Now()` is cheap; `time.Format` is not — cache formatted timestamps when logging at high rate.
- Struct field order: group same-size fields to minimize padding (`fieldalignment` analyzer); matters only for millions of instances.
- Pointer-free structures (no pointers, strings, slices inside) are skipped by the GC scanner — big win for large caches.

## CPU

- Avoid reflection (`encoding/json`, `fmt`) in hot loops; use code generation or manual encoding for critical paths.
- Bounds checks: iterate with `for i := range s` and access `s[i]`; hoist `_ = s[len(s)-1]` hints only after seeing them in `-gcflags=-d=ssa/check_bce`.
- Inline-able functions (small, no loops/defer/closures) are free; `//go:noinline` only in benchmarks.
- `switch` on strings compiles to efficient jumps; map lookups for large dispatch tables.
- Batch work: fewer syscalls (`bufio`), fewer lock acquisitions, fewer channel operations (send slices, not items).

## Memory and GC

- GC cost ∝ live heap pointers. Reduce live heap, reduce pointers, reuse objects.
- `GOGC` (default 100) trades memory for CPU; `GOMEMLIMIT` caps heap in containers — set it below the cgroup limit. Don't call `runtime.GC()` in production code.
- Large slices kept alive by a small sub-slice: copy the small part out.
- `sync.Pool` objects can vanish at any GC; never store state that must survive.
- Goroutines cost ~2–8 KB each; a million idle goroutines is fine, a million busy ones is not. Bound with `errgroup.SetLimit`/semaphores.

## I/O and networking

- Wrap `os.File`/`net.Conn` in `bufio.Reader`/`Writer`; flush deliberately. Prefer `io.Copy` (uses `ReaderFrom`/`WriterTo`, sendfile/splice).
- Reuse `http.Client` and `http.Transport` (connection pooling); tune `MaxIdleConnsPerHost`. Always close and drain response bodies.
- `json.Decoder` on streams instead of `io.ReadAll` + `Unmarshal`. Consider `encoding/json/v2` (1.25 experiment) or `easyjson`/`sonic` only when profiling blames JSON.
- Databases: prepared statements, connection pool sizing (`SetMaxOpenConns`), batch inserts, `context` timeouts on every query.
- Compression and TLS are CPU: measure before enabling on hot internal links.

## Caching

- Cache only what is expensive and stable; define eviction (LRU/TTL) and size bounds up front.
- `singleflight` to collapse concurrent misses. `sync.Map` for read-mostly caches; sharded mutex maps beyond that.
- Memoize pure functions with `sync.OnceValue` for process lifetime constants.

## Observability

- Expose `expvar`/Prometheus metrics for latency histograms, error rates, goroutine count, heap; `runtime/metrics` for GC stats.
- `net/http/pprof` on a private listener in every long-running service; continuous profiling (Pyroscope/Parca) beats guessing.
- Trace with `runtime/trace` + `go tool trace` for scheduler/blocking issues; `-blockprofile` and `-mutexprofile` for contention.

## Don'ts

- Don't micro-optimize before profiling. Don't use `unsafe` for speed without a benchmark and a comment. Don't disable the GC. Don't add goroutines to "make it parallel" without measuring the serial baseline.
