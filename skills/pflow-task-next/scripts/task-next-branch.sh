#!/usr/bin/env bash

# task-next-branch.sh — create the agent-chosen branch and switch onto it.
#
# Carries the working-tree change made by `mdtodo take` (the `[~]` marker) onto
# the new branch. Emits ONE JSON line:
#   {"status":"created","branch":"...","previous_branch":"..."}
#   {"status":"error","error":{...}}

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
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
	local step="$1" code="$2" msg="$3"
	printf '{"status":"error","error":{"step":"%s","exit_code":%d,"message":"%s"}}\n' \
		"$(tf_escape "$step")" "$code" "$(tf_escape "$msg")"
}

branch=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		--branch|-b) branch="${2:-}"; shift 2 ;;
		-h|--help)
			emit_error "usage" 1 'Usage: task-next-branch.sh --branch "type/slug"'; exit 1 ;;
		*) emit_error "usage" 1 "Unknown argument: $1"; exit 1 ;;
	esac
done

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

# Validate the branch name.
if [[ -z "$branch" ]]; then
	emit_error "branch" 1 "missing --branch argument"; exit 1
fi
if ! git check-ref-format "refs/heads/$branch" >/dev/null 2>&1; then
	emit_error "branch" 1 "invalid git branch name: $branch"; exit 1
fi
if git show-ref --verify --quiet "refs/heads/$branch"; then
	emit_error "branch" 1 "branch already exists: $branch"; exit 1
fi

previous_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

set +e
co_output="$(git checkout -b "$branch" 2>&1)"; co_exit=$?
set -e
if [[ "$co_exit" -ne 0 ]]; then
	emit_error "git checkout" "$co_exit" "$co_output"
	exit "$co_exit"
fi

printf '{"status":"created","branch":"%s","previous_branch":"%s"}\n' \
	"$(tf_escape "$branch")" "$(tf_escape "$previous_branch")"
