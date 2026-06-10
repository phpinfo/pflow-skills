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

cd "$SKILLS_DIR" || { emit_error "chdir" 1 "cannot enter skills dir: $SKILLS_DIR"; exit 1; }

items=""
for dir in */; do
	dir="${dir%/}"
	[[ -f "$dir/SKILL.md" ]] || continue

	desc=""
	in_fm=0
	while IFS= read -r line; do
		[[ "$line" == "---" ]] && { in_fm=$((1 - in_fm)); ((in_fm == 0)) && break; continue; }
		((in_fm == 1)) && [[ "$line" =~ ^description:[[:space:]]*(.*) ]] && desc="${BASH_REMATCH[1]}"
	done < "$dir/SKILL.md"

	scripts="[]"
	if [[ -d "$dir/scripts" ]]; then
		scripts="["
		sfirst=true
		for f in "$dir/scripts"/*; do
			[[ -f "$f" ]] || continue
			$sfirst && sfirst=false || scripts="$scripts,"
			scripts="$scripts\"$(json_escape "$(basename "$f")")\""
		done
		scripts="$scripts]"
	fi

	[[ -n "$items" ]] && items="$items,"
	items="${items}{\"name\":\"$(json_escape "$dir")\",\"description\":\"$(json_escape "$desc")\",\"scripts\":$scripts}"
done

printf '{"status":"ok","skills_dir":"%s","skills":[%s]}\n' "$(json_escape "$SKILLS_DIR")" "$items"
