#!/usr/bin/env bash

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

load_dotenv() {
	local env_file="$1"
	[[ -f "$env_file" ]] || return 0
	local line key val
	while IFS= read -r line || [[ -n "$line" ]]; do
		line="${line%$'\r'}"
		line="${line#"${line%%[![:space:]]*}"}"
		[[ -z "$line" || "${line:0:1}" == "#" ]] && continue
		[[ "$line" == export\ * ]] && line="${line#export }"
		[[ "$line" == *=* ]] || continue
		key="${line%%=*}"
		val="${line#*=}"
		key="${key%"${key##*[![:space:]]}"}"
		[[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
		case "$val" in
			\"*\") val="${val:1:${#val}-2}" ;;
			\'*\") val="${val:1:${#val}-2}" ;;
		esac
		[[ -n "${!key+x}" ]] && continue
		export "$key=$val"
	done < "$env_file"
}

cd "$ROOT_DIR" || { emit_error "chdir" 1 "cannot enter repo root: $ROOT_DIR"; exit 1; }

load_dotenv "$ROOT_DIR/.env"

plan_filename="${PFLOW_TASKS_PLAN_FILE:-./tmp/pflow-tasks-plan.md}"

if [[ -t 0 ]]; then
	emit_error "stdin" 1 "stdin is interactive; pass the full plan non-interactively via a quoted heredoc, e.g. plan-save.sh <<'__PFLOW_PLAN_EOF__' ... __PFLOW_PLAN_EOF__"; exit 1
fi

content="$(cat)"

if [[ -z "${content//[[:space:]]/}" ]]; then
	emit_error "content" 1 "empty plan content on stdin"; exit 1
fi

plan_dir="$(dirname "$plan_filename")"
mkdir -p "$plan_dir" || { emit_error "mkdir" 1 "cannot create directory: $plan_dir"; exit 1; }

printf '%s\n' "$content" > "$plan_filename" || {
	emit_error "write" 1 "cannot write plan file: $plan_filename"; exit 1
}

bytes="$(wc -c < "$plan_filename" | tr -d ' ')"

printf '{"status":"ok","plan_filename":"%s","bytes":%s}\n' \
	"$(json_escape "$plan_filename")" "$bytes"
