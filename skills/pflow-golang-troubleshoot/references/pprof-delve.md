# Profiling and stepping

## Getting a profile

| Situation | Command |
| --- | --- |
| Benchmark | `go test -run '^$' -bench 'BenchmarkX' -benchmem -cpuprofile cpu.out -memprofile mem.out ./pkg` |
| Test | `go test -run TestX -cpuprofile cpu.out -memprofile mem.out -blockprofile block.out -mutexprofile mutex.out ./pkg` |
| Running service | `import _ "net/http/pprof"` on an internal mux; `go tool pprof -http=:0 http://host:6060/debug/pprof/profile?seconds=30` |
| Heap now | `…/debug/pprof/heap` (inuse), `?gc=1` to GC first; `allocs` for total allocations |
| Goroutines | `…/debug/pprof/goroutine?debug=2` (full stacks, text) |
| CLI / one-shot program | `github.com/pkg/profile` or manual `pprof.StartCPUProfile(f)` / `pprof.WriteHeapProfile(f)` around `run()` |
| Execution trace | `go test -trace trace.out` or `…/debug/pprof/trace?seconds=5` → `go tool trace trace.out` |

Always profile a build close to production (`-race` off, same GOGC/GOMEMLIMIT), for long enough to capture the behavior (≥ 10–30 s of load).

## Reading pprof

- `go tool pprof -http=:0 cpu.out` → Flame Graph first (widest frames = time), then Top (`flat` = own time, `cum` = including callees), Source view for hot lines.
- CLI: `top -cum 20`, `list FuncName`, `peek Regex`, `web`, `-focus=Func`, `-ignore=runtime`. `-diff_base old.out new.out` to compare before/after.
- Memory: `-sample_index=alloc_space` (who allocates the most, total), `inuse_space` (what's live now — leaks), `alloc_objects` (allocation count → GC pressure). A leak = `inuse_space` growing between two heap profiles taken minutes apart.
- Runtime frames (`runtime.mallocgc`, `runtime.scanobject`, `gcBgMarkWorker`) high in CPU → allocation problem, not CPU logic; go to `alloc_objects`.
- `runtime.futex`/`sync.(*Mutex).Lock` hot → contention: use `mutexprofile` to find the lock, `blockprofile` to find waits.
- `syscall.Syscall` hot → I/O without buffering or too many small writes.
- Flat time in `encoding/json`, `fmt`, `reflect` → serialization; consider streaming, code generation, or caching.

## Memory problems

- OOM-killed / RSS grows: heap profile diff; `GODEBUG=gctrace=1` shows heap goal per cycle (`… 4->4->2 MB, 5 MB goal`). Live heap stable but RSS high → fragmentation or `GOMEMLIMIT` unset in a container; set `GOMEMLIMIT` ≈ 80–90% of the limit.
- Common leaks: global maps/caches without eviction; goroutines holding references (see `concurrency-debug.md`); sub-slices pinning large arrays; `time.Ticker` not stopped; `http.Response.Body` unclosed; `context.WithValue` chains carrying big payloads; `sync.Pool` misuse (storing huge buffers).
- High GC CPU (`gcBgMarkWorker` > 25%): reduce allocations per op (`benchmem`), reduce pointers in large structures, raise `GOGC` if memory is available.
- Escape analysis: `go build -gcflags='-m -m' ./pkg 2>&1 | grep 'escapes to heap'` to see why a value went to the heap.

## CPU problems

- Compare with a benchmark: `go test -bench X -count 10 > old.txt`; change; `> new.txt`; `benchstat old.txt new.txt`. Trust only results with tight ± and p < 0.05.
- Check GOMAXPROCS in containers (CPU quota vs cores; Go 1.25+ respects cgroup limits, older: `go.uber.org/automaxprocs`).
- Scheduler issues (latency spikes, few cores busy): `go tool trace` → Scheduler latency profile, goroutine view; look for long-running goroutines without preemption points (tight loops without function calls — rare since 1.14 async preemption) and GC assist.

## Delve

- Install: `go install github.com/go-delve/delve/cmd/dlv@latest`. Build flags for readable debugging: `-gcflags='all=-N -l'` (dlv adds them by default for `dlv test`/`dlv debug`).
- Tests: `dlv test ./internal/pkg -- -test.run '^TestX$' -test.v`. Binary: `dlv debug ./cmd/tool -- --flag arg`. Running process: `dlv attach PID`. Core dump: `GOTRACEBACK=crash` + `dlv core ./bin core`.
- Essentials: `break pkg.Func` / `b file.go:42` / `b` with `cond N x == nil`; `c` continue; `n` next; `s` step; `so` step out; `p expr` print; `locals`, `args`, `vars pkg`; `bt` backtrace; `frame 2`; `goroutines`, `goroutine N bt`; `on 1 print x` auto-print at breakpoint; `trace pkg.Func` prints every call without stopping.
- `config max-string-len 500`, `config max-array-values 200` to see full values. `display -a expr` to watch.
- Headless for editors: `dlv dap` (VS Code) or `dlv --headless --listen=:2345 --api-version=2 debug`. Remote containers: build with `-N -l`, run under `dlv exec --headless --continue --accept-multiclient`.
- Prefer a failing unit test + `dlv test` over adding prints when state is complex (many fields, nested pointers, maps).

## Other diagnostics

- `go tool nm -size -sort size ./bin | head` — what makes the binary large; `go version -m ./bin` — module versions inside a binary.
- `GODEBUG=http2debug=2`, `GODEBUG=netdns=go+2`, `GODEBUG=asyncpreemptoff=1` (isolate preemption issues), `GODEBUG=madvdontneed=1` (RSS release behavior).
- `runtime/metrics` (`/sched/latencies:seconds`, `/gc/heap/allocs:bytes`) for exporting to Prometheus; `expvar` for quick counters.
- `govulncheck ./...` when a "bug" turns out to be a dependency issue; `go mod why -m dep` to see why it's there.
