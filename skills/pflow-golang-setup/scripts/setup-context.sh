#!/usr/bin/env bash
# setup-context.sh — audits the project scaffolding of the consuming Go project
# (layout, lint config, task runner, CI, hygiene files) and prints one JSON line
# with what is present and what is missing. Read-only.
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

gomod="$ROOT_DIR/go.mod"
has_gomod=0; module=""; go_version=""
if [[ -f "$gomod" ]]; then
	has_gomod=1
	module="$(awk '$1=="module"{print $2; exit}' "$gomod")"
	go_version="$(awk '$1=="go"{print $2; exit}' "$gomod")"
fi
toolchain="$(command -v go >/dev/null 2>&1 && go version 2>/dev/null | awk '{print $3}')"
latest_local="$toolchain"

golangci=""; golangci_version=""
for f in .golangci.yml .golangci.yaml .golangci.toml .golangci.json; do
	[[ -f "$ROOT_DIR/$f" ]] && golangci="$f" && break
done
[[ -n "$golangci" ]] && golangci_version="$(grep -E '^version:' "$ROOT_DIR/$golangci" 2>/dev/null | head -1 | sed -E 's/^version:[[:space:]]*"?([^"]*)"?/\1/')"

runner=""
for f in Taskfile.yml Taskfile.yaml Makefile justfile; do [[ -f "$ROOT_DIR/$f" ]] && runner="$f" && break; done

workflows=()
if [[ -d "$ROOT_DIR/.github/workflows" ]]; then
	while IFS= read -r w; do workflows+=("$(basename "$w")"); done < <(find "$ROOT_DIR/.github/workflows" -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort)
fi
ci_other=()
[[ -f "$ROOT_DIR/.gitlab-ci.yml" ]] && ci_other+=(".gitlab-ci.yml")
[[ -d "$ROOT_DIR/.circleci" ]] && ci_other+=(".circleci")

remote_host=""
if command -v git >/dev/null 2>&1; then
	url="$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null)"
	case "$url" in *github.com*) remote_host="github" ;; *gitlab*) remote_host="gitlab" ;; *bitbucket*) remote_host="bitbucket" ;; "") remote_host="" ;; *) remote_host="other" ;; esac
fi

dirs=()
for d in cmd internal pkg api tests testdata docs scripts; do [[ -d "$ROOT_DIR/$d" ]] && dirs+=("$d"); done
mains="$(grep -rlI --include='*.go' --exclude-dir=vendor --exclude-dir=.git '^package main$' "$ROOT_DIR" 2>/dev/null | xargs -I{} dirname {} 2>/dev/null | sort -u | sed "s#^$ROOT_DIR/##" | tr '\n' ' ' | sed 's/ $//')"

files_present=(); files_missing=()
for f in .gitignore .editorconfig README.md LICENSE CHANGELOG.md go.work Dockerfile .goreleaser.yml .goreleaser.yaml .dockerignore; do
	if [[ -f "$ROOT_DIR/$f" ]]; then files_present+=("$f"); else files_missing+=("$f"); fi
done
dependabot=0; [[ -f "$ROOT_DIR/.github/dependabot.yml" ]] && dependabot=1
renovate=0; for f in renovate.json .renovaterc .renovaterc.json; do [[ -f "$ROOT_DIR/$f" ]] && renovate=1; done
gotools="$(awk '$1=="tool" && $2!="("{print $2} /^tool \(/{b=1;next} b&&/^\)/{b=0} b{print $1}' "$gomod" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"
vendor=0; [[ -d "$ROOT_DIR/vendor" ]] && vendor=1

missing=()
((has_gomod)) || missing+=("go.mod")
[[ -z "$golangci" ]] && missing+=("golangci-lint config")
[[ -z "$runner" ]] && missing+=("task runner (Taskfile/Makefile)")
[[ ${#workflows[@]} -eq 0 && ${#ci_other[@]} -eq 0 ]] && missing+=("CI workflow")
[[ ! -f "$ROOT_DIR/.gitignore" ]] && missing+=(".gitignore")
[[ ! -f "$ROOT_DIR/README.md" ]] && missing+=("README.md")
(( dependabot || renovate )) || missing+=("dependency updates (Dependabot/Renovate)")

printf '{"status":"ok","root":%s,"module":%s,"go_version":%s,"toolchain":%s,"golangci_config":%s,"golangci_config_version":%s,"task_runner":%s,"github_workflows":%s,"ci_other":%s,"remote_host":%s,"dirs":%s,"main_packages":%s,"files_present":%s,"go_tools":%s,"vendor":%s,"dependabot":%s,"renovate":%s,"missing":%s}\n' \
	"$(json_str "$ROOT_DIR")" "$(json_str "$module")" "$(json_str "$go_version")" "$(json_str "$toolchain")" \
	"$(json_str "$golangci")" "$(json_str "$golangci_version")" "$(json_str "$runner")" "$(json_arr "${workflows[@]:-}")" \
	"$(json_arr "${ci_other[@]:-}")" "$(json_str "$remote_host")" "$(json_arr "${dirs[@]:-}")" "$(json_str "$mains")" \
	"$(json_arr "${files_present[@]:-}")" "$(json_str "$gotools")" "$(json_bool $vendor)" "$(json_bool $dependabot)" "$(json_bool $renovate)" "$(json_arr "${missing[@]:-}")"
