# Task runner: one gate, run everywhere

Rule: `task check` (or `make check`) runs every quality step in order and is exactly what CI runs. Steps fail fast, are idempotent, and need no arguments.

## Taskfile (`Taskfile.yml`, taskfile.dev)

```yaml
version: '3'

vars:
  BIN: tool
  VERSION:
    sh: git describe --tags --always --dirty 2>/dev/null || echo dev
  LDFLAGS: -s -w -X main.version={{.VERSION}}
  COVER_PKGS: ./internal/...

env:
  CGO_ENABLED: '0'

tasks:
  default: { cmds: [task --list] }

  build:
    desc: Build binary into tmp/
    cmds: [go build -trimpath -ldflags "{{.LDFLAGS}}" -o tmp/{{.BIN}} ./cmd/{{.BIN}}]
    sources: ['**/*.go', go.mod, go.sum]
    generates: [tmp/{{.BIN}}]

  install:
    cmds: [go install -trimpath -ldflags "{{.LDFLAGS}}" ./cmd/{{.BIN}}]

  fmt:        { cmds: [go tool golangci-lint fmt ./...] }          # or: gofmt -w . && goimports -w .
  fmt-check:  { cmds: [go tool golangci-lint fmt --diff ./...] }
  vet:        { cmds: [go vet ./...] }
  lint:       { cmds: [go tool golangci-lint run ./...] }
  tidy-check: { cmds: [go mod tidy -diff] }

  test:
    cmds: [go test -count=1 -shuffle=on ./...]
  test-race:
    env: { CGO_ENABLED: '1' }                # race detector needs cgo on most platforms
    cmds: [go test -count=1 -race ./...]
  test-e2e:
    desc: Black-box tests; needs the backend running
    cmds: [go test -count=1 -tags e2e -v ./tests/e2e/...]
  coverage:
    cmds:
      - go test -count=1 -coverprofile=tmp/cover.out -coverpkg={{.COVER_PKGS}} {{.COVER_PKGS}}
      - go tool cover -func=tmp/cover.out | tail -1
      - |
        pct=$(go tool cover -func=tmp/cover.out | tail -1 | grep -Eo '[0-9.]+%' | tr -d %)
        awk -v p="$pct" 'BEGIN{ if (p+0 < 80) { print "coverage " p "% < 80%"; exit 1 } }'
  bench:
    cmds: [go test -run '^$' -bench . -benchmem ./...]

  generate:
    desc: Regenerate code (mocks, proto, stringer)
    cmds: [go generate ./..., go tool mockery]
  generate-check:
    cmds: [task: generate, git diff --exit-code -- '*.go']

  vuln:  { cmds: [go run golang.org/x/vuln/cmd/govulncheck@latest ./...] }

  check:
    desc: Full quality gate (what CI runs)
    cmds:
      - task: fmt-check
      - task: tidy-check
      - task: vet
      - task: lint
      - task: test-race
      - task: coverage

  clean: { cmds: [rm -rf tmp/ dist/] }
```

- Keep `tmp/` (or `bin/`) gitignored. `sources`/`generates` make `build` incremental.
- Pin tool versions via `go tool` so `task lint` is identical for everyone; if a binary is required instead, check it in the task (`command -v golangci-lint || …`).
- E2E and anything needing external services stays out of `check`; CI runs it as a separate job with the service.

## Makefile equivalent

```make
BIN     := tool
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LDFLAGS := -s -w -X main.version=$(VERSION)
PKGS    := ./...
export CGO_ENABLED ?= 0

.PHONY: build install fmt fmt-check vet lint tidy-check test test-race coverage generate generate-check check clean

build:        ; go build -trimpath -ldflags "$(LDFLAGS)" -o bin/$(BIN) ./cmd/$(BIN)
install:      ; go install -trimpath -ldflags "$(LDFLAGS)" ./cmd/$(BIN)
fmt:          ; go tool golangci-lint fmt $(PKGS)
fmt-check:    ; go tool golangci-lint fmt --diff $(PKGS)
vet:          ; go vet $(PKGS)
lint:         ; go tool golangci-lint run $(PKGS)
tidy-check:   ; go mod tidy -diff
test:         ; go test -count=1 -shuffle=on $(PKGS)
test-race:    ; CGO_ENABLED=1 go test -count=1 -race $(PKGS)
coverage:     ; go test -count=1 -coverprofile=coverage.out ./internal/... && go tool cover -func=coverage.out | tail -1
generate:     ; go generate $(PKGS) && go tool mockery
generate-check: generate ; git diff --exit-code -- '*.go'
check: fmt-check tidy-check vet lint test-race coverage
clean:        ; rm -rf bin/ dist/ coverage.out
```

Tabs, not spaces, for recipe lines. `.PHONY` everything that isn't a file.

## Conventions

- Names: `build`, `test`, `test-race`, `lint`, `fmt`, `check`, `generate`, `clean` — same across all Go projects so muscle memory works.
- Every target prints nothing on success beyond the tools' own output; failures exit non-zero.
- Coverage thresholds apply to an allowlist of packages with logic, not to `cmd/` or generated code.
- Document the runner in `AGENTS.md`/`README.md` with a two-column table: task → command. Agents and humans read the same table.
- `.pre-commit` or `lefthook.yml`: `fmt` + `lint --new-from-rev=HEAD --fix` on staged files; never the full `check` (too slow for commits).
