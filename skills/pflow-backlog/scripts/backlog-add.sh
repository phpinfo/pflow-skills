#!/usr/bin/env bash
# backlog-add.sh — create a numbered backlog task file under docs/backlog.
# Reads the plain task text from stdin, takes a latin kebab-case --slug.
# Prints one JSON line; errors as JSON fields, never on stderr.
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

max_lines=10
max_width=140
max_slug=100

slug=""
dir="docs/backlog"

while [[ $# -gt 0 ]]; do
	case "$1" in
		--slug|-s)
			if [[ $# -lt 2 ]]; then emit_error "usage" 1 "missing value for --slug"; exit 1; fi
			slug="${2:-}"; shift 2 ;;
		--dir|-d)
			if [[ $# -lt 2 ]]; then emit_error "usage" 1 "missing value for --dir"; exit 1; fi
			dir="${2:-}"; shift 2 ;;
		-h|--help)
			emit_error "usage" 1 'Usage: backlog-add.sh --slug "<slug>" [--dir "<path>"] < task.txt'; exit 1 ;;
		*)
			emit_error "usage" 1 "Unknown argument: $1"; exit 1 ;;
	esac
done

if [[ -z "$slug" ]]; then
	emit_error "slug" 1 "missing --slug argument"; exit 1
fi
if [[ ! "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
	emit_error "slug" 1 "slug must be latin kebab-case (a-z, 0-9, single dashes): '$slug'"; exit 1
fi
if (( ${#slug} > max_slug )); then
	emit_error "slug" 1 "slug is ${#slug} chars, max ${max_slug}: '$slug'"; exit 1
fi

body="$(cat)"

lines=()
while IFS= read -r line || [[ -n "$line" ]]; do
	line="${line%$'\r'}"
	lines+=("$line")
done <<< "$body"

trim() {
	local v="$1"
	v="${v#"${v%%[![:space:]]*}"}"
	v="${v%"${v##*[![:space:]]}"}"
	printf '%s' "$v"
}

first=-1
last=-1
count=0
maxlen=0
longest=""
for ((i = 0; i < ${#lines[@]}; i++)); do
	if [[ -z "$(trim "${lines[$i]}")" ]]; then continue; fi
	((count++))
	((first == -1)) && first=$i
	last=$i
	if ((${#lines[$i]} > maxlen)); then
		maxlen=${#lines[$i]}
		longest="${lines[$i]}"
	fi
done

if ((count == 0)); then
	emit_error "body" 1 "task description is empty"; exit 1
fi
if ((count > max_lines)); then
	emit_error "body" 1 "task description has ${count} non-blank lines, max ${max_lines}"; exit 1
fi
if ((maxlen > max_width)); then
	emit_error "body" 1 "line is ${maxlen} chars, max ${max_width} — add line breaks: '$longest'"; exit 1
fi

cd "$ROOT_DIR" || { emit_error "chdir" 1 "cannot enter project root: $ROOT_DIR"; exit 1; }

mkdir -p "$dir" || { emit_error "mkdir" 1 "cannot create backlog folder: $dir"; exit 1; }

max_num=0
shopt -s nullglob
for f in "$dir"/[0-9]*-*.md; do
	base="$(basename "$f")"
	n="${base%%-*}"
	[[ "$n" =~ ^[0-9]+$ ]] || continue
	n=$((10#$n))
	((n > max_num)) && max_num=$n
done
shopt -u nullglob

next=$((max_num + 1))
printf -v num '%03d' "$next"
target="$dir/${num}-${slug}.md"
while [[ -e "$target" ]]; do
	next=$((next + 1))
	printf -v num '%03d' "$next"
	target="$dir/${num}-${slug}.md"
done

if ! {
	for ((i = first; i <= last; i++)); do
		printf '%s\n' "${lines[$i]}"
	done
} > "$target"; then
	rm -f -- "$target"
	emit_error "write" 1 "cannot write task file: $target"; exit 1
fi

printf '{"status":"ok","path":"%s","number":"%s","slug":"%s","lines":%d,"width":%d}\n' \
	"$(json_escape "$target")" "$(json_escape "$num")" "$(json_escape "$slug")" "$count" "$maxlen"
