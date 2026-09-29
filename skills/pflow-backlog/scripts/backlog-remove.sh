#!/usr/bin/env bash
# backlog-remove.sh — delete a backlog task file under docs/backlog.
# Accepts --name "<NNN-slug>" or --name "<slug>"; removes exactly one file.
# Prints one JSON line; errors as JSON fields, never on stderr.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SKILL_DIR/../../.." && pwd)"

json_escape() {
	local value="$1"
	value="${value//\\/\\\\}"
	value="${value//\"/\\\"}"
	value="${value//$'\n'/\\n}"
	value="${value//$'\r'/\\r}"
	value="${value//$'\t'/\\t}"
	printf '%s' "$value"
}

emit_error() {
	local step="$1" code="$2" msg="$3"
	printf '{"status":"error","error":{"step":"%s","exit_code":%d,"message":"%s"}}\n' \
		"$(json_escape "$step")" "$code" "$(json_escape "$msg")"
}

name=""
dir="docs/backlog"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--name|-n)
			if [[ $# -lt 2 ]]; then emit_error "usage" 1 "missing value for --name"; exit 1; fi
			name="${2:-}"; shift 2 ;;
		--dir|-d)
			if [[ $# -lt 2 ]]; then emit_error "usage" 1 "missing value for --dir"; exit 1; fi
			dir="${2:-}"; shift 2 ;;
		-h|--help)
			emit_error "usage" 1 'Usage: backlog-remove.sh --name "<NNN-slug|slug>" [--dir "<path>"]'; exit 1 ;;
		*)
			emit_error "usage" 1 "Unknown argument: $1"; exit 1 ;;
	esac
done

if [[ -z "$name" ]]; then
	emit_error "name" 1 "missing --name argument"; exit 1
fi

cd "$ROOT_DIR" || { emit_error "chdir" 1 "cannot enter project root: $ROOT_DIR"; exit 1; }

if [[ ! -d "$dir" ]]; then
	emit_error "not_found" 1 "backlog folder not found: $dir"; exit 1
fi

stem="${name%.md}"

target=""
if [[ -f "$dir/$stem.md" ]]; then
	target="$dir/$stem.md"
else
	matches=()
	shopt -s nullglob
	matches=("$dir"/*-"$stem".md)
	shopt -u nullglob
	if ((${#matches[@]} == 0)); then
		emit_error "not_found" 1 "no backlog task matches '$name' in $dir"; exit 1
	fi
	if ((${#matches[@]} > 1)); then
		list=""
		for m in "${matches[@]}"; do list+="${list:+, }$(basename "$m")"; done
		emit_error "ambiguous" 1 "multiple backlog tasks match '$name': $list"; exit 1
	fi
	target="${matches[0]}"
fi

dir_abs="$(cd "$dir" && pwd)"
resolved="$(cd "$(dirname "$target")" && pwd)/$(basename "$target")"
case "$resolved" in
	"$dir_abs"/*) ;;
	*) emit_error "guard" 1 "refusing to remove outside $dir: $target"; exit 1 ;;
esac

base="$(basename "$target")"
num="${base%%-*}"

if ! rm -f -- "$target"; then
	emit_error "remove" 1 "cannot remove task file: $target"; exit 1
fi

printf '{"status":"ok","removed":"%s","number":"%s"}\n' \
	"$(json_escape "$target")" "$(json_escape "$num")"
