#!/usr/bin/env bash
# go-stack.sh — detects the Go toolchain, direct dependencies and tooling of the
# consuming project and prints one JSON line. Read-only.
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
json_arr() { local out="" x; for x in "$@"; do out+="${out:+,}\"$(json_escape "$x")\""; done; printf '[%s]' "$out"; }

gomod="$ROOT_DIR/go.mod"
[[ -f "$gomod" ]] || { emit_error "go.mod" 1 "go.mod not found at $ROOT_DIR — not a Go module root"; exit 1; }

module="$(awk '$1=="module"{print $2; exit}' "$gomod")"
go_version="$(awk '$1=="go"{print $2; exit}' "$gomod")"
toolchain="$(command -v go >/dev/null 2>&1 && go version 2>/dev/null | awk '{print $3}')"

# Direct requires only (drop "// indirect").
direct="$(awk '
	/^require \(/ {inblock=1; next}
	inblock && /^\)/ {inblock=0; next}
	inblock && !/\/\/ indirect/ && NF>=2 {print $1}
	/^require [^(]/ && !/\/\/ indirect/ {print $2}
' "$gomod")"
tools="$(awk '$1=="tool" && $2!="("{print $2} /^tool \(/{b=1;next} b&&/^\)/{b=0} b{print $1}' "$gomod")"
has_dep() { grep -qx -- "$1" <<<"$direct"; }
has_dep_prefix() { grep -q -- "^$1" <<<"$direct"; }

cli=""
has_dep_prefix "github.com/urfave/cli/v3" && cli="urfave/cli/v3"
[[ -z "$cli" ]] && has_dep_prefix "github.com/urfave/cli/v2" && cli="urfave/cli/v2"
[[ -z "$cli" ]] && has_dep "github.com/spf13/cobra" && cli="cobra"
[[ -z "$cli" ]] && has_dep "github.com/alecthomas/kong" && cli="kong"

rpc=""
has_dep "connectrpc.com/connect" && rpc="connect"
[[ -z "$rpc" ]] && has_dep "google.golang.org/grpc" && rpc="grpc"

testing=()
has_dep "github.com/stretchr/testify" && testing+=("testify")
mockery_cfg=""
for f in .mockery.yml .mockery.yaml; do [[ -f "$ROOT_DIR/$f" ]] && mockery_cfg="$f" && break; done
if [[ -n "$mockery_cfg" ]] || grep -q "github.com/vektra/mockery" <<<"$direct$tools" \
	|| grep -rIl --include='*.go' --exclude-dir=vendor --exclude-dir=.git -m1 'go:generate.*mockery' "$ROOT_DIR" >/dev/null 2>&1; then
	testing+=("mockery")
fi
has_dep "go.uber.org/mock" && testing+=("gomock")
has_dep "github.com/google/go-cmp" && testing+=("go-cmp")

other=()
has_dep "github.com/samber/lo" && other+=("samber/lo")
has_dep "golang.org/x/sync" && other+=("x/sync")
has_dep "github.com/samber/oops" && other+=("samber/oops")

golangci=""
for f in .golangci.yml .golangci.yaml .golangci.toml .golangci.json; do [[ -f "$ROOT_DIR/$f" ]] && golangci="$f" && break; done
runner=""
for f in Taskfile.yml Taskfile.yaml Makefile justfile; do [[ -f "$ROOT_DIR/$f" ]] && runner="$f" && break; done
gowork=0; [[ -f "$ROOT_DIR/go.work" ]] && gowork=1

# Library references shipped with this skill, selected by detected stack.
refs=()
[[ "$cli" == urfave/cli* ]] && refs+=("references/lib-urfave-cli.md")
[[ "$rpc" == "connect" ]] && refs+=("references/lib-connect.md")
for t in "${testing[@]:-}"; do
	[[ "$t" == "testify" ]] && refs+=("references/lib-testify.md")
	[[ "$t" == "mockery" ]] && refs+=("references/lib-mockery.md")
done
for o in "${other[@]:-}"; do [[ "$o" == "samber/lo" ]] && refs+=("references/lib-samber-lo.md"); done

printf '{"status":"ok","root":%s,"module":%s,"go_version":%s,"toolchain":%s,"cli":%s,"rpc":%s,"testing":%s,"other":%s,"golangci_config":%s,"task_runner":%s,"go_work":%s,"lib_references":%s}\n' \
	"$(json_str "$ROOT_DIR")" "$(json_str "$module")" "$(json_str "$go_version")" "$(json_str "$toolchain")" \
	"$(json_str "$cli")" "$(json_str "$rpc")" "$(json_arr "${testing[@]:-}")" "$(json_arr "${other[@]:-}")" \
	"$(json_str "$golangci")" "$(json_str "$runner")" "$( ((gowork)) && printf true || printf false)" "$(json_arr "${refs[@]:-}")"
