# connectrpc.com/connect (connect-go) — idioms

## Layout

- Keep `.proto` sources and generated code together (`internal/pkg/<api>/proto`, `internal/pkg/<api>/gen`); never edit
  `gen/`. Generate with `buf generate` (plugins `protoc-gen-go`, `protoc-gen-connect-go`) pinned via `buf.gen.yaml` and
  `go tool`; a CI diff check catches `proto/` committed without regenerating.
- One Go package per proto package; version in the path (`foov1`, `foov1connect`).
- Hand-written transport (HTTP client, interceptors, auth headers, uploads) lives outside `gen/` in a small `client`
  package that wraps the generated clients.

## Client

```go
httpClient := &http.Client{Timeout: 30 * time.Second}
client := foov1connect.NewFooServiceClient(
    httpClient, baseURL,
    connect.WithInterceptors(authInterceptor(session), loggingInterceptor(log)),
)
req := connect.NewRequest(&foov1.GetReq{Id: id})
req.Header().Set("X-Session", session)
res, err := client.Get(ctx, req)
if err != nil { return nil, fmt.Errorf("get foo: id=%q: %w", id, err) }
return res.Msg, nil
```

- `connect.WithGRPC()` only against a real gRPC server (otherwise 415/unknown); never against a Connect server.
- Pass `ctx` with a timeout on every call; Connect maps `context.DeadlineExceeded`/`Canceled` to codes automatically.
- Reuse one `http.Client` (connection pooling). Set `Timeout` or use ctx deadlines; never both unbounded.
- Large uploads/downloads: presigned URLs with a plain `http.Client` (no RPC credentials), streaming `io.Reader` bodies,
  explicit `Content-Type`, drain and close `res.Body`. Don't push blobs through unary RPCs.
- Streaming: `client.Stream(ctx)` returns a stream; always `CloseRequest`/`CloseResponse`; check `stream.Receive` errors
  with `errors.Is(err, io.EOF)` for normal end.

## Server

```go
mux := http.NewServeMux()
path, handler := foov1connect.NewFooServiceHandler(svc, connect.WithInterceptors(recoverInterceptor(), authInterceptor()))
mux.Handle(path, handler)
srv := &http.Server{Addr: addr, Handler: h2c.NewHandler(mux, &http2.Server{}), ReadHeaderTimeout: 5 * time.Second}
```

- `h2c` only for plaintext HTTP/2 (gRPC clients fail without it); behind TLS use the standard server.
- Auth in HTTP middleware or an interceptor: read `req.Header()`, put the principal into `ctx` via a typed key.
- `connect.WithRecover` / a recover interceptor turns panics into `CodeInternal`.
- Health and reflection: `connectrpc.com/grpchealth`, `connectrpc.com/grpcreflect` when tooling needs them.
- Validate requests with `protovalidate` (`buf.build/go/protovalidate`) in an interceptor before business logic.

## Errors

- Handlers return `connect.NewError(code, err)`; unknown errors become `CodeUnknown`. Map: `ErrNotFound → CodeNotFound`,
  validation → `CodeInvalidArgument`, auth → `CodeUnauthenticated`/`CodePermissionDenied`.
- Client side: `connect.CodeOf(err)` for branching; `errors.As(err, &cerr)` with `var cerr *connect.Error` for
  `cerr.Message()`, `cerr.Details()`.
- Rich details: `connect.NewErrorDetail(&errdetails.BadRequest{…})`; `cerr.AddDetail(d)`. Keep messages user-safe; log
  internals server-side.
- `CodeUnavailable`/`DeadlineExceeded` are retryable; others are not. Retry with backoff only for idempotent RPCs.

## Interceptors

```go
func loggingInterceptor(log *slog.Logger) connect.UnaryInterceptorFunc {
    return func(next connect.UnaryFunc) connect.UnaryFunc {
        return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
            start := time.Now()
            res, err := next(ctx, req)
            log.InfoContext(ctx, "rpc", "procedure", req.Spec().Procedure, "code", connect.CodeOf(err), "dur", time.Since(start))
            return res, err
        }
    }
}
```

- Order: interceptors run in the order given, outermost first. Put recover → logging → auth → validation.
- `req.Spec().IsClient` when one interceptor serves both sides. Implement full `connect.Interceptor` (`WrapUnary`,
  `WrapStreamingClient`, `WrapStreamingHandler`) when streams exist.
- Client metadata (session, user agent, hostname) belongs in an interceptor, not in every call site.

## Testing

- Unit: call the handler struct methods directly with `connect.NewRequest`; no HTTP.
- Integration: `httptest.NewServer(handler)` and a real generated client pointed at `srv.URL`;
  `httptest.NewUnstartedServer` + `EnableHTTP2` for h2. Assert on `connect.CodeOf(err)`, not on error strings.
- Fake the server for CLI tests: a struct of func fields implementing `foov1connect.FooServiceHandler`.
