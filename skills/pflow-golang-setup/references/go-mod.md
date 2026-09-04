# go.mod hygiene

## The file

```
module github.com/acme/tool

go 1.26.0          // language version + default GODEBUG set; bump deliberately
toolchain go1.26.5 // optional; the minimum toolchain that will be used to build

require ( … )      // direct deps first block, indirect (// indirect) second — `go mod tidy` maintains this

tool (             // Go ≥ 1.24: dev tools pinned like deps; run with `go tool <name>`
	github.com/golangci/golangci-lint/v2/cmd/golangci-lint
	github.com/vektra/mockery/v3
)
```

- Module path = import path = repo URL (+ `/vN` for major ≥ 2). Changing it is a breaking change for importers.
- `go` line: the language version the code is written against; `go 1.22` enables per-iteration loop vars, `1.21+` enables toolchain auto-download. Use `major.minor.0` form (`1.26.0`) or `1.26`.
- `toolchain`: set when you need a specific patch level; otherwise omit and let `GOTOOLCHAIN=auto` pick ≥ `go` line.
- Keep `go mod tidy` clean; CI: `go mod tidy -diff` (1.23+) or tidy + `git diff --exit-code`.
- `replace` only for local development or emergency forks; never leave a `replace ../local` in a committed library. Prefer forking + retagging or upstreaming.
- `exclude` and `retract` are rare; `retract` in your own module to mark a bad release.

## Commands

| Task | Command |
| --- | --- |
| Add / upgrade dep | `go get github.com/x/y@latest` (or `@v1.4.0`, `@main`, `@commit`) |
| Upgrade all direct deps (minor/patch) | `go get -u ./...` then `go mod tidy`; test thoroughly |
| Patch-only upgrade | `go get -u=patch ./...` |
| Downgrade | `go get github.com/x/y@v1.2.0` — may fail if another dep requires newer (MVS) |
| Remove | delete imports, `go mod tidy` |
| See what's outdated | `go list -m -u all` (add `-json` for tooling) |
| Why is it here | `go mod why -m github.com/x/y`, `go mod graph \| grep x/y` |
| Vulnerabilities | `govulncheck ./...` (reachability-aware; install `golang.org/x/vuln/cmd/govulncheck`) |
| Verify integrity | `go mod verify` |
| Vendor | `go mod vendor` (only for hermetic builds / air-gapped CI; adds churn) |
| Tools | `go get -tool github.com/x/tool@v1`; run `go tool tool`; list `go tool` |
| Bump Go version | edit `go` line (or `go get go@1.27.0`), run tests, check `go vet`, update CI matrix and Dockerfile |

## Versioning your module

- Semantic import versioning: `v0.x` = anything can change; `v1.x` = compatible; `v2+` needs `/v2` suffix in module path and imports (`module github.com/acme/lib/v2`).
- Tag with `vX.Y.Z` (annotated tags); for sub-modules `subdir/vX.Y.Z`. Pseudo-versions (`v0.0.0-2026…-abcdef`) mean "untagged commit" — avoid publishing them as dependencies.
- Keep the public API small; use `internal/` freely. `apidiff` (`golang.org/x/exp/cmd/apidiff`) or `gorelease` to detect breaking changes before tagging.
- Deprecate with `// Deprecated:` comments and `retract` for broken versions.

## Dependency policy

- Prefer stdlib. Before adding a dep: maintenance activity, license (`go-licenses report ./...`), transitive count (`go list -m all | wc -l` before/after), binary size (`go build && ls -l`), is it just 30 lines you could write.
- Pin generators and linters via `tool` directives so every developer and CI produce identical output.
- Automate updates: Dependabot (`package-ecosystem: gomod`) or Renovate with grouped minor/patch PRs; still review changelogs of major bumps.
- Private modules: `GOPRIVATE=github.com/acme/*` (also disables sum DB for them); use `GONOSUMCHECK`/`GONOSUMDB` only when needed; CI needs credentials (SSH key or token via `git config url.…insteadOf`).
- `GOFLAGS=-mod=mod` locally if you want `go build` to update go.mod automatically; CI should run with the default `-mod=readonly` so drift fails.

## Reproducible builds

- `go.sum` committed; `GOFLAGS=-trimpath`; `-ldflags="-s -w -X main.version=$(git describe --tags)"` for version stamping; `CGO_ENABLED=0` for static binaries when no cgo.
- `go version -m ./bin/tool` reveals module versions and build settings inside a binary; use it in bug reports.
- Docker: copy `go.mod go.sum` first, `go mod download`, then sources — cache layers. Use `--mount=type=cache,target=/root/.cache/go-build` and `/go/pkg/mod`.
