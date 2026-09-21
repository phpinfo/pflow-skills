#!/usr/bin/env bash
# glossary-context.sh — read-only audit for building a project glossary.
# Prints one JSON line: the existing glossary file and its shape, plus the most frequent
# PascalCase identifiers in tracked code (to spot synonym clusters such as
# Customer/Client/Account). Never writes.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SKILL_DIR/../../.." && pwd)"

json_escape() {
	local v="$1"
	v="${v//\\/\\\\}"; v="${v//\"/\\\"}"; v="${v//$'\n'/\\n}"; v="${v//$'\r'/\\r}"; v="${v//$'\t'/\\t}"
	printf '%s' "$v"
}
json_str() { if [[ -z "$1" ]]; then printf 'null'; else printf '"%s"' "$(json_escape "$1")"; fi; }
emit_error() {
	printf '{"status":"error","error":{"step":"%s","exit_code":%d,"message":"%s"}}\n' "$(json_escape "$1")" "$2" "$(json_escape "$3")"
}

top=150
while [[ $# -gt 0 ]]; do
	case "$1" in
		--top) top="${2:-}"; shift 2 ;;
		-h|--help) emit_error "usage" 1 "Usage: glossary-context.sh [--top N]"; exit 1 ;;
		*) emit_error "usage" 1 "Unknown argument: $1"; exit 1 ;;
	esac
done
[[ "$top" =~ ^[0-9]+$ ]] || { emit_error "usage" 1 "--top must be an integer"; exit 1; }

cd "$ROOT_DIR" || { emit_error "chdir" 1 "cannot enter project root: $ROOT_DIR"; exit 1; }

prune=( -not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path './.git/*' -not -path './.agents/*' -not -path './.claude/*' )

# --- existing glossary --------------------------------------------------------
glossary=""
while IFS= read -r f; do glossary="${f#./}"; break; done < <(find . -maxdepth 3 -type f -iname 'glossary*.md' "${prune[@]}" 2>/dev/null | awk '{print length($0), $0}' | sort -n | cut -d' ' -f2-)
g_rows=0; g_tables=0; g_format="absent"
if [[ -n "$glossary" ]]; then
	g_tables="$(grep -cE '^\|[[:space:]]*Term[[:space:]]*\|[[:space:]]*Code[[:space:]]*\|[[:space:]]*Definition[[:space:]]*\|[[:space:]]*Avoid[[:space:]]*\|' "$glossary" 2>/dev/null || true)"
	g_rows="$(grep -cE '^\|' "$glossary" 2>/dev/null || true)"
	if (( g_tables > 0 )); then g_rows=$(( g_rows - 2 * g_tables )); g_format="table"
	elif (( g_rows > 0 )); then g_format="other-table"
	else g_format="prose"; g_rows="$(grep -cE '^(###|-|\*)[[:space:]]' "$glossary" 2>/dev/null || true)"; fi
	(( g_rows < 0 )) && g_rows=0
fi

# --- frequent PascalCase identifiers in code --------------------------------
ext='\.(go|php|py|rb|rs|java|kt|kts|scala|swift|cs|ts|tsx|js|jsx|mjs|cjs|vue|svelte|dart|ex|exs|erl|hs|ml|c|cc|cpp|h|hpp|m|mm|sql|proto|graphql|gql)$'
files=()
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	while IFS= read -r f; do files+=("$f"); done < <(git ls-files -z 2>/dev/null | tr '\0' '\n' | grep -E "$ext" | grep -vE '(^|/)(node_modules|vendor|dist|build|target|\.agents|\.claude)/' | grep -vE '(_test\.go|\.test\.[jt]sx?|\.spec\.[jt]sx?|\.min\.js|\.d\.ts|\.pb\.go|\.g\.dart|_pb2\.py)$' | head -3000)
else
	while IFS= read -r f; do files+=("${f#./}"); done < <(find . -type f "${prune[@]}" -not -path '*/dist/*' -not -path '*/build/*' 2>/dev/null | grep -E "$ext" | head -3000)
fi
identifiers=""; files_scanned="${#files[@]}"
if (( files_scanned > 0 )); then
	while IFS= read -r line; do
		[[ -z "$line" ]] && continue
		cnt="${line%% *}"; name="${line#* }"
		identifiers+="${identifiers:+,}{\"name\":\"$(json_escape "$name")\",\"count\":$cnt}"
	done < <(LC_ALL=C grep -ohE '\b[A-Z][a-z]+([A-Z][a-z0-9]+)+\b|\b[A-Z][a-z]{3,}\b' "${files[@]}" 2>/dev/null \
		| grep -vxE 'String|Object|Array|Boolean|Number|Integer|Float|Double|Error|Exception|Promise|Context|Interface|Option|Result|Function|Class|Public|Private|Static|Return|Import|Package|Default|Record|Struct|Enum|Type|List|Map|Set|Null|None|True|False|Some|Self|This|Void|Value|Date|Time|Json|Http|Test|Mock|Fake|Stub' \
		| sort | uniq -c | sort -rn | head -"$top" | awk '{print $1" "$2}')
fi

printf '{"status":"ok","glossary":{"path":%s,"format":"%s","rows":%s,"default_path":"GLOSSARY.md"},"files_scanned":%s,"identifiers":[%s]}\n' \
	"$(json_str "$glossary")" "$g_format" "$g_rows" "$files_scanned" "$identifiers"
