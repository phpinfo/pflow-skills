# GitHub Actions for Go

Principles: CI runs the same gate as local (`task check`); pin action majors; cache modules; run e2e separately; fail on `go.mod`/generated drift; least-privilege permissions.

## `.github/workflows/ci.yml`

```yaml
name: ci
on:
  push: { branches: [main, dev] }
  pull_request:
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
permissions:
  contents: read

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod       # follows the go/toolchain lines
          cache: true                   # caches ~/go/pkg/mod and build cache
      - uses: arduino/setup-task@v2     # or go-task/setup-task; skip for Makefile
        with: { repo-token: ${{ secrets.GITHUB_TOKEN }} }
      - run: task check                 # fmt-check, tidy-check, vet, lint, test-race, coverage
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: coverage, path: tmp/cover.out, if-no-files-found: ignore }

  # Lint via the official action instead of `go tool` when the binary is not pinned in go.mod:
  # - uses: golangci/golangci-lint-action@v8
  #   with: { version: v2.5.0 }         # pin; keep in sync with the task runner

  matrix:                                # libraries: test on supported Go versions and OSes
    if: false                            # enable for libraries
    strategy:
      matrix:
        go: ['1.25', '1.26']
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: ${{ matrix.go }}, cache: true }
      - run: go test -count=1 -race ./...

  e2e:
    needs: check
    runs-on: ubuntu-latest
    services:                            # or docker compose up in a step
      postgres:
        image: postgres:17
        env: { POSTGRES_PASSWORD: test }
        ports: ['5432:5432']
        options: --health-cmd pg_isready --health-interval 5s --health-retries 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version-file: go.mod, cache: true }
      - run: go test -count=1 -tags e2e -v ./tests/e2e/...
        env: { E2E_DB_URL: postgres://postgres:test@localhost:5432/postgres?sslmode=disable }

  vuln:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version-file: go.mod, cache: true }
      - run: go run golang.org/x/vuln/cmd/govulncheck@latest ./...
```

- `go-version-file: go.mod` keeps CI and `go.mod` in lockstep. For a `toolchain` line, setup-go honors it.
- Cache key is derived from `go.sum` automatically with `cache: true`; add `cache-dependency-path` for multi-module repos.
- Windows runners: set `git config core.autocrlf false` before checkout if `gofmt`/golden files differ.
- Don't run `-race` on Windows/macOS matrices unless needed (slow); run it on Linux.

## Release (`.github/workflows/release.yml`) with GoReleaser

```yaml
name: release
on: { push: { tags: ['v*'] } }
permissions: { contents: write, packages: write, id-token: write }
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: actions/setup-go@v5
        with: { go-version-file: go.mod, cache: true }
      - uses: goreleaser/goreleaser-action@v6
        with: { version: '~> v2', args: release --clean }
        env: { GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }} }
```

Minimal `.goreleaser.yaml`: `version: 2`, `builds: [{ main: ./cmd/tool, env: [CGO_ENABLED=0], goos: [linux, darwin, windows], goarch: [amd64, arm64], ldflags: ['-s -w -X main.version={{.Version}}'] }]`, `archives`, `checksum`, `changelog: { use: github }`. Add `brews`/`nfpms`/`dockers` only when distributing that way. Sign with cosign (`signs`) for public tools.

## Dependency updates

`.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: gomod
    directory: /
    schedule: { interval: weekly }
    groups: { go-deps: { patterns: ['*'], update-types: [minor, patch] } }
  - package-ecosystem: github-actions
    directory: /
    schedule: { interval: weekly }
```

Renovate alternative: `renovate.json` with `"extends": ["config:recommended", ":semanticCommits", "group:allNonMajor"]`, `"postUpdateOptions": ["gomodTidy", "gomodUpdateImportPaths"]`.

## Security and hygiene

- `permissions: contents: read` at the top; grant more per job only. Use `${{ secrets.X }}` never echoed; mask outputs.
- Pin third-party actions to a major (`@v5`) at least; to a SHA for supply-chain-sensitive repos (Renovate/Dependabot keep SHAs fresh).
- CodeQL: `github/codeql-action` with `languages: go` for public repos; `gosec` runs already via golangci-lint.
- Branch protection: require `check` (and `e2e` if reliable) before merge; `concurrency` cancels stale PR runs.
- Fail on drift: `go mod tidy -diff` and `task generate-check` are part of `check`, so stale `go.sum` or generated code cannot merge.
- Keep job time under ~10 min: cache, `-short` in PRs with the full suite on `main` if necessary, split e2e.

## Other hosts

GitLab: `image: golang:1.26`, cache `key: { files: [go.sum] }` paths `.go/pkg/mod`, stages `check` → `e2e` → `release` running the same `task check`. The task runner keeps the pipeline definition tiny regardless of host.
