#!/usr/bin/env bash
# glossary-finalize.sh — reads glossary Markdown from stdin, enforces the fixed shape
# (H1, optional H2 groups, tables `| Term | Code | Definition | Avoid |`, nothing else),
# lint-checks rows, sorts each table alphabetically, writes the file atomically, then
# adds a one-line glossary rule to AGENTS.md / CLAUDE.md when they exist and lack one.
#
# Usage: glossary-finalize.sh [--path FILE] [--overwrite] [--agents auto|none] < GLOSSARY.md
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
trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }
lower() { printf '%s' "$1" | LC_ALL=C.UTF-8 tr '[:upper:]' '[:lower:]' 2>/dev/null || printf '%s' "$1"; }

path=""; overwrite=0; agents_mode="auto"
while [[ $# -gt 0 ]]; do
	case "$1" in
		--path) path="${2:-}"; shift 2 ;;
		--overwrite) overwrite=1; shift ;;
		--agents) agents_mode="${2:-}"; shift 2 ;;
		-h|--help) emit_error "usage" 1 "Usage: glossary-finalize.sh [--path FILE] [--overwrite] [--agents auto|none] < GLOSSARY.md"; exit 1 ;;
		*) emit_error "usage" 1 "Unknown argument: $1"; exit 1 ;;
	esac
done
case "$agents_mode" in auto|none) ;; *) emit_error "usage" 1 "--agents must be auto or none"; exit 1 ;; esac

[[ -t 0 ]] && { emit_error "stdin" 1 "no content on stdin — pipe the glossary Markdown via a quoted heredoc"; exit 1; }
content="$(cat)"
[[ -z "${content//[[:space:]]/}" ]] && { emit_error "stdin" 1 "empty glossary content on stdin"; exit 1; }

cd "$ROOT_DIR" || { emit_error "chdir" 1 "cannot enter project root: $ROOT_DIR"; exit 1; }

if [[ -z "$path" ]]; then
	path="$(find . -maxdepth 3 -type f -iname 'glossary*.md' -not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path './.git/*' -not -path './.agents/*' -not -path './.claude/*' 2>/dev/null | awk '{print length($0), $0}' | sort -n | head -1 | cut -d' ' -f2-)"
	path="${path#./}"; path="${path:-GLOSSARY.md}"
fi
[[ -e "$path" && ! -f "$path" ]] && { emit_error "path" 1 "$path exists and is not a regular file"; exit 1; }
[[ -f "$path" && $overwrite -eq 0 ]] && { emit_error "exists" 1 "$path already exists — read it, merge every existing term, then rerun with --overwrite"; exit 1; }

# --- parse and lint -----------------------------------------------------------
header_re='^\|[[:space:]]*Term[[:space:]]*\|[[:space:]]*Code[[:space:]]*\|[[:space:]]*Definition[[:space:]]*\|[[:space:]]*Avoid[[:space:]]*\|[[:space:]]*$'
sep_re='^\|[[:space:]]*:?-+:?[[:space:]]*\|[[:space:]]*:?-+:?[[:space:]]*\|[[:space:]]*:?-+:?[[:space:]]*\|[[:space:]]*:?-+:?[[:space:]]*\|[[:space:]]*$'
canon_header='| Term | Code | Definition | Avoid |'
canon_sep='| --- | --- | --- | --- |'

warnings=""
add_warning() { warnings+="${warnings:+,}{\"code\":\"$(json_escape "$1")\",\"line\":$2,\"text\":\"$(json_escape "$3")\"}"; }
fail() { emit_error "lint" 1 "line $1: $2"; exit 1; }

out=""          # rebuilt document
rows_buf=""     # rows of the current table, "sortkey<TAB>row" per line
in_table=0; expect_sep=0; n=0; h1=0; tables=0; total_rows=0
terms_lower=(); avoid_lower=(); avoid_lines=()
flush_table() {
	[[ -z "$rows_buf" ]] && { in_table=0; return; }
	local sorted
	sorted="$(printf '%s' "$rows_buf" | LC_ALL=C sort -t $'\t' -k1,1)"  # keys are lowercased; byte order == code-point order (BSD sort mis-collates Cyrillic under UTF-8 locales)
	out+="$canon_header"$'\n'"$canon_sep"$'\n'
	while IFS=$'\t' read -r _ row; do [[ -n "$row" ]] && out+="$row"$'\n'; done <<< "$sorted"
	rows_buf=""; in_table=0
}
while IFS= read -r line || [[ -n "$line" ]]; do
	n=$((n+1))
	line="${line%$'\r'}"
	t="$(trim "$line")"
	if (( expect_sep )); then
		[[ "$t" =~ $sep_re ]] || fail "$n" "table header must be followed by a separator row"
		expect_sep=0; continue
	fi
	if [[ -z "$t" ]]; then
		(( in_table )) && flush_table
		[[ "$out" != *$'\n\n' && -n "$out" ]] && out+=$'\n'
		continue
	fi
	if [[ "$t" =~ ^#[[:space:]] ]]; then
		(( h1 )) && fail "$n" "only one H1 allowed"
		(( n > 1 )) && [[ -n "${out//[[:space:]]/}" ]] && fail "$n" "H1 must be the first line"
		h1=1; out+="$t"$'\n'; continue
	fi
	if [[ "$t" =~ ^##[[:space:]] ]]; then
		(( in_table )) && flush_table
		[[ "$t" =~ ^###+ ]] && fail "$n" "only H1 and H2 headings allowed — no cards, no sub-sections"
		out+="$t"$'\n'; continue
	fi
	if [[ "$t" =~ $header_re ]]; then
		(( in_table )) && flush_table
		in_table=1; expect_sep=1; tables=$((tables+1)); continue
	fi
	if [[ "$t" == \|* ]]; then
		(( in_table )) || fail "$n" "table row outside a table — every table starts with '$canon_header'"
		body="${t#|}"; body="${body%|}"; body="${body//\\|/$'\x01'}"
		pipes="${body//[^|]/}"
		(( ${#pipes} > 3 )) && fail "$n" "row has more than 4 cells (escape literal pipes as \\|)"
		(( ${#pipes} < 3 )) && fail "$n" "row has fewer than 4 cells"
		IFS='|' read -r c_term c_code c_def c_avoid <<< "$body"
		term="$(trim "${c_term//$'\x01'/\\|}")"; code="$(trim "${c_code//$'\x01'/\\|}")"; def="$(trim "${c_def//$'\x01'/\\|}")"; avoid="$(trim "${c_avoid//$'\x01'/\\|}")"
		[[ -z "$term" ]] && fail "$n" "empty Term"
		[[ "$term" == *'`'* || "$term" == \** ]] && fail "$n" "Term is plain text — no backticks or bold"
		tl="$(lower "$term")"
		for x in "${terms_lower[@]:-}"; do [[ "$x" == "$tl" ]] && fail "$n" "duplicate Term '$term'"; done
		terms_lower+=("$tl")
		[[ "$code" =~ ^\`[A-Za-z][A-Za-z0-9_]*\`$ || "$code" == "—" ]] || fail "$n" "Code must be a backticked identifier (\`Invoice\`, \`SKU\`) or — when the term never appears in code"
		[[ -z "$def" ]] && fail "$n" "empty Definition"
		[[ "$def" =~ [.!?]$ ]] || fail "$n" "Definition must end with a period"
		dl="$(lower "$def")"
		[[ "$dl" == "$tl"* ]] && add_warning "circular" "$n" "Definition starts with the term itself — state the genus (what kind of thing) instead"
		printf '%s' "$def" | grep -qE '[.!?][[:space:]]+[[:upper:]]|[.!?][[:space:]]+[А-ЯЁ]' && add_warning "long" "$n" "Definition has more than one sentence — keep the one that says what the thing is"
		printf '%s' "$dl" | grep -qE '^(this is|it is|is when|is where|это когда|это то|означает|refers to|означает,)' && add_warning "form" "$n" "Definition should be a noun phrase (genus + distinguishing trait), not a meta-sentence"
		[[ -z "$avoid" ]] && fail "$n" "empty Avoid — use — when there are no synonyms to ban"
		if [[ "$avoid" != "—" ]]; then
			IFS=',' read -ra parts <<< "$avoid"
			for p in "${parts[@]}"; do
				p="$(trim "$p")"; [[ -z "$p" ]] && continue
				pl="$(lower "$p")"
				[[ "$pl" == "$tl" ]] && fail "$n" "Avoid lists the Term itself: '$p'"
				avoid_lower+=("$pl"); avoid_lines+=("$n:$p")
			done
		fi
		rows_buf+="$tl"$'\t'"| $term | $code | $def | $avoid |"$'\n'
		total_rows=$((total_rows+1)); continue
	fi
	fail "$n" "prose is not allowed — the file holds only an H1, optional H2 group headings and tables"
done <<< "$content"
(( expect_sep )) && fail "$n" "table header without separator row at end of file"
(( in_table )) && flush_table
(( h1 )) || fail 1 "file must start with an H1 title (e.g. '# Glossary')"
(( total_rows > 0 )) || fail 1 "no glossary rows found"
i=0
for a in "${avoid_lower[@]:-}"; do
	[[ -z "$a" ]] && { i=$((i+1)); continue; }
	for x in "${terms_lower[@]}"; do [[ "$x" == "$a" ]] && fail "${avoid_lines[$i]%%:*}" "'${avoid_lines[$i]#*:}' is both a canonical Term and a banned synonym — pick one"; done
	i=$((i+1))
done
out="$(printf '%s' "$out" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"$'\n'

# --- write --------------------------------------------------------------------
dir="$(dirname "$path")"; mkdir -p "$dir" 2>/dev/null || { emit_error "write" 1 "cannot create $dir"; exit 1; }
tmp="$(mktemp "$dir/.glossary.XXXXXX")" || { emit_error "write" 1 "cannot create temp file"; exit 1; }
printf '%s' "$out" > "$tmp" && chmod 644 "$tmp" && mv -f "$tmp" "$path" || { rm -f "$tmp"; emit_error "write" 1 "cannot write $path"; exit 1; }

# --- AGENTS.md / CLAUDE.md pointer -------------------------------------------
rule="- Use the terms and \`Code\` identifiers from \`$path\` in code, docs and messages; never introduce a synonym — add the term to the glossary instead."
agents_res="skipped"; claude_res="skipped"
if [[ "$agents_mode" == "auto" ]]; then
	pointer() { # file -> absent|present|appended|error
		[[ -L "$1" ]] && { printf 'symlink'; return; }
		[[ -f "$1" ]] || { printf 'absent'; return; }
		grep -qE '^@AGENTS\.md[[:space:]]*$' "$1" 2>/dev/null && { printf 'import'; return; }
		grep -qiF 'glossary' "$1" 2>/dev/null && { printf 'present'; return; }
		[[ -s "$1" && "$(tail -c1 "$1")" != $'\n' ]] && printf '\n' >> "$1"
		printf '%s\n' "$rule" >> "$1" && printf 'appended' || printf 'error'
	}
	agents_res="$(pointer AGENTS.md)"
	claude_res="$(pointer CLAUDE.md)"
fi

printf '{"status":"ok","path":"%s","tables":%s,"rows":%s,"agents_md":"%s","claude_md":"%s","warnings":[%s]}\n' \
	"$(json_escape "$path")" "$tables" "$total_rows" "$agents_res" "$claude_res" "$warnings"
