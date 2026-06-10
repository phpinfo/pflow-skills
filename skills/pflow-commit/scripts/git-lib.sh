#!/usr/bin/env bash

# git-lib.sh — sourceable helpers shared across pflow skills.
#
# This file ONLY defines functions and a few path variables. It must never
# produce output or exit when sourced, so other skills (e.g. pflow-task-finish)
# can `source` it to reuse the commit/push logic without side effects.
#
# Path derivation: this lib lives at .agents/skills/<skill>/scripts/git-lib.sh
# once installed, so three levels up from SKILL_DIR is the consuming repo root.
# Both pflow-commit and any sibling skill that sources this file resolve to the
# same PFLOW_ROOT_DIR.

PFLOW_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PFLOW_SKILL_DIR="$(cd "$PFLOW_LIB_DIR/.." && pwd)"
PFLOW_ROOT_DIR="$(cd "$PFLOW_SKILL_DIR/../../.." && pwd)"

# Outputs set by the functions below (read by callers after invocation):
#   GIT_COMMIT_HASH        — commit sha on success
#   GIT_NOTHING_TO_COMMIT  — 1 when the working tree had nothing staged
#   GIT_PUSH_STATUS        — pushed | pushed_with_upstream | failed
#   GIT_ERR_STEP / GIT_ERR_CODE / GIT_ERR_MSG — populated on failure
GIT_COMMIT_HASH=""
GIT_NOTHING_TO_COMMIT=0
GIT_PUSH_STATUS=""
GIT_ERR_STEP=""
GIT_ERR_CODE=0
GIT_ERR_MSG=""

json_escape() {
	local value="$1"
	value="${value//\\/\\\\}"
	value="${value//\"/\\\"}"
	value="${value//$'\n'/\\n}"
	value="${value//$'\r'/\\r}"
	value="${value//$'\t'/\\t}"
	printf '%s' "$value"
}

print_json_error() {
	local step="$1"
	local exit_code="$2"
	local branch_name="$3"
	local commit_hash="$4"
	local push_status="$5"
	local error_output="$6"
	local escaped_step=""
	local escaped_branch=""
	local escaped_push_status=""
	local escaped_error=""

	escaped_step="$(json_escape "$step")"
	escaped_branch="$(json_escape "$branch_name")"
	escaped_push_status="$(json_escape "$push_status")"
	escaped_error="$(json_escape "$error_output")"
	if [[ -z "$commit_hash" ]]; then
		printf '{"commit_hash":null,"branch_name":"%s","push_status":"%s","error":{"step":"%s","exit_code":%d,"message":"%s"}}\n' \
			"$escaped_branch" "$escaped_push_status" "$escaped_step" "$exit_code" "$escaped_error"
	else
		printf '{"commit_hash":"%s","branch_name":"%s","push_status":"%s","error":{"step":"%s","exit_code":%d,"message":"%s"}}\n' \
			"$commit_hash" "$escaped_branch" "$escaped_push_status" "$escaped_step" "$exit_code" "$escaped_error"
	fi
}

# git_commit_all <message>
#   Stages everything and commits. Sets GIT_COMMIT_HASH on success.
#   If nothing is staged, sets GIT_NOTHING_TO_COMMIT=1 and returns 0 WITHOUT
#   committing (callers decide whether that is fatal). On a real git failure,
#   sets GIT_ERR_* and returns the failing exit code.
git_commit_all() {
	local message="$1"
	GIT_COMMIT_HASH=""
	GIT_NOTHING_TO_COMMIT=0

	local add_output add_exit_code
	add_output="$(git add -A 2>&1)"
	add_exit_code=$?
	if [[ "$add_exit_code" -ne 0 ]]; then
		GIT_ERR_STEP="git add -A"
		GIT_ERR_CODE="$add_exit_code"
		GIT_ERR_MSG="$add_output"
		return "$add_exit_code"
	fi

	if git diff --cached --quiet; then
		GIT_NOTHING_TO_COMMIT=1
		return 0
	fi

	local commit_output commit_exit_code
	commit_output="$(git commit -m "$message" 2>&1)"
	commit_exit_code=$?
	if [[ "$commit_exit_code" -ne 0 ]]; then
		GIT_ERR_STEP="git commit"
		GIT_ERR_CODE="$commit_exit_code"
		GIT_ERR_MSG="$commit_output"
		return "$commit_exit_code"
	fi

	GIT_COMMIT_HASH="$(git rev-parse HEAD)"
	return 0
}

# git_push_current
#   Pushes the current branch, creating upstream when missing. Sets
#   GIT_PUSH_STATUS to pushed | pushed_with_upstream on success. On failure
#   sets GIT_PUSH_STATUS=failed plus GIT_ERR_* and returns the exit code.
git_push_current() {
	local branch_name
	branch_name="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

	local push_output push_exit_code
	if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
		GIT_PUSH_STATUS="pushed"
		push_output="$(git push 2>&1)"
		push_exit_code=$?
	else
		GIT_PUSH_STATUS="pushed_with_upstream"
		push_output="$(git push -u origin "$branch_name" 2>&1)"
		push_exit_code=$?
	fi

	if [[ "$push_exit_code" -ne 0 ]]; then
		GIT_PUSH_STATUS="failed"
		GIT_ERR_STEP="git push"
		GIT_ERR_CODE="$push_exit_code"
		GIT_ERR_MSG="$push_output"
		return "$push_exit_code"
	fi

	return 0
}
