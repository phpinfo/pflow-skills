# Idiomatic patterns

## Constructors and configuration

- `New…(required deps…, opts ...Option)` — required things are positional, optional ones go through functional options or a config struct.
- Functional options for libraries with many optional knobs:

```go
type Option func(*Server)
func WithTimeout(d time.Duration) Option { return func(s *Server) { s.timeout = d } }
func NewServer(addr string, opts ...Option) *Server {
    s := &Server{addr: addr, timeout: 30 * time.Second} // defaults first
    for _, o := range opts { o(s) }
    return s
}
```

- Config struct when options are data (`Config{Addr, Timeout}`) loaded from flags/env/file; validate in `New` and return an error.
- Defaults live in one place (the constructor). Use `cmp.Or(cfg.Port, 8080)` for simple fallbacks.
- Dependency injection = pass dependencies to constructors. Wire manually in `main`; reach for `wire`/`fx`/`do` only when the graph is large and the team already uses them.

## Resource lifecycle

- Whoever opens closes: `f, err := os.Open(p); if err != nil { return err }; defer f.Close()` in the same function.
- Constructors that acquire resources return `(*T, error)` and the type has `Close() error`. Document idempotency; make `Close` safe to call twice with `sync.Once`.
- Use `errgroup`/`context` for lifecycle, not global shutdown channels.
- Graceful shutdown in `main`:

```go
ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
defer stop()
srv := &http.Server{Addr: addr, Handler: h, ReadHeaderTimeout: 5 * time.Second}
go func() { <-ctx.Done(); shCtx, c := context.WithTimeout(context.Background(), 10*time.Second); defer c(); _ = srv.Shutdown(shCtx) }()
if err := srv.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) { return err }
```

- `main` is thin: parse config → build deps → `run(ctx, cfg) error` → exit code. Only `main` calls `os.Exit`, once.

## Behavioral patterns, the Go way

- Strategy = an interface with one method, or just a `func` type (`type Handler func(ctx, req) error`).
- Middleware/decorator = function that takes and returns the same interface or func type; chain in order.
- Adapter = small struct implementing the consumer's interface over a third-party type; keep it in the consumer package.
- Builder is rarely needed; prefer a struct literal or functional options. Fluent APIs hide errors.
- Singleton = package-level `var` initialized in `main` and injected, or `sync.OnceValue(func() T)`; never a global reached from everywhere.
- Observer = channels or a slice of callbacks under a mutex; document goroutine ownership.
- State machine = `type state int` + `switch`; keep transitions in one function.
- Repository/service layering only when there are ≥ 2 implementations or the boundary is real (DB, network). Don't pre-build layers.

## Resilience

- Every outbound call has a timeout from `context.WithTimeout`; `http.Client` gets an explicit `Timeout` too.
- Retries: bounded attempts, exponential backoff with jitter, only for idempotent operations and retryable errors; honor `ctx.Done()` between attempts.
- Circuit breakers, rate limits (`golang.org/x/time/rate`) at the client edge, not sprinkled in business code.
- Make handlers idempotent where retried; return the same result for the same key.

## Data flow

- Streaming over slurping: `io.Reader`/`io.Writer` pipes, `bufio.Scanner`, `json.Decoder` for large inputs.
- Validate at the boundary once (HTTP handler, CLI parse), then pass typed values inward; inner code trusts its inputs.
- DTOs for wire formats, domain types inside; convert in one place (`toDomain`, `fromProto`).
- Time: inject `func() time.Time` or a `Clock` interface for testability; use `time.Now().UTC()` for storage.
- IDs: typed (`type UserID string`) to prevent mixing parameters.

## Anti-patterns to flag in review

- Interfaces with one implementation and no test seam; `I`-prefixed interfaces; `Get`-prefixed getters.
- Package-level `var db *sql.DB`; `init()` doing I/O; `log.Fatal` outside `main`.
- Returning `interface{}`/`any`; `map[string]interface{}` where a struct fits.
- Premature abstraction: "abstractions should be discovered, not created". Three similar lines beat a wrong helper.
- `util`, `common`, `helpers`, `base` packages; giant `models` packages shared by everything.
- Setters/getters that wrap every field; deep inheritance-like embedding chains.
- Boolean parameters (`Send(msg, true)`); use an option or two functions.
