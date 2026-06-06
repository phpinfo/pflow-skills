#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$(cd "$SKILL_DIR/.." && pwd)"
# Consuming repo root: three levels up from SKILL_DIR once installed.
ROOT_DIR="$(cd "$SKILL_DIR/../../.." && pwd)"
COMMIT_LIB="$SKILLS_DIR/pflow-commit/scripts/git-lib.sh"

# Minimal escaper for THIS script's own JSON output, so it works even in the
# fallback mode where git-lib.sh (and its json_escape) is unavailable.
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

slugify() {
	printf '%s' "$1" \
		| tr '[:upper:]' '[:lower:]' \
		| tr -c 'a-z0-9' '-' \
		| sed -E 's/-+/-/g; s/^-+//; s/-+$//' \
		| cut -c1-50 \
		| sed -E 's/-+$//'
}

# Load KEY=VALUE pairs from a .env file WITHOUT executing it (no command
# substitution, no subshells). Existing environment values win — only unset
# variables are filled, matching standard dotenv behaviour.
load_dotenv() {
	local env_file="$1"
	[[ -f "$env_file" ]] || return 0
	local line key val
	while IFS= read -r line || [[ -n "$line" ]]; do
		line="${line%$'\r'}"                                   # strip CR (CRLF files)
		line="${line#"${line%%[![:space:]]*}"}"                # trim leading whitespace
		[[ -z "$line" || "${line:0:1}" == "#" ]] && continue   # skip blanks / comments
		[[ "$line" == export\ * ]] && line="${line#export }"
		[[ "$line" == *=* ]] || continue
		key="${line%%=*}"
		val="${line#*=}"
		key="${key%"${key##*[![:space:]]}"}"                   # trim trailing whitespace in key
		[[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue   # only valid identifiers
		case "$val" in                                         # strip one layer of quotes
			\"*\") val="${val:1:${#val}-2}" ;;
			\'*\') val="${val:1:${#val}-2}" ;;
		esac
		[[ -n "${!key+x}" ]] && continue                       # don't override existing env
		export "$key=$val"
	done < "$env_file"
}

message=""
slug=""
dev_arg=""

while [[ $# -gt 0 ]]; do
	case "$1" in
		--message|-m) message="${2:-}"; shift 2 ;;
		--slug|-s)    slug="${2:-}"; shift 2 ;;
		--dev|-d)     dev_arg="${2:-}"; shift 2 ;;
		-h|--help)
			emit_error "usage" 1 'Usage: task-finish.sh --message "M" [--slug "S"] [--dev "branch"]'
			exit 1 ;;
		*) emit_error "usage" 1 "Unknown argument: $1"; exit 1 ;;
	esac
done

cd "$ROOT_DIR" || { emit_error "chdir" 1 "cannot enter repo root: $ROOT_DIR"; exit 1; }

# Optional project config. A .env in the repo root MAY exist; load it (without
# executing it), then route every mdtodo call to the configured list file by
# exporting MDTODO_FILE once, before the first mdtodo invocation.
load_dotenv "$ROOT_DIR/.env"
if [[ -n "${PFLOW_TASKS_MDTODO_FILE:-}" ]]; then
	export MDTODO_FILE="$PFLOW_TASKS_MDTODO_FILE"
fi

if ! command -v mdtodo >/dev/null 2>&1; then
	emit_error "mdtodo" 12 "mdtodo CLI is not available"
	exit 12
fi

# 1. Is there a current task?
# `mdtodo current` always exits 0; the reliable "no task" signal is the JSON
# value `null` (locale-independent), so detect on that rather than exit code.
set +e
task_json="$(mdtodo current --format json 2>/dev/null)"
current_exit=$?
set -e
task_json="$(printf '%s' "$task_json" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [[ "$current_exit" -ne 0 || -z "$task_json" || "$task_json" == "null" ]]; then
	printf '{"status":"no_current_task"}\n'
	exit 0
fi

# Raw (unescaped) task title from plain format "status;version;title".
plain="$(mdtodo current --format plain 2>/dev/null)"
rest="${plain#*;}"
task="${rest#*;}"
task="$(printf '%s' "$task" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[[ -n "$task" ]] || task="current task"

# 2. Close the task — ALWAYS, even when git is unavailable (core promise).
set +e
finish_output="$(mdtodo finish 2>&1)"
finish_exit=$?
set -e
if [[ "$finish_exit" -ne 0 ]]; then
	emit_error "mdtodo finish" "$finish_exit" "$finish_output"
	exit "$finish_exit"
fi

# 3. Fallback: no pflow-commit -> close only, no git at all.
if [[ ! -f "$COMMIT_LIB" ]] || ! command -v git >/dev/null 2>&1; then
	reason="pflow-commit is not installed"
	[[ -f "$COMMIT_LIB" ]] && reason="git binary is not available"
	warning="$reason — task closed via mdtodo, all git steps skipped. Install: npx skills add phpinfo/pflow-skills -s pflow-commit"
	printf '⚠️ %s\n' "$warning" >&2
	printf '{"status":"closed_no_git","git":"skipped","task":"%s","warning":"%s"}\n' \
		"$(tf_escape "$task")" "$(tf_escape "$warning")"
	exit 0
fi

# 4. Full git flow.
# shellcheck source=../../pflow-commit/scripts/git-lib.sh
source "$COMMIT_LIB"

started_on="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

# Resolve the dev/merge target.
# Precedence: --dev CLI flag > $PFLOW_GIT_DEV_BRANCH (env/.env) > autodetected
# dev/develop > default "dev". If the chosen branch does not exist, fall back to
# merging into the branch we started on.
if [[ -n "$dev_arg" ]]; then
	dev_branch="$dev_arg"
elif [[ -n "${PFLOW_GIT_DEV_BRANCH:-}" ]]; then
	dev_branch="$PFLOW_GIT_DEV_BRANCH"
elif git show-ref --verify --quiet refs/heads/develop && ! git show-ref --verify --quiet refs/heads/dev; then
	dev_branch="develop"
else
	dev_branch="dev"
fi
if [[ "$dev_branch" != "$started_on" ]] && ! git show-ref --verify --quiet "refs/heads/$dev_branch"; then
	dev_branch="$started_on"
fi

# Decide the task branch.
# If we are already on a work branch (anything other than the dev target — e.g.
# one created by pflow-task-next), commit and merge THAT branch. Only when
# finishing straight from the dev branch do we create task/<slug>.
if [[ "$started_on" != "$dev_branch" ]]; then
	task_branch="$started_on"
	[[ -n "$slug" ]] || slug="${started_on##*/}"
else
	[[ -n "$slug" ]] || slug="$(slugify "$task")"
	[[ -n "$slug" ]] || slug="task"
	task_branch="task/$slug"

	# Move onto the task branch (carrying the just-closed todo change with us).
	set +e
	if git show-ref --verify --quiet "refs/heads/$task_branch"; then
		co_output="$(git checkout "$task_branch" 2>&1)"; co_exit=$?
	else
		co_output="$(git checkout -b "$task_branch" 2>&1)"; co_exit=$?
	fi
	set -e
	if [[ "$co_exit" -ne 0 ]]; then
		emit_error "checkout task branch" "$co_exit" "$co_output"
		exit "$co_exit"
	fi
fi

# Commit everything (todo change + any working-tree changes).
if ! git_commit_all "$message"; then
	emit_error "$GIT_ERR_STEP" "$GIT_ERR_CODE" "$GIT_ERR_MSG"
	exit "$GIT_ERR_CODE"
fi
if [[ "$GIT_NOTHING_TO_COMMIT" -eq 1 ]]; then
	commit_status="nothing_to_commit"
	commit_hash=""
else
	commit_status="committed"
	commit_hash="$GIT_COMMIT_HASH"
fi

has_remote=0
[[ -n "$(git remote 2>/dev/null)" ]] && has_remote=1

# Best-effort push of the task branch.
push_status_task="skipped"
if [[ "$has_remote" -eq 1 ]]; then
	if git_push_current; then push_status_task="$GIT_PUSH_STATUS"; else push_status_task="failed"; fi
fi

push_status_dev="skipped"
if [[ "$dev_branch" == "$task_branch" ]]; then
	merge_status="same_branch"
else
	set +e
	cod_output="$(git checkout "$dev_branch" 2>&1)"; cod_exit=$?
	set -e
	if [[ "$cod_exit" -ne 0 ]]; then
		emit_error "checkout dev" "$cod_exit" "$cod_output"
		exit "$cod_exit"
	fi

	set +e
	merge_output="$(git merge --no-ff --no-edit "$task_branch" 2>&1)"; merge_exit=$?
	set -e
	if [[ "$merge_exit" -ne 0 ]]; then
		# Conflict (or other failure): leave the repo mid-merge for a human.
		emit_error "git merge" "$merge_exit" "$merge_output"
		exit "$merge_exit"
	fi
	merge_status="merged"

	if [[ "$has_remote" -eq 1 ]]; then
		if git_push_current; then push_status_dev="$GIT_PUSH_STATUS"; else push_status_dev="failed"; fi
	fi
fi

commit_hash_json="null"
[[ -n "$commit_hash" ]] && commit_hash_json="\"$commit_hash\""

printf '{"status":"finished","task":"%s","slug":"%s","task_branch":"%s","dev_branch":"%s","started_on":"%s","commit_hash":%s,"commit_status":"%s","merge_status":"%s","push_status_task":"%s","push_status_dev":"%s"}\n' \
	"$(tf_escape "$task")" "$(tf_escape "$slug")" "$(tf_escape "$task_branch")" \
	"$(tf_escape "$dev_branch")" "$(tf_escape "$started_on")" "$commit_hash_json" \
	"$commit_status" "$merge_status" "$push_status_task" "$push_status_dev"
