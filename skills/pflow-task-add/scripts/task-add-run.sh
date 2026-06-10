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

title=""
description=""
version=""

while [[ $# -gt 0 ]]; do
	case "$1" in
		--title|-t)
			if [[ $# -lt 2 ]]; then
				emit_error "usage" 1 "missing value for --title"; exit 1
			fi
			title="${2:-}"
			shift 2
			;;
		--description|-d)
			if [[ $# -lt 2 ]]; then
				emit_error "usage" 1 "missing value for --description"; exit 1
			fi
			description="${2:-}"
			shift 2
			;;
		--version|-v)
			if [[ $# -lt 2 ]]; then
				emit_error "usage" 1 "missing value for --version"; exit 1
			fi
			version="${2:-}"
			shift 2
			;;
		-h|--help)
			emit_error "usage" 1 'Usage: task-add-run.sh --title "TITLE" [--description "DESC"] [--version "VERSION"]'
			exit 1
			;;
		*)
			emit_error "usage" 1 "Unknown argument: $1"; exit 1
			;;
	esac
done

if [[ -z "$title" ]]; then
	emit_error "title" 1 "missing --title argument"; exit 1
fi

cd "$ROOT_DIR" || { emit_error "chdir" 1 "cannot enter repo root: $ROOT_DIR"; exit 1; }

if ! command -v mdtodo >/dev/null 2>&1; then
	emit_error "mdtodo" 12 "mdtodo CLI is not available"; exit 12
fi

load_dotenv "$ROOT_DIR/.env"
if [[ -n "${PFLOW_TASKS_MDTODO_FILE:-}" ]]; then
	export MDTODO_FILE="$PFLOW_TASKS_MDTODO_FILE"
fi
mdtodo_file="${MDTODO_FILE:-todo.md}"

if [[ ! -f "$mdtodo_file" ]]; then
	touch "$mdtodo_file" || {
		emit_error "file" 1 "cannot create tasks file: $mdtodo_file"; exit 1
	}
fi

cmd=(mdtodo add --file "$mdtodo_file" --position last)
[[ -n "$version" ]] && cmd+=(--version "$version")
cmd+=("$title")

set +e
add_output="$("${cmd[@]}" 2>&1)"
add_exit=$?
set -e

if [[ "$add_exit" -ne 0 ]]; then
	emit_error "mdtodo add" "$add_exit" "$add_output"
	exit "$add_exit"
fi

has_description="false"

if [[ -n "$description" ]]; then
	expected_prefix="- [ ] "
	[[ -n "$version" ]] && expected_prefix="- [ ] ${version} "
	expected_line="${expected_prefix}${title}"

	tmpfile="$(mktemp)"
	found=0

	while IFS= read -r line || [[ -n "$line" ]]; do
		printf '%s\n' "$line"
		if [[ "$found" -eq 0 ]]; then
			trimmed="$line"
			trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"
			trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
			if [[ "$trimmed" == "$expected_line" ]]; then
				found=1
				while IFS= read -r dline; do
					[[ -n "$dline" ]] && printf '  %s\n' "$dline"
				done <<< "$description"
			fi
		fi
	done < "$mdtodo_file" > "$tmpfile"

	if [[ "$found" -eq 1 ]]; then
		mv "$tmpfile" "$mdtodo_file"
		has_description="true"
	else
		rm -f "$tmpfile"
	fi
fi

printf '{"status":"ok","title":"%s","version":"%s","mdtodo_file":"%s","has_description":%s}\n' \
	"$(json_escape "$title")" "$(json_escape "$version")" \
	"$(json_escape "$mdtodo_file")" "$has_description"
