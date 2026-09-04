# golangci-lint v2 configuration

Install pinned: `go get -tool github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest` → `go tool golangci-lint run` (slow first build) — or the official install script / binary with the version written in the task runner and CI. v1 configs must be migrated: `golangci-lint migrate`.

## Recommended `.golangci.yml`

```yaml
version: "2"

run:
  timeout: 5m
  tests: true
  build-tags: [e2e]          # lint tagged tests too; drop if none

linters:
  default: standard          # errcheck, govet, ineffassign, staticcheck, unused
  enable:
    # correctness
    - bodyclose              # HTTP response bodies closed
    - copyloopvar            # redundant loop var copies (Go ≥ 1.22)
    - durationcheck          # Duration * Duration
    - errorlint              # %w, errors.Is/As instead of == and type assertions
    - errname                # ErrX / XError naming
    - exhaustive             # enum switches cover all cases
    - fatcontext             # ctx re-wrapped in loops
    - forcetypeassert        # single-value type assertions
    - gosec                  # security smells
    - nilerr                 # return nil when err != nil
    - nilnil                 # (nil, nil) returns
    - noctx                  # HTTP/SQL calls without context
    - rowserrcheck; sqlclosecheck
    - testifylint            # correct testify usage
    - thelper                # t.Helper() in helpers
    - usetesting             # t.TempDir, t.Setenv, t.Context
    - wastedassign
    # style / maintainability
    - gocritic
    - godot                  # comments end with a period
    - misspell
    - nolintlint             # every nolint has a linter and a reason
    - revive
    - unconvert
    - unparam
    - modernize              # apply modern stdlib (if available in this version)
    - intrange
    - perfsprint
    - prealloc
  settings:
    errcheck:
      check-type-assertions: true
    govet:
      enable-all: true
      disable: [fieldalignment, shadow]   # enable shadow if the team wants it
    gocritic:
      enabled-tags: [diagnostic, performance]
    revive:
      rules:
        - name: exported
          arguments: [checkPrivateReceivers, disableStutteringCheck]
    nolintlint:
      require-explanation: true
      require-specific: true
    staticcheck:
      checks: ["all", "-ST1000"]  # ST1000 package comment — enable when docs matter
  exclusions:
    generated: lax
    presets: [common-false-positives, std-error-handling]
    paths: ['.*\.pb\.go$', 'gen/', 'mocks/']
    rules:
      - path: _test\.go
        linters: [gosec, forcetypeassert, unparam]

formatters:
  enable: [gofumpt, goimports]   # or gofmt only
  settings:
    goimports:
      local-prefixes: [github.com/acme/tool]

issues:
  max-issues-per-linter: 0
  max-same-issues: 0
```

Remove `rowserrcheck; sqlclosecheck` if no `database/sql`; remove `modernize` if the installed golangci-lint predates it (`golangci-lint help linters | grep modernize`). Start strict on a new project; on an existing one enable in batches and use `--new-from-rev=origin/main` to lint only changes while paying down the backlog.

## Running

- `golangci-lint run ./...`; `--fix` applies formatters and auto-fixable linters; `--new-from-rev=HEAD~1` for incremental; `-v` to see timing; `--out-format` unnecessary in v2 (use `output.formats`).
- Format only: `golangci-lint fmt ./...` (v2). Check without writing: `golangci-lint fmt --diff`.
- Cache lives in `~/.cache/golangci-lint`; in CI use the official action with caching or cache that dir.
- Pre-commit: run `golangci-lint run --new-from-rev=HEAD --fix` on staged Go files (lefthook/pre-commit); keep the full run for `task check` and CI.

## `nolint` policy

- Form: `//nolint:gosec // G304: path is validated above` — specific linter, reason, on the offending line (or above a declaration). `nolintlint` rejects bare `//nolint`.
- Prefer fixing or configuring an exclusion rule (path/text based) over per-line suppressions when the pattern is systemic.
- Never suppress `errcheck`, `govet`, `staticcheck` SA* without explaining the invariant that makes it safe.

## Pairing linters with the code

- `errorlint` + `errname` enforce `errors-safety.md`; `testifylint` + `thelper` + `usetesting` enforce `testing.md`; `modernize` + `intrange` + `copyloopvar` enforce `modernize.md`; `gosec` + `noctx` + `bodyclose` enforce `security.md`.
- `exhaustive` requires typed enums; `revive exported` requires doc comments on exported symbols — decide once in the project.
- Speed: `run.concurrency`, disable `gocritic` `experimental` tag, exclude generated directories; a full run should stay under a few minutes.
