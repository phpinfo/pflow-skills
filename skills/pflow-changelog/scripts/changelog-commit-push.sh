#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMIT_LIB="$SKILLS_DIR/pflow-commit/scripts/git-lib.sh"

if [[ ! -f "$COMMIT_LIB" ]]; then
	printf '{"error":{"step":"dependency","exit_code":1,"message":"pflow-commit is not installed"}}\n'
	exit 1
fi

# shellcheck source=../../pflow-commit/scripts/git-lib.sh
source "$COMMIT_LIB"

cd "$PFLOW_ROOT_DIR" || exit 1

message="docs: update CHANGELOG.md"

if ! git_commit_all "$message"; then
	print_json_error "$GIT_ERR_STEP" "$GIT_ERR_CODE" "" "" "not_pushed" "$GIT_ERR_MSG"
	exit "$GIT_ERR_CODE"
fi

if [[ "$GIT_NOTHING_TO_COMMIT" -eq 1 ]]; then
	print_json_error "git commit" 1 "" "" "not_pushed" "nothing to commit, working tree clean"
	exit 1
fi

commit_hash="$GIT_COMMIT_HASH"

if ! git_push_current; then
	print_json_error "git push" "$GIT_ERR_CODE" "" "$commit_hash" "failed" "$GIT_ERR_MSG"
	exit "$GIT_ERR_CODE"
fi

escaped_branch="$(json_escape "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)")"
printf '{"commit_hash":"%s","branch_name":"%s","push_status":"%s"}\n' \
	"$commit_hash" "$escaped_branch" "$GIT_PUSH_STATUS"
