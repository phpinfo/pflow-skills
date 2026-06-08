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
	printf '{"error":{"step":"%s","exit_code":%d,"message":"%s"}}\n' \
		"$(json_escape "$step")" "$code" "$(json_escape "$msg")"
	exit "$code"
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

cd "$ROOT_DIR" || emit_error "chdir" 1 "cannot enter repo root: $ROOT_DIR"

load_dotenv "$ROOT_DIR/.env"

if ! command -v git >/dev/null 2>&1; then
	emit_error "git" 10 "git binary is not available"
fi

if ! command -v mdtodo >/dev/null 2>&1; then
	emit_error "mdtodo" 11 "mdtodo CLI is not available"
fi

if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
	emit_error "git status" 2 "working tree has uncommitted changes"
fi

dev_branch="${PFLOW_GIT_DEV_BRANCH:-dev}"
current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
if [[ "$current_branch" != "$dev_branch" ]]; then
	emit_error "branch" 3 "current branch '$current_branch' is not '$dev_branch'"
fi

if [[ -z "${PFLOW_FEATURES_MDTODO_FILE:-}" ]]; then
	emit_error "env" 4 "PFLOW_FEATURES_MDTODO_FILE is not set"
fi

export MDTODO_FILE="$PFLOW_FEATURES_MDTODO_FILE"

set +e
feature_json="$(mdtodo current --format json 2>/dev/null)"
current_exit=$?
set -e
feature_json="$(printf '%s' "$feature_json" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [[ "$current_exit" -ne 0 || -z "$feature_json" || "$feature_json" == "null" ]]; then
	emit_error "feature" 5 "no current feature found in $PFLOW_FEATURES_MDTODO_FILE"
fi

feature_plain="$(mdtodo current --format plain 2>/dev/null)"
rest="${feature_plain#*;}"
feature_version="${rest%%;*}"
feature_version="$(printf '%s' "$feature_version" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
feature_title="${rest#*;}"
feature_title="$(printf '%s' "$feature_title" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [[ -z "$feature_version" ]]; then
	emit_error "feature" 6 "current feature has no version number"
fi

unset MDTODO_FILE

if [[ -n "${PFLOW_TASKS_MDTODO_FILE:-}" ]]; then
	export MDTODO_FILE="$PFLOW_TASKS_MDTODO_FILE"
fi

set +e
tasks_json="$(mdtodo list --format json 2>/dev/null)"
tasks_exit=$?
set -e

if [[ "$tasks_exit" -ne 0 ]]; then
	tasks_json="[]"
fi

set +e
git_log="$(git --no-pager log --no-merges --reverse --pretty=format:'- %s%n%b' master..HEAD 2>/dev/null)"
log_exit=$?
set -e

if [[ "$log_exit" -ne 0 || -z "$git_log" ]]; then
	git_log=""
fi

printf '{"feature":{"title":"%s","version":"%s"},"tasks":%s,"commits":"%s"}\n' \
	"$(json_escape "$feature_title")" \
	"$(json_escape "$feature_version")" \
	"${tasks_json:-[]}" \
	"$(json_escape "$git_log")"
