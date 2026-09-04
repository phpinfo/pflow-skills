#!/usr/bin/env bash
# troubleshoot-context.sh — collects the debugging environment of the consuming
# Go project (toolchain, available debug tools, test entry points) as one JSON
# line. Read-only: never builds or runs tests.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SKILL_DIR/../../.." && pwd)"

json_escape() {
	local v="$1"
	v="${v//\\/\\\\}"; v="${v//\"/\\\"}"; v="${v//$'\n'/\\n}"; v="${v//$'\r'/\\r}"; v="${v//$'\t'/\\t}"
	printf '%s' "$v"
}
emit_error() {
	printf '{"status":"error","error":{"step":"%s","exit_code":%d,"message":"%s"}}\n' \
		"$(json_escape "$1")" "$2" "$(json_escape "$3")"
}
json_str() { if [[ -z "$1" ]]; then printf 'null'; else printf '"%s"' "$(json_escape "$1")"; fi; }
json_arr() { local out="" x; for x in "$@"; do [[ -n "$x" ]] && out+="${out:+,}\"$(json_escape "$x")\""; done; printf '[%s]' "$out"; }

gomod="$ROOT_DIR/go.mod"
[[ -f "$gomod" ]] || { emit_error "go.mod" 1 "go.mod not found at $ROOT_DIR — not a Go module root"; exit 1; }
command -v go >/dev/null 2>&1 || { emit_error "go" 1 "go binary not found in PATH"; exit 1; }

module="$(awk '$1=="module"{print $2; exit}' "$gomod")"
go_mod_version="$(awk '$1=="go"{print $2; exit}' "$gomod")"
toolchain="$(go version 2>/dev/null | awk '{print $3}')"
goos="$(go env GOOS)"; goarch="$(go env GOARCH)"
cgo="$(go env CGO_ENABLED)"; goflags="$(go env GOFLAGS)"; gotoolchain="$(go env GOTOOLCHAIN)"

tools=()
for t in dlv golangci-lint gotestsum benchstat dot staticcheck govulncheck; do
	command -v "$t" >/dev/null 2>&1 && tools+=("$t")
done

runner=""
for f in Taskfile.yml Taskfile.yaml Makefile justfile; do [[ -f "$ROOT_DIR/$f" ]] && runner="$f" && break; done
targets=()
case "$runner" in
	Taskfile.yml|Taskfile.yaml)
		while IFS= read -r t; do targets+=("$t"); done < <(awk '/^tasks:/{b=1;next} b&&/^[^ ]/{b=0} b&&/^  [A-Za-z0-9_:-]+:/{gsub(/^  |:$/,"");print}' "$ROOT_DIR/$runner" | grep -Ei 'test|race|lint|check|vet|bench|e2e|cover' ) ;;
	Makefile)
		while IFS= read -r t; do targets+=("$t"); done < <(grep -Eo '^[A-Za-z0-9_-]+:' "$ROOT_DIR/Makefile" | tr -d ':' | grep -Ei 'test|race|lint|check|vet|bench|e2e|cover') ;;
	justfile)
		while IFS= read -r t; do targets+=("$t"); done < <(grep -Eo '^[A-Za-z0-9_-]+' "$ROOT_DIR/justfile" | grep -Ei 'test|race|lint|check|vet|bench|e2e|cover') ;;
esac

test_files="$(find "$ROOT_DIR" -name '*_test.go' -not -path '*/vendor/*' -not -path '*/.git/*' 2>/dev/null | wc -l | tr -d ' ')"
test_dirs=()
for d in tests test e2e testdata integration; do [[ -d "$ROOT_DIR/$d" ]] && test_dirs+=("$d"); done
build_tags="$(grep -rhoI --include='*_test.go' --exclude-dir=vendor '^//go:build .*' "$ROOT_DIR" 2>/dev/null | sort -u | sed 's#^//go:build ##' | tr '\n' ' ' | sed 's/ $//')"
has_testify=0; grep -q 'github.com/stretchr/testify' "$gomod" && has_testify=1
has_race_hint=""; [[ "$cgo" == "0" ]] && has_race_hint="CGO_ENABLED=0 — -race may need CGO_ENABLED=1 on this platform"

printf '{"status":"ok","root":%s,"module":%s,"go_mod_version":%s,"toolchain":%s,"goos":%s,"goarch":%s,"cgo_enabled":%s,"goflags":%s,"gotoolchain":%s,"debug_tools":%s,"task_runner":%s,"test_targets":%s,"test_files":%s,"test_dirs":%s,"test_build_tags":%s,"testify":%s,"hint":%s}\n' \
	"$(json_str "$ROOT_DIR")" "$(json_str "$module")" "$(json_str "$go_mod_version")" "$(json_str "$toolchain")" \
	"$(json_str "$goos")" "$(json_str "$goarch")" "$(json_str "$cgo")" "$(json_str "$goflags")" "$(json_str "$gotoolchain")" \
	"$(json_arr "${tools[@]:-}")" "$(json_str "$runner")" "$(json_arr "${targets[@]:-}")" "$test_files" \
	"$(json_arr "${test_dirs[@]:-}")" "$(json_str "$build_tags")" "$( ((has_testify)) && printf true || printf false)" "$(json_str "$has_race_hint")"
