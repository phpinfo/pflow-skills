# Project layout

Start flat; add directories when a second thing of the same kind appears. The Go team's guidance (go.dev/doc/modules/layout) beats "standard project layout" templates.

## Shapes

| Project | Layout |
| --- | --- |
| Library | `go.mod` at root, package in root (`import "github.com/acme/lib"`), sub-packages as needed, `internal/` for helpers, `examples/` optional |
| Single CLI/service | `cmd/<name>/main.go` (thin) + `internal/...` (all logic). Or `main.go` at root when there will be only one binary and it's tiny |
| Several binaries | `cmd/<a>/`, `cmd/<b>/`, shared code in `internal/` |
| Library + CLI | root package = library API, `cmd/<tool>/` = CLI using it, `internal/` for non-public code |
| Monorepo of services | one module per service or one module with `go.work` for local dev; shared libs as their own module with tags |

## Directories

- `cmd/<binary>/main.go` — parse flags/config, build dependencies, call `run(ctx, cfg) error`, exit code. No business logic.
- `internal/` — everything not importable by other modules. Name packages by what they provide: `internal/config`, `internal/storage/postgres`, `internal/api/http`, `internal/usecase` (application services), `internal/models` only if truly shared data types (prefer types living with their owner).
- `pkg/` — only for code deliberately importable by others; most projects don't need it. If unsure, use `internal/`.
- `api/` — proto/OpenAPI definitions and generated clients when the API is a first-class artifact (`api/proto`, `api/gen`).
- `tests/` or `test/` — black-box/e2e tests and their fixtures, behind a build tag; unit tests stay next to code.
- `testdata/` — ignored by the toolchain; per-package fixtures and golden files.
- `scripts/` — repo automation not worth a Go program; prefer task runner targets calling `go run ./tools/...`.
- `tools/` or `go tool` directives — dev tools; with Go ≥ 1.24 use `tool` in `go.mod` and drop `tools.go`.
- `docs/`, `deploy/`, `configs/`, `build/` (Dockerfiles, packaging) as needed. `tmp/`/`bin/`/`dist/` gitignored.
- Never: `src/`, `common/`, `util/`, `helpers/`, `models/` catch-alls, `pkg/` as a dumping ground, deeply nested `internal/pkg/x/y/z` for one file.

## Package design

- Package = one cohesive concept with a small exported surface. Fewer, larger packages beat many tiny ones; split when a package needs two different sets of dependencies or two teams own it.
- Dependencies point inward: `cmd` → `internal/api` → `internal/usecase` → `internal/domain`; storage/transport implement interfaces defined by the layer that uses them. No cycles by construction.
- File per concept inside a package (`user.go`, `user_repo.go`, `user_test.go`); `doc.go` for the package comment when the package is large.
- `main` packages import `internal/...`; nothing imports `main`.
- Generated code in its own package/directory (`gen/`, `*pb.go`) with a `// Code generated` header; never mixed with hand-written files.

## Configuration

- Precedence: flags > env > config file > defaults; one `Config` struct, one `Load()` function, validated once at startup. Secrets only via env/secret manager.
- Default config path in the user's home for CLIs (`~/.tool.yml`); XDG dirs (`os.UserConfigDir()`) when being polite.
- Keep parsing (`flag`, `urfave/cli`, `cobra`, `env`, `yaml`) in `cmd/` or `internal/config`; the rest of the code receives typed values.

## Workspaces and multi-module

- `go.work` for local development across modules; **don't commit** it unless the whole team works that way (add `go.work*` to `.gitignore` otherwise). CI builds each module standalone (`GOWORK=off`).
- Tag sub-modules with their path prefix: `git tag lib/v1.2.0`.
- Nested modules only when release cadence or dependency footprint truly differs; otherwise one module.

## Minimal starting tree (service or CLI)

```
.
├── cmd/<name>/main.go
├── internal/
│   ├── config/config.go
│   ├── <domain>/...
│   └── <adapter>/...
├── testdata/
├── go.mod  go.sum
├── Taskfile.yml (or Makefile)
├── .golangci.yml
├── .gitignore  .editorconfig  README.md  LICENSE
└── .github/workflows/ci.yml
```

## `.gitignore` for Go

```
/bin/
/dist/
/tmp/
*.test
*.out
*.prof
coverage.*
go.work
go.work.sum
.env
.DS_Store
.idea/  .vscode/  (unless shared settings are intended)
```

## `.editorconfig`

```
root = true
[*]
end_of_line = lf
insert_final_newline = true
charset = utf-8
trim_trailing_whitespace = true
[*.go]
indent_style = tab
[*.{yml,yaml,json,md}]
indent_style = space
indent_size = 2
[Makefile]
indent_style = tab
```
