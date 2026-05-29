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

usage() {
	print_json_error "usage" 1 "" "" "not_pushed" 'Usage: git-commit-push.sh --message "commit message"'
	exit 1
}

commit_message=""

while [[ $# -gt 0 ]]; do
	case "$1" in
		--message|-m)
			if [[ $# -lt 2 ]]; then
				usage
			fi
			commit_message="${2:-}"
			shift 2
			;;
		-h|--help)
			usage
			;;
		*)
			if [[ -z "$commit_message" ]]; then
				commit_message="$1"
				shift
			else
				print_json_error "usage" 1 "" "" "not_pushed" "Unknown argument: $1"
				exit 1
			fi
			;;
	esac
done

if [[ -z "$commit_message" ]]; then
	usage
fi

if ! command -v git >/dev/null 2>&1; then
	print_json_error "git" 10 "" "" "not_pushed" "git binary is not available"
	exit 10
fi

cd "$ROOT_DIR" || exit 1

branch_name="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
if [[ -z "$branch_name" || "$branch_name" == "HEAD" ]]; then
	print_json_error "branch" 11 "$branch_name" "" "not_pushed" "current Git branch is not available"
	exit 11
fi

set +e
add_output="$(git add -A 2>&1)"
add_exit_code=$?
set -e

if [[ "$add_exit_code" -ne 0 ]]; then
	print_json_error "git add -A" "$add_exit_code" "$branch_name" "" "not_pushed" "$add_output"
	exit "$add_exit_code"
fi

set +e
commit_output="$(git commit -m "$commit_message" 2>&1)"
commit_exit_code=$?
set -e

if [[ "$commit_exit_code" -ne 0 ]]; then
	print_json_error "git commit" "$commit_exit_code" "$branch_name" "" "not_pushed" "$commit_output"
	exit "$commit_exit_code"
fi

commit_hash="$(git rev-parse HEAD)"

push_status="pushed"
if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
	set +e
	push_output="$(git push 2>&1)"
	push_exit_code=$?
	set -e
else
	push_status="pushed_with_upstream"
	set +e
	push_output="$(git push -u origin "$branch_name" 2>&1)"
	push_exit_code=$?
	set -e
fi

if [[ "$push_exit_code" -ne 0 ]]; then
	print_json_error "git push" "$push_exit_code" "$branch_name" "$commit_hash" "failed" "$push_output"
	exit "$push_exit_code"
fi

escaped_branch="$(json_escape "$branch_name")"
printf '{"commit_hash":"%s","branch_name":"%s","push_status":"%s"}\n' \
	"$commit_hash" "$escaped_branch" "$push_status"
