#!/usr/bin/env bash

# task-next-context.sh — prepare context for starting the next mdtodo task.
#
# Guards the preconditions, then takes the next task into progress and returns
# its data so the agent can name a branch. Emits ONE JSON line:
#   {"status":"ready","task":{...}}   — task taken, agent should name a branch
#   {"status":"no_tasks"}             — nothing left to take, stop cleanly
#   {"status":"error","error":{...}}  — a precondition failed

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# Consuming repo root: three levels up from SKILL_DIR once installed.
ROOT_DIR="$(cd "$SKILL_DIR/../../.." && pwd)"

tf_escape() {
	local value="$1"
	value="${value//\\/\\\\}"
	value="${value//\"/\\\"}"
	value="${value//$'\n'/\\n}"
	value="${value//$'\r'/\\r}"
	value="${value//$'\t'/\\t}"
	printf '%s' "$value"
}

emit_error() {
	# emit_error <step> <exit_code> <message>
	local step="$1" code="$2" msg="$3"
	printf '{"status":"error","error":{"step":"%s","exit_code":%d,"message":"%s"}}\n' \
		"$(tf_escape "$step")" "$code" "$(tf_escape "$msg")"
}

# Load KEY=VALUE pairs from a .env file WITHOUT executing it. Existing
# environment values win — only unset variables are filled (dotenv semantics).
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
			\'*\') val="${val:1:${#val}-2}" ;;
		esac
		[[ -n "${!key+x}" ]] && continue
		export "$key=$val"
	done < "$env_file"
}

cd "$ROOT_DIR" || { emit_error "chdir" 1 "cannot enter repo root: $ROOT_DIR"; exit 1; }

# Tool / repo guards.
if ! command -v git >/dev/null 2>&1; then
	emit_error "git" 10 "git binary is not available"; exit 10
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	emit_error "git" 10 "not a git repository: $ROOT_DIR"; exit 10
fi
if ! command -v mdtodo >/dev/null 2>&1; then
	emit_error "mdtodo" 12 "mdtodo CLI is not available"; exit 12
fi

# Optional project config, then route every mdtodo call to the configured list.
load_dotenv "$ROOT_DIR/.env"
if [[ -n "${PFLOW_TASKS_MDTODO_FILE:-}" ]]; then
	export MDTODO_FILE="$PFLOW_TASKS_MDTODO_FILE"
fi

# 1. Working tree must be clean — we branch off a known-good state.
if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
	emit_error "git status" 1 "working tree has uncommitted changes; commit or stash them first"
	exit 1
fi

# 2. Must be on the dev branch.
dev_branch="${PFLOW_GIT_DEV_BRANCH:-dev}"
current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
if [[ "$current_branch" != "$dev_branch" ]]; then
	emit_error "git branch" 1 "current branch is '$current_branch', expected dev branch '$dev_branch'"
	exit 1
fi

# 3. There must be no task already in progress.
# `mdtodo current` always exits 0; the locale-independent "no task" signal is
# the JSON value `null`.
trim() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

task_json="$(trim "$(mdtodo current --format json 2>/dev/null)")"
if [[ -n "$task_json" && "$task_json" != "null" ]]; then
	emit_error "mdtodo current" 1 "a task is already in progress; finish it before taking the next"
	exit 1
fi

# 4. Take the next task into progress.
set +e
take_output="$(mdtodo take 2>&1)"
take_exit=$?
set -e
if [[ "$take_exit" -ne 0 ]]; then
	emit_error "mdtodo take" "$take_exit" "$take_output"
	exit "$take_exit"
fi

# `take` exits 0 even when nothing was available — confirm via current.
task_json="$(trim "$(mdtodo current --format json 2>/dev/null)")"
if [[ -z "$task_json" || "$task_json" == "null" ]]; then
	printf '{"status":"no_tasks"}\n'
	exit 0
fi

# mdtodo already emits valid JSON (with title/description); embed it verbatim.
printf '{"status":"ready","task":%s}\n' "$task_json"
