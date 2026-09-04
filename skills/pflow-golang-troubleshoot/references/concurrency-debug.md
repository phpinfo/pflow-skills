# Concurrency debugging

## Data races

- Run `go test -race -count=1 ./...` (and `go build -race` for the binary; ~5–10× slower, 5–10× memory). CI must include it.
- Report anatomy: `WARNING: DATA RACE` → `Write at 0x… by goroutine N` (stack) → `Previous read at 0x… by goroutine M` (stack) → `Goroutine N (running) created at:` (where each `go` statement is). Fix the *ownership*, not the line: who should own that variable?
- Fixes in order of preference: don't share (pass values, per-goroutine state, channels); share immutable data; guard with a mutex; atomic for single words. Never "fix" a race by adding `time.Sleep`.
- Common sources: closure over a loop var (pre-1.22), appending to a shared slice from workers, writing test results from goroutines without `t.Errorf` safety (use `t.Error` from goroutines is OK, `t.Fatal` is not), lazy init without `sync.Once`, map read/write mix (map reads are not safe with concurrent writes).
- `fatal error: concurrent map writes` / `concurrent map read and map write` is the runtime's own detector; it's a race even if `-race` didn't catch it.
- `GORACE="halt_on_error=1 history_size=7"` to stop at the first race with deeper stacks.

## Deadlocks and hangs

- `fatal error: all goroutines are asleep - deadlock!` → every goroutine blocked. Read each `goroutine N [chan receive]` / `[semacquire]` / `[select]` state: the state tells you what it waits on.
- Partial hang (some goroutines alive) is not detected by the runtime. Get a dump: send `SIGQUIT` (`kill -QUIT pid`) for a full trace, or `curl :6060/debug/pprof/goroutine?debug=2` with `net/http/pprof`. In tests: `go test -timeout 30s` prints all goroutines on timeout.
- Read the dump: group goroutines by stack; the waiting states name the problem: `chan send` on an unbuffered channel with no receiver; `chan receive` waiting for a close that never comes; `sync.Mutex.Lock` → lock ordering or forgotten unlock (panic between Lock/Unlock without defer); `sync.WaitGroup.Wait` → `Add` count > `Done` calls.
- `select {}` with no `ctx.Done()` case; `for range ch` when nobody closes `ch`; `wg.Wait()` inside the goroutine that should call `Done`; RWMutex: `RLock` then `Lock` on the same goroutine deadlocks (not reentrant).
- Context missing: a downstream call has no timeout; add `context.WithTimeout` and `-timeout` in tests to turn hangs into errors with stacks.
- Lock ordering: two mutexes taken in different orders in two paths → always take in a fixed order or use one lock. `go test -race` doesn't detect deadlocks; `go vet` doesn't either — reason from the dump.

## Goroutine leaks

- Symptom: goroutine count grows (`runtime.NumGoroutine()`, `/debug/pprof/goroutine`), memory grows, "too many open files".
- Causes: worker waiting on a channel no one writes; HTTP response body not closed (transport goroutines); `time.After` per iteration; producer blocked on send after consumer returned early; `context` never canceled; server goroutine without shutdown.
- Test with `goleak.VerifyNone(t)` (`go.uber.org/goleak`) or `defer goleak.VerifyTestMain(m)`. Diff two goroutine profiles minutes apart in prod: the growing stack is the leak.
- Fix: every blocking send/receive in a `select` with `ctx.Done()`; owner closes channels; bounded lifetimes via `errgroup`.

## Wrong results under concurrency

- Lost updates → non-atomic `x++`, `m[k]++`, check-then-act (`if !exists { create }`). Use `atomic.Int64`, `sync.Mutex`, `sync.Map.LoadOrStore`, or `singleflight`.
- Order dependence: channel fan-in reorders items; tests asserting order over concurrent workers must sort or use indices.
- Reads of stale values without synchronization (no happens-before) → visible only sometimes; `-race` catches most; `sync/atomic` or channels establish ordering.
- Closing a channel twice / sending after close → `panic: close of closed channel`. Single owner closes; use `sync.Once` if in doubt.
- Panics inside goroutines crash the whole process — recover at the goroutine boundary and convert to an error (`errgroup` does not recover for you).

## Tools

- `go test -race`, `-timeout`, `-count=N`, `-cpu=1,4,16` (surface scheduling assumptions), `GOMAXPROCS=1` to make ordering deterministic-ish.
- `runtime/trace`: `go test -trace trace.out` → `go tool trace trace.out` → "Goroutine analysis", "Synchronization blocking profile", "Scheduler latency".
- `-blockprofile block.out` (where goroutines wait), `-mutexprofile mutex.out` (contended locks) → `go tool pprof`.
- `dlv test ./pkg -- -test.run TestX` → `goroutines`, `goroutine N bt`, `bt` while hung: attach to a hung process with `dlv attach PID`.
- `testing/synctest` (1.25): `synctest.Test(t, func(t *testing.T) { … synctest.Wait() … })` makes timers virtual and detects goroutines blocked forever inside the bubble.
- `go vet` flags: `copylocks` (mutex copied), `lostcancel`, `unusedresult`; staticcheck SA2xxx for concurrency misuse.
