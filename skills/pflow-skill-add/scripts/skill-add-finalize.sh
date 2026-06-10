#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$(cd "$SKILL_DIR/.." && pwd)"

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

name=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		--name|-n) name="${2:-}"; shift 2 ;;
		-h|--help)
			emit_error "usage" 1 'Usage: skill-add-finalize.sh --name "<name>"'
			exit 1 ;;
		*) emit_error "usage" 1 "Unknown argument: $1"; exit 1 ;;
	esac
done

[[ -z "$name" ]] && { emit_error "name" 1 "missing --name argument"; exit 1; }

target="$SKILLS_DIR/$name"
skill_md="$target/SKILL.md"

[[ -f "$skill_md" ]] || { emit_error "validate" 1 "SKILL.md not found: $skill_md"; exit 1; }

has_name=0 has_desc=0 in_fm=0
while IFS= read -r line; do
	[[ "$line" == "---" ]] && { in_fm=$((1 - in_fm)); ((in_fm == 0)) && break; continue; }
	((in_fm == 1)) && {
		[[ "$line" =~ ^name: ]] && has_name=1
		[[ "$line" =~ ^description: ]] && has_desc=1
	}
done < "$skill_md"

((has_name == 0)) && { emit_error "validate" 1 "SKILL.md missing 'name' in frontmatter"; exit 1; }
((has_desc == 0)) && { emit_error "validate" 1 "SKILL.md missing 'description' in frontmatter"; exit 1; }

chmod_count=0
scripts_dir="$target/scripts"
if [[ -d "$scripts_dir" ]]; then
	for f in "$scripts_dir"/*; do
		if [[ -f "$f" ]]; then
			chmod +x "$f" && ((chmod_count++))
		fi
	done
fi

printf '{"status":"ok","skill_dir":"%s","scripts_chmod":%d}\n' "$(json_escape "$target")" "$chmod_count"
