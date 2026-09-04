# Security checklist

Run `govulncheck ./...` (reachability-aware) and `gosec` via golangci-lint. Review this list on any code that handles input, files, network, credentials, or spawns processes.

## Input and injection

- SQL: parameterized queries only (`db.QueryContext(ctx, "… WHERE id = $1", id)`); never `fmt.Sprintf` into SQL. Table/column names from an allowlist.
- Shell: `exec.CommandContext(ctx, "bin", args...)` with args as separate strings; never `sh -c` with user data. Validate the binary path; set `cmd.Env` explicitly.
- HTML: `html/template` (auto-escapes), never `text/template` for HTML; `template.HTML` only for trusted, pre-sanitized content.
- Paths: `filepath.Clean` + prefix check, or `os.OpenRoot` (1.24) / `os.Root` to jail file access; reject `..` and absolute paths from users. Use `filepath.Join`, not string concat.
- URLs: parse with `url.Parse`, allowlist schemes (`https`) and hosts for outbound requests (SSRF); block link-local/private ranges when fetching user URLs.
- Deserialization: set `json.Decoder.DisallowUnknownFields()` where strictness matters; cap sizes with `http.MaxBytesReader`; validate after decode. Never `gob`/`yaml` from untrusted sources without limits.
- Regex from users → ReDoS is impossible in Go's RE2 engine, but cap input length anyway.
- Integer parsing: `strconv.ParseInt(s, 10, 64)` with range checks; validate sizes before `make`.

## Crypto

- Randomness: `crypto/rand` for tokens, keys, salts, IDs (`rand.Text()` 1.24). `math/rand/v2` only for non-security use.
- Hashing passwords: `golang.org/x/crypto/argon2` or `bcrypt`; never SHA-256 alone. Constant-time compare: `crypto/subtle.ConstantTimeCompare`.
- Symmetric: AES-GCM or `chacha20poly1305`; fresh nonce per message (`crypto/rand`), never reuse. `crypto/hkdf` (1.24 stdlib) for key derivation.
- TLS: `tls.Config{MinVersion: tls.VersionTLS12}`; never `InsecureSkipVerify: true` outside tests. Prefer stdlib defaults for cipher suites.
- JWT: verify algorithm allowlist, `exp`, `aud`, `iss`; use a maintained library. No `none`.
- Don't roll your own crypto or protocols. MD5/SHA1 only for non-security checksums.

## Secrets

- Never in code, git, logs, error messages, or URLs. Load from env or a secret manager; zero buffers you control after use where feasible.
- `.env` files are for local dev only and are gitignored. Config structs: mark secret fields and redact in `String()`/`LogValue()`.
- Rotate on leak; short-lived tokens over long-lived ones.

## Filesystem and processes

- Create files with explicit perms: `os.WriteFile(p, b, 0o600)`; dirs `0o700`/`0o755` deliberately. Use `os.CreateTemp`, not predictable names.
- Check symlinks when writing into user-controlled dirs (`os.Lstat`, `O_NOFOLLOW`, `os.Root`).
- Don't run as root in containers; drop capabilities; read-only filesystem where possible.
- Set timeouts on `exec` (`CommandContext`) and cap output size.

## Network and HTTP

- Servers: `ReadHeaderTimeout`, `ReadTimeout`, `WriteTimeout`, `IdleTimeout`, `MaxHeaderBytes`. Never `http.ListenAndServe` bare in production.
- Clients: explicit `Timeout` or ctx; don't follow redirects blindly to other hosts when credentials are attached.
- CORS allowlist explicit origins; no `*` with credentials. Set security headers (`Content-Security-Policy`, `X-Content-Type-Options: nosniff`, `Strict-Transport-Security`).
- Cookies: `HttpOnly`, `Secure`, `SameSite=Lax/Strict`, short expiry; sign or encrypt session cookies.
- Rate-limit auth endpoints; generic error messages for login failures; constant-time credential checks.
- gRPC/Connect: auth in interceptors/middleware; validate messages (protovalidate) before business logic; limit message size.

## Logging and errors

- Never log credentials, tokens, PII, full request bodies. Redact by type (`type Secret string` with `String()` returning `"***"`).
- Internal errors to users are generic; details go to logs with a correlation ID. Don't leak stack traces or file paths over the wire.

## Dependencies and build

- `go mod verify`, `govulncheck` in CI; Dependabot/Renovate for updates. Pin tool versions with `go tool`.
- Vet new deps: maintenance, license, transitive size (`go mod graph | wc -l`). Prefer stdlib.
- Build with `-trimpath`, reproducible flags; sign releases (goreleaser + cosign) when distributing binaries.
- Docker: distroless/`scratch` base with `CGO_ENABLED=0`, non-root `USER`, pinned base digests.

## Memory safety

- Avoid `unsafe`; when needed, isolate in one file with tests and `go vet`. `reflect` can bypass unexported fields — treat as unsafe.
- Slices from user sizes: cap before `make`; `bytes.Buffer` grows unbounded — use `io.LimitReader`.
- Data races are memory-safety bugs in Go: run `-race` in CI.
