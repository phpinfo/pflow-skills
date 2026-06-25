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

if ! command -v mdtodo >/dev/null 2>&1; then
	emit_error "mdtodo" 12 "mdtodo CLI is not available"; exit 12
fi

load_dotenv "$ROOT_DIR/.env"

mdtodo_file="${PFLOW_TASKS_MDTODO_FILE:-${MDTODO_FILE:-todo.md}}"

if [[ ! -f "$mdtodo_file" ]]; then
	emit_error "tasks_file" 1 "tasks file not found: $mdtodo_file"; exit 1
fi

set +e
current_task="$(mdtodo current --file "$mdtodo_file" 2>&1)"
current_exit=$?
set -e

if [[ "$current_exit" -ne 0 ]]; then
	emit_error "mdtodo current" "$current_exit" "$current_task"
	exit "$current_exit"
fi

current_task="${current_task#"${current_task%%[![:space:]]*}"}"
current_task="${current_task%"${current_task##*[![:space:]]}"}"

if [[ -z "$current_task" ]]; then
	emit_error "active_task" 1 "no active task found in $mdtodo_file"; exit 1
fi

# Surrounding tasks: 2 completed before the active task, 2 pending after it.
set +e
list_output="$(mdtodo list --file "$mdtodo_file" --format plain 2>&1)"
list_exit=$?
set -e

if [[ "$list_exit" -ne 0 ]]; then
	emit_error "mdtodo list" "$list_exit" "$list_output"; exit "$list_exit"
fi

json_array() {
	local out="[" first=1 t
	for t in "$@"; do
		[[ "$first" -eq 1 ]] && first=0 || out+=","
		out+="\"$(json_escape "$t")\""
	done
	printf '%s]' "$out"
}

statuses=()
titles=()
active_idx=-1
i=0
while IFS= read -r line || [[ -n "$line" ]]; do
	[[ -z "$line" ]] && continue
	st="${line%%;*}"          # status
	rest="${line#*;}"         # version;title
	ttl="${rest#*;}"          # title (keeps any ';' it contains)
	statuses+=("$st")
	titles+=("$ttl")
	[[ "$active_idx" -eq -1 && "$st" == "in_progress" ]] && active_idx="$i"
	i=$((i + 1))
done <<< "$list_output"

prev=()
next=()
if [[ "$active_idx" -ge 0 ]]; then
	j=$((active_idx - 1))
	while [[ "$j" -ge 0 && "${#prev[@]}" -lt 2 ]]; do
		[[ "${statuses[$j]}" == "completed" ]] && prev=("${titles[$j]}" ${prev[@]+"${prev[@]}"})
		j=$((j - 1))
	done
	total="${#statuses[@]}"
	k=$((active_idx + 1))
	while [[ "$k" -lt "$total" && "${#next[@]}" -lt 2 ]]; do
		[[ "${statuses[$k]}" == "pending" ]] && next+=("${titles[$k]}")
		k=$((k + 1))
	done
fi

prev_json="$(json_array ${prev[@]+"${prev[@]}"})"
next_json="$(json_array ${next[@]+"${next[@]}"})"

printf '{"status":"ok","current_task":"%s","previous_tasks":%s,"next_tasks":%s}\n' \
	"$(json_escape "$current_task")" "$prev_json" "$next_json"
