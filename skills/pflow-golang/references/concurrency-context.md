# Concurrency and context

## Ownership rules

- Never start a goroutine without knowing how and when it stops. The starter owns cancellation (`ctx`) and waits (`WaitGroup`/`errgroup`).
- Leave concurrency to the caller: expose synchronous APIs; callers add goroutines if they need them. Exception: servers/workers whose job is concurrency.
- No fire-and-forget `go f()`. Wrap in a helper that recovers panics, logs, and reports via `errgroup` or a channel.
- Prefer `errgroup.Group` (`golang.org/x/sync/errgroup`) for fan-out: `g, ctx := errgroup.WithContext(ctx); g.Go(func() error {…}); return g.Wait()`. `g.SetLimit(n)` bounds parallelism.
- Go 1.25+: `wg.Go(func())` replaces `wg.Add(1); go func(){ defer wg.Done() … }()`.

## Channels

- Channel size is 0 or 1 unless you can justify the number with a measured need. Buffers hide backpressure bugs.
- The sender closes; only one sender closes. Multiple senders → don't close, use a `done` channel or `WaitGroup` then close in the coordinator.
- `for v := range ch` to consume until close. `select` with `ctx.Done()` on every blocking send/receive that may wait.
- Nil channel blocks forever: set a channel variable to `nil` inside `select` to disable a case after it's drained.
- `time.After` in a loop leaks timers until fired; use `time.NewTimer` + `Reset`, or `context.WithTimeout`.
- Don't use channels as mutexes or for simple shared state. "Channels orchestrate; mutexes serialize."

## Mutexes and sync

- Guard shared fields with `sync.Mutex`/`RWMutex` stored as an unexported field directly above the guarded fields; comment the invariant.
- Hold locks briefly; never call out (I/O, callbacks, other locks) while holding one. Copy what you need, unlock, then work.
- `defer mu.Unlock()` right after `Lock()` unless the critical section is a few lines and the function continues long after.
- `RWMutex` only when reads dominate and are measured hot; otherwise plain `Mutex`.
- `sync/atomic` typed values (`atomic.Int64`, `atomic.Bool`, `atomic.Pointer[T]`) for counters and flags; don't mix atomic and non-atomic access.
- `sync.Once` / `sync.OnceValue` for lazy init; `sync.Map` only for append-mostly caches with disjoint keys — a mutex + map is usually clearer.
- `sync.Pool` for expensive, reusable, size-stable buffers in hot paths; reset before `Put`.
- Never copy a `Mutex`/`WaitGroup`/`Cond` after use (pass structs containing them by pointer).
- Run `go test -race` in CI; the race detector finds real bugs, not theoretical ones.

## Patterns

- Worker pool: fixed N goroutines ranging over a jobs channel; results channel closed by a coordinator after `wg.Wait()`. Or `errgroup` with `SetLimit`.
- Pipeline: each stage owns its output channel and closes it when input is exhausted; propagate `ctx` to every stage.
- Semaphore: buffered channel `sem := make(chan struct{}, n)` or `golang.org/x/sync/semaphore`.
- `singleflight.Group` to dedupe concurrent identical requests (cache stampede).
- Timeouts: `ctx, cancel := context.WithTimeout(ctx, d); defer cancel()` — always call cancel.
- Periodic work: `ticker := time.NewTicker(d); defer ticker.Stop(); for { select { case <-ctx.Done(): return; case <-ticker.C: … } }`.
- Go 1.25+ `testing/synctest` for deterministic tests of time-dependent concurrent code.

## Context

- First parameter, named `ctx`, never `nil` (`context.TODO()` if truly unknown), never stored in a struct; exception: a request struct that *is* the scope (e.g. `http.Request`).
- Derive, don't create: child contexts via `WithCancel`/`WithTimeout`/`WithDeadline`/`WithValue`. Only `main`, tests, and background workers start from `Background()`.
- Cancellation flows down; results flow up. Check `ctx.Err()` in long loops; pass `ctx` to every I/O call (`db.QueryContext`, `http.NewRequestWithContext`).
- Return `ctx.Err()` (or wrap it) when a cancellation interrupts work so callers can `errors.Is(err, context.Canceled)`.
- `context.WithoutCancel(ctx)` for work that must outlive the request (audit log, cache write) while keeping values; add your own timeout.
- `context.WithCancelCause` / `context.Cause(ctx)` to explain why a context ended.
- `context.AfterFunc(ctx, f)` to run cleanup on cancellation without a goroutine.
- Values: only request-scoped metadata (trace ID, auth principal), never dependencies or options. Unexported key type + typed accessor:

```go
type ctxKey struct{}
func WithUser(ctx context.Context, u User) context.Context { return context.WithValue(ctx, ctxKey{}, u) }
func UserFrom(ctx context.Context) (User, bool) { u, ok := ctx.Value(ctxKey{}).(User); return u, ok }
```

- HTTP servers: `r.Context()` is canceled when the client disconnects; use it for downstream calls. Set `http.Server` timeouts (`ReadHeaderTimeout`, `ReadTimeout`, `WriteTimeout`, `IdleTimeout`).
- Tests: `t.Context()` (Go 1.24+) is canceled at test end.
