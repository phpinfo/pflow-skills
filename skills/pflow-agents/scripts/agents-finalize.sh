#!/usr/bin/env bash
# agents-finalize.sh — reads AGENTS.md Markdown from stdin, lint-checks it (size, filler
# phrases, verbatim duplication of README/CONTRIBUTING/docs), writes AGENTS.md atomically,
# then syncs CLAUDE.md (copy | import | none). Errors block the write; warnings do not.
#
# Usage: agents-finalize.sh [--overwrite] [--claude copy|import|none] [--max-lines N] [--warn-lines N] < AGENTS.md
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SKILL_DIR/../../.." && pwd)"

json_escape() {
	local v="$1"
	v="${v//\\/\\\\}"; v="${v//\"/\\\"}"; v="${v//$'\n'/\\n}"; v="${v//$'\r'/\\r}"; v="${v//$'\t'/\\t}"
	printf '%s' "$v"
}
emit_error() {
	printf '{"status":"error","error":{"step":"%s","exit_code":%d,"message":"%s"}}\n' "$(json_escape "$1")" "$2" "$(json_escape "$3")"
}

overwrite=0; claude_mode="copy"; max_lines=100; warn_lines=60
while [[ $# -gt 0 ]]; do
	case "$1" in
		--overwrite) overwrite=1; shift ;;
		--claude) claude_mode="${2:-}"; shift 2 ;;
		--max-lines) max_lines="${2:-}"; shift 2 ;;
		--warn-lines) warn_lines="${2:-}"; shift 2 ;;
		-h|--help) emit_error "usage" 1 "Usage: agents-finalize.sh [--overwrite] [--claude copy|import|none] [--max-lines N] [--warn-lines N] < AGENTS.md"; exit 1 ;;
		*) emit_error "usage" 1 "Unknown argument: $1"; exit 1 ;;
	esac
done
case "$claude_mode" in copy|import|none) ;; *) emit_error "usage" 1 "--claude must be copy, import or none"; exit 1 ;; esac
[[ "$max_lines" =~ ^[0-9]+$ && "$warn_lines" =~ ^[0-9]+$ ]] || { emit_error "usage" 1 "--max-lines/--warn-lines must be integers"; exit 1; }

[[ -t 0 ]] && { emit_error "stdin" 1 "no content on stdin — pipe the AGENTS.md Markdown via a quoted heredoc"; exit 1; }
content="$(cat)"
[[ -z "${content//[[:space:]]/}" ]] && { emit_error "stdin" 1 "empty AGENTS.md content on stdin"; exit 1; }
content="${content%$'\n'}"$'\n'

cd "$ROOT_DIR" || { emit_error "chdir" 1 "cannot enter project root: $ROOT_DIR"; exit 1; }

# --- hard checks (block the write) -------------------------------------------
lines="$(printf '%s' "$content" | wc -l | tr -d ' ')"
bytes="$(printf '%s' "$content" | wc -c | tr -d ' ')"
(( lines > max_lines )) && { emit_error "lint" 1 "AGENTS.md is $lines lines; limit is $max_lines. Cut derivable, duplicated or generic lines, or move detail into referenced files."; exit 1; }
(( bytes > 32768 )) && { emit_error "lint" 1 "AGENTS.md is $bytes bytes; Codex stops reading at 32768. Trim it."; exit 1; }
if (( ! overwrite )); then
	[[ -f AGENTS.md ]] && { emit_error "exists" 1 "AGENTS.md already exists — read it, merge, then rerun with --overwrite"; exit 1; }
	[[ -e CLAUDE.md && "$claude_mode" != "none" ]] && { emit_error "exists" 1 "CLAUDE.md already exists — read it, merge, then rerun with --overwrite (or --claude none)"; exit 1; }
fi

# --- soft checks (warnings) --------------------------------------------------
warnings=""
add_warning() { # code line text
	warnings+="${warnings:+,}{\"code\":\"$(json_escape "$1")\",\"line\":$2,\"text\":\"$(json_escape "$3")\"}"
}
(( lines > warn_lines )) && add_warning "long" 0 "$lines lines; target is <= $warn_lines. Re-apply the removal test to every line."

filler='write clean code|follow best practices|be careful|be thorough|high[- ]quality|well[- ]tested|maintainable|readable code|clean architecture|solid principles|dry principle|kiss principle|as needed|where appropriate|when necessary|good practices|industry standard|self-explanatory|this project (is|uses)|you are an? (expert|senior|helpful)|always write tests|handle errors properly|meaningful (names|variable)|add comments|use descriptive'
important_count=0; fence_count=0; n=0
doc_files=()
for f in README.md README.rst README CONTRIBUTING.md ARCHITECTURE.md DEVELOPMENT.md; do [[ -f "$f" ]] && doc_files+=("$f"); done
if [[ -d docs ]]; then while IFS= read -r f; do doc_files+=("$f"); done < <(find docs -maxdepth 2 -name '*.md' 2>/dev/null | head -50); fi
in_fence=0
while IFS= read -r line; do
	n=$((n+1))
	[[ "$line" =~ ^\`\`\` ]] && { in_fence=$((1-in_fence)); fence_count=$((fence_count+1)); continue; }
	(( in_fence )) && continue
	[[ -z "${line//[[:space:]]/}" ]] && continue
	printf '%s' "$line" | grep -qiE "$filler" && add_warning "generic" "$n" "generic or self-evident phrase — an agent already knows this: $(printf '%s' "$line" | cut -c1-100)"
	printf '%s' "$line" | grep -qE 'IMPORTANT|MUST|NEVER|ALWAYS' && important_count=$((important_count+1))
	printf '%s' "$line" | grep -qiE '\b(TODO|TBD|FIXME|XXX)\b' && add_warning "placeholder" "$n" "placeholder left in file"
	printf '%s' "$line" | grep -qiE '^\s*(this (repository|repo|project) (is|contains)|the project (is|uses))' && add_warning "overview" "$n" "project overview — agents derive this from the code and README; studies show it does not help"
	stripped="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*([-*]|[0-9]+\.|#+)[[:space:]]*//; s/[[:space:]]+$//')"
	if (( ${#stripped} >= 40 )) && (( ${#doc_files[@]} > 0 )); then
		if grep -qF -- "$stripped" "${doc_files[@]}" 2>/dev/null; then
			add_warning "duplicate" "$n" "verbatim in $(grep -lF -- "$stripped" "${doc_files[@]}" 2>/dev/null | head -1) — link to it instead of copying"
		fi
	fi
done <<< "$content"
(( important_count > 2 )) && add_warning "emphasis" 0 "$important_count lines use IMPORTANT/MUST/NEVER/ALWAYS; emphasis only works on one or two lines"
(( fence_count > 6 )) && add_warning "code" 0 "$((fence_count/2)) code blocks; prefer file:line pointers over pasted code"

# --- write ------------------------------------------------------------------
tmp="$(mktemp "$ROOT_DIR/.AGENTS.md.XXXXXX")" || { emit_error "write" 1 "cannot create temp file"; exit 1; }
printf '%s' "$content" > "$tmp" && chmod 644 "$tmp" && mv -f "$tmp" AGENTS.md || { rm -f "$tmp"; emit_error "write" 1 "cannot write AGENTS.md"; exit 1; }

claude_result="skipped"
case "$claude_mode" in
	copy)
		[[ -L CLAUDE.md ]] && rm -f CLAUDE.md
		cp -f AGENTS.md CLAUDE.md && chmod 644 CLAUDE.md || { emit_error "write" 1 "cannot write CLAUDE.md"; exit 1; }
		claude_result="copied" ;;
	import)
		[[ -L CLAUDE.md ]] && rm -f CLAUDE.md
		if [[ -f CLAUDE.md ]] && grep -qE '^@AGENTS\.md[[:space:]]*$' CLAUDE.md; then claude_result="import-kept"
		else printf '@AGENTS.md\n' > CLAUDE.md || { emit_error "write" 1 "cannot write CLAUDE.md"; exit 1; }; claude_result="import-written"; fi ;;
esac

printf '{"status":"ok","agents_md":{"path":"%s","lines":%s,"bytes":%s},"claude_md":{"mode":"%s","result":"%s"},"warnings":[%s]}\n' \
	"$(json_escape "$ROOT_DIR/AGENTS.md")" "$lines" "$bytes" "$claude_mode" "$claude_result" "$warnings"
