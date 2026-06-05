#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./git-lib.sh
source "$SCRIPT_DIR/git-lib.sh"

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

cd "$PFLOW_ROOT_DIR" || exit 1

branch_name="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
if [[ -z "$branch_name" || "$branch_name" == "HEAD" ]]; then
	print_json_error "branch" 11 "$branch_name" "" "not_pushed" "current Git branch is not available"
	exit 11
fi

if ! git_commit_all "$commit_message"; then
	print_json_error "$GIT_ERR_STEP" "$GIT_ERR_CODE" "$branch_name" "" "not_pushed" "$GIT_ERR_MSG"
	exit "$GIT_ERR_CODE"
fi

if [[ "$GIT_NOTHING_TO_COMMIT" -eq 1 ]]; then
	print_json_error "git commit" 1 "$branch_name" "" "not_pushed" "nothing to commit, working tree clean"
	exit 1
fi

commit_hash="$GIT_COMMIT_HASH"

if ! git_push_current; then
	print_json_error "git push" "$GIT_ERR_CODE" "$branch_name" "$commit_hash" "failed" "$GIT_ERR_MSG"
	exit "$GIT_ERR_CODE"
fi

escaped_branch="$(json_escape "$branch_name")"
printf '{"commit_hash":"%s","branch_name":"%s","push_status":"%s"}\n' \
	"$commit_hash" "$escaped_branch" "$GIT_PUSH_STATUS"
