#!/usr/bin/env bash

set -u

MAX_TOTAL_LINES=600
MAX_FILE_LINES=50
printed_lines=0

if ! command -v git >/dev/null 2>&1; then
	printf 'Error: git binary is not available\n' >&2
	exit 10
fi

print_line() {
	if [ "$printed_lines" -ge "$MAX_TOTAL_LINES" ]; then
		return 1
	fi

	printf '%s\n' "$1"
	printed_lines=$((printed_lines + 1))
	return 0
}

print_stream_limited() {
	local limit="$1"
	local count=0
	local line

	while IFS= read -r line; do
		if [ "$count" -ge "$limit" ]; then
			break
		fi

		print_line "$line" || return 1
		count=$((count + 1))
	done
}

normalize_renamed_path() {
	local path="$1"

	if [[ "$path" == *" -> "* ]]; then
		printf '%s\n' "${path##* -> }"
	else
		printf '%s\n' "$path"
	fi
}

declare -a added_files=()
declare -a modified_files=()
declare -a deleted_files=()

while IFS= read -r status_line; do
	[ -n "$status_line" ] || continue

	index_status="${status_line:0:1}"
	worktree_status="${status_line:1:1}"
	path="${status_line:3}"
	path="$(normalize_renamed_path "$path")"

	if [ "$index_status" = "?" ] && [ "$worktree_status" = "?" ]; then
		added_files+=("$path")
	elif [ "$index_status" = "A" ] || [ "$worktree_status" = "A" ]; then
		added_files+=("$path")
	elif [ "$index_status" = "D" ] || [ "$worktree_status" = "D" ]; then
		deleted_files+=("$path")
	else
		modified_files+=("$path")
	fi
done < <(git status --porcelain=v1 --untracked-files=all)

if [ "${#added_files[@]}" -eq 0 ] && [ "${#modified_files[@]}" -eq 0 ] && [ "${#deleted_files[@]}" -eq 0 ]; then
	print_line "No changes detected."
	exit 0
fi

print_line "Changed files summary:"

print_line "Added files:"
if [ "${#added_files[@]}" -eq 0 ]; then
	print_line "- none"
else
	for file_path in "${added_files[@]}"; do
		print_line "- $file_path" || exit 0
	done
fi

print_line "Modified files:"
if [ "${#modified_files[@]}" -eq 0 ]; then
	print_line "- none"
else
	for file_path in "${modified_files[@]}"; do
		print_line "- $file_path" || exit 0
	done
fi

print_line "Deleted files:"
if [ "${#deleted_files[@]}" -eq 0 ]; then
	print_line "- none"
else
	for file_path in "${deleted_files[@]}"; do
		print_line "- $file_path" || exit 0
	done
fi

for file_path in "${added_files[@]}"; do
	print_line "" || exit 0
	print_line "Added file content (first $MAX_FILE_LINES lines): $file_path" || exit 0
	if [ -f "$file_path" ]; then
		print_stream_limited "$MAX_FILE_LINES" < "$file_path" || exit 0
	else
		print_line "File content is not available." || exit 0
	fi
done

for file_path in "${modified_files[@]}"; do
	print_line "" || exit 0
	print_line "Modified file diff (first $MAX_FILE_LINES lines): $file_path" || exit 0
	print_stream_limited "$MAX_FILE_LINES" < <(git diff HEAD -- "$file_path") || exit 0
done
