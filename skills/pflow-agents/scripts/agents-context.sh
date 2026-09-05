#!/usr/bin/env bash
# agents-context.sh — read-only audit of the consuming project for writing AGENTS.md.
# Prints one JSON line: existing agent files, docs to avoid duplicating, stack markers,
# task-runner targets, tooling configs, CI, monorepo signals. Never writes.
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
json_arr() { local out="" x; for x in "$@"; do [[ -n "$x" ]] && out+="${out:+,}\"$(json_escape "$x")\""; done; printf '[%s]' "$out"; }
json_bool() { if (( $1 )); then printf true; else printf false; fi; }
emit_error() {
	printf '{"status":"error","error":{"step":"%s","exit_code":%d,"message":"%s"}}\n' "$(json_escape "$1")" "$2" "$(json_escape "$3")"
}
count_lines() { if [[ -f "$1" ]]; then wc -l < "$1" | tr -d ' '; else printf 0; fi; }
count_bytes() { if [[ -f "$1" ]]; then wc -c < "$1" | tr -d ' '; else printf 0; fi; }

cd "$ROOT_DIR" || { emit_error "chdir" 1 "cannot enter project root: $ROOT_DIR"; exit 1; }

# --- git ---------------------------------------------------------------------
default_branch=""; remote_host=""; gitignored=()
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	default_branch="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
	if [[ -z "$default_branch" ]]; then
		for b in main master dev develop trunk; do git show-ref --verify --quiet "refs/heads/$b" && { default_branch="$b"; break; }; done
	fi
	url="$(git remote get-url origin 2>/dev/null)"
	case "$url" in *github.com*) remote_host="github" ;; *gitlab*) remote_host="gitlab" ;; *bitbucket*) remote_host="bitbucket" ;; "") ;; *) remote_host="other" ;; esac
	for f in AGENTS.md CLAUDE.md; do git check-ignore -q "$f" 2>/dev/null && gitignored+=("$f"); done
fi

# --- existing agent instruction files ---------------------------------------
agents_exists=0; [[ -f AGENTS.md ]] && agents_exists=1
claude_kind="absent"
if [[ -L CLAUDE.md ]]; then
	claude_kind="symlink"
elif [[ -f CLAUDE.md ]]; then
	if grep -qE '^@AGENTS\.md[[:space:]]*$' CLAUDE.md 2>/dev/null; then claude_kind="import"
	elif ((agents_exists)) && cmp -s AGENTS.md CLAUDE.md; then claude_kind="identical"
	else claude_kind="different"; fi
fi

other_rules=()
for f in .cursorrules .cursor/rules .github/copilot-instructions.md .github/instructions GEMINI.md \
	.windsurfrules .windsurf/rules .clinerules .claude/CLAUDE.md .claude/rules CLAUDE.local.md AGENTS.override.md .codex/AGENTS.md; do
	[[ -e "$f" ]] && other_rules+=("$f")
done
nested_agents=()
while IFS= read -r f; do nested_agents+=("${f#./}"); done < <(find . -mindepth 2 -maxdepth 4 \( -name AGENTS.md -o -name CLAUDE.md \) \
	-not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path './.git/*' -not -path './.agents/*' -not -path './.claude/*' 2>/dev/null | sort)

# --- human docs the agent must not duplicate --------------------------------
docs=()
for f in README.md README.rst README CONTRIBUTING.md ARCHITECTURE.md DEVELOPMENT.md SECURITY.md CHANGELOG.md docs doc; do
	[[ -e "$f" ]] && docs+=("$f")
done
readme_lines="$(count_lines README.md)"

# --- stack manifests ---------------------------------------------------------
manifests=()
for f in package.json go.mod go.work pyproject.toml setup.py requirements.txt Pipfile composer.json Cargo.toml Gemfile \
	pom.xml build.gradle build.gradle.kts mix.exs Package.swift pubspec.yaml deno.json CMakeLists.txt; do
	[[ -f "$f" ]] && manifests+=("$f")
done
pm=""
if [[ -f package.json ]]; then
	pm="$(grep -oE '"packageManager"[[:space:]]*:[[:space:]]*"[^"@]+' package.json 2>/dev/null | sed -E 's/.*"//')"
	if [[ -z "$pm" ]]; then
		if [[ -f pnpm-lock.yaml ]]; then pm="pnpm"; elif [[ -f yarn.lock ]]; then pm="yarn"
		elif [[ -f bun.lockb || -f bun.lock ]]; then pm="bun"; elif [[ -f package-lock.json ]]; then pm="npm"; fi
	fi
elif [[ -f uv.lock ]]; then pm="uv"; elif [[ -f poetry.lock ]]; then pm="poetry"; elif [[ -f Pipfile.lock ]]; then pm="pipenv"
elif [[ -f pdm.lock ]]; then pm="pdm"
fi
versions=()
for f in .tool-versions .nvmrc .node-version .python-version .ruby-version .mise.toml .java-version rust-toolchain.toml; do
	[[ -f "$f" ]] && versions+=("$f")
done

# --- task runners and their targets -----------------------------------------
runner=""; targets=()
if [[ -f Taskfile.yml || -f Taskfile.yaml ]]; then
	runner="task"; tf=Taskfile.yml; [[ -f Taskfile.yaml ]] && tf=Taskfile.yaml
	while IFS= read -r t; do targets+=("$t"); done < <(awk '/^tasks:/{b=1;next} b&&/^[^[:space:]]/{b=0} b&&/^  [A-Za-z0-9_:-]+:/{sub(/^  /,"");sub(/:.*/,"");print}' "$tf" 2>/dev/null)
elif [[ -f Makefile || -f makefile || -f GNUmakefile ]]; then
	runner="make"; mf=Makefile; [[ -f GNUmakefile ]] && mf=GNUmakefile; [[ -f makefile ]] && mf=makefile
	while IFS= read -r t; do targets+=("$t"); done < <(grep -oE '^[A-Za-z0-9_./-]+:([^=]|$)' "$mf" 2>/dev/null | sed -E 's/:.*//' | grep -vE '^\.' | sort -u)
elif [[ -f justfile || -f Justfile ]]; then
	runner="just"; jf=justfile; [[ -f Justfile ]] && jf=Justfile
	while IFS= read -r t; do targets+=("$t"); done < <(grep -oE '^[A-Za-z0-9_-]+( [^:]*)?:' "$jf" 2>/dev/null | sed -E 's/[ :].*//' | sort -u)
fi
json_keys() { # $1=file $2=top-level object key -> one key per line
	if command -v node >/dev/null 2>&1; then
		node -e 'try{const o=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))[process.argv[2]]||{};console.log(Object.keys(o).join("\n"))}catch(e){}' "$1" "$2" 2>/dev/null
	elif command -v python3 >/dev/null 2>&1; then
		python3 -c 'import json,sys
try: print("\n".join(json.load(open(sys.argv[1])).get(sys.argv[2],{}).keys()))
except Exception: pass' "$1" "$2" 2>/dev/null
	else
		tr -d '\n' < "$1" | grep -oE "\"$2\"[[:space:]]*:[[:space:]]*\{[^}]*\}" | grep -oE '"[^"]+"[[:space:]]*:' | sed -E 's/^"//; s/"[[:space:]]*:$//' | grep -vx "$2"
	fi
}
scripts=()
[[ -f package.json ]] && while IFS= read -r s; do [[ -n "$s" ]] && scripts+=("$s"); done < <(json_keys package.json scripts)
composer_scripts=()
[[ -f composer.json ]] && while IFS= read -r s; do [[ -n "$s" ]] && composer_scripts+=("$s"); done < <(json_keys composer.json scripts)

# --- tooling configs (things a linter/hook already enforces) -----------------
tooling=()
for f in .editorconfig .eslintrc .eslintrc.js .eslintrc.cjs .eslintrc.json eslint.config.js eslint.config.mjs eslint.config.ts \
	.prettierrc .prettierrc.json .prettierrc.js prettier.config.js biome.json biome.jsonc .golangci.yml .golangci.yaml ruff.toml \
	.ruff.toml .flake8 mypy.ini .pylintrc phpstan.neon phpstan.neon.dist psalm.xml .php-cs-fixer.php .php-cs-fixer.dist.php \
	rustfmt.toml clippy.toml .rubocop.yml .pre-commit-config.yaml lefthook.yml .husky commitlint.config.js commitlint.config.cjs \
	.commitlintrc .commitlintrc.json .env.example .env.sample docker-compose.yml docker-compose.yaml compose.yml compose.yaml \
	Dockerfile .devcontainer tsconfig.json .stylelintrc vitest.config.ts jest.config.js jest.config.ts pytest.ini tox.ini \
	phpunit.xml phpunit.xml.dist .releaserc .goreleaser.yml; do
	[[ -e "$f" ]] && tooling+=("$f")
done
[[ -f pyproject.toml ]] && grep -qE '^\[tool\.(ruff|black|mypy|pytest|isort)' pyproject.toml 2>/dev/null && tooling+=("pyproject.toml[tool.*]")

# --- CI ----------------------------------------------------------------------
ci=()
if [[ -d .github/workflows ]]; then
	while IFS= read -r w; do ci+=(".github/workflows/$(basename "$w")"); done < <(find .github/workflows -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort)
fi
for f in .gitlab-ci.yml .circleci bitbucket-pipelines.yml Jenkinsfile azure-pipelines.yml .drone.yml; do [[ -e "$f" ]] && ci+=("$f"); done

# --- monorepo signals and layout --------------------------------------------
mono=()
for f in pnpm-workspace.yaml lerna.json nx.json turbo.json go.work rush.json; do [[ -f "$f" ]] && mono+=("$f"); done
[[ -f package.json ]] && grep -q '"workspaces"' package.json 2>/dev/null && mono+=("package.json:workspaces")
for d in packages apps services libs modules; do [[ -d "$d" ]] && mono+=("$d/"); done
top_dirs=()
while IFS= read -r d; do top_dirs+=("${d#./}"); done < <(find . -mindepth 1 -maxdepth 1 -type d -not -name '.*' -not -name node_modules -not -name vendor 2>/dev/null | sort)

installed_skills=()
while IFS= read -r s; do installed_skills+=("$s"); done < <(for d in .agents/skills/*/ .claude/skills/*/; do [[ -d "$d" ]] && basename "$d"; done | sort -u)

printf '{"status":"ok","root":%s,"default_branch":%s,"remote_host":%s,"gitignored":%s,"agents_md":{"exists":%s,"lines":%s,"bytes":%s},"claude_md":{"kind":%s,"lines":%s},"other_rule_files":%s,"nested_agent_files":%s,"docs":%s,"readme_lines":%s,"manifests":%s,"package_manager":%s,"version_files":%s,"task_runner":%s,"runner_targets":%s,"npm_scripts":%s,"composer_scripts":%s,"tooling":%s,"ci":%s,"monorepo":%s,"top_dirs":%s,"installed_skills":%s}\n' \
	"$(json_str "$ROOT_DIR")" "$(json_str "$default_branch")" "$(json_str "$remote_host")" "$(json_arr "${gitignored[@]:-}")" \
	"$(json_bool $agents_exists)" "$(count_lines AGENTS.md)" "$(count_bytes AGENTS.md)" \
	"$(json_str "$claude_kind")" "$(count_lines CLAUDE.md)" "$(json_arr "${other_rules[@]:-}")" "$(json_arr "${nested_agents[@]:-}")" \
	"$(json_arr "${docs[@]:-}")" "$readme_lines" "$(json_arr "${manifests[@]:-}")" "$(json_str "$pm")" "$(json_arr "${versions[@]:-}")" \
	"$(json_str "$runner")" "$(json_arr "${targets[@]:-}")" "$(json_arr "${scripts[@]:-}")" "$(json_arr "${composer_scripts[@]:-}")" \
	"$(json_arr "${tooling[@]:-}")" "$(json_arr "${ci[@]:-}")" "$(json_arr "${mono[@]:-}")" "$(json_arr "${top_dirs[@]:-}")" "$(json_arr "${installed_skills[@]:-}")"
