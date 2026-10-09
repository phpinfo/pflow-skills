# pflow-skills

A catalog of [Agent Skills](https://docs.claude.com/en/docs/claude-code/skills) for development workflows: commits,
an `mdtodo` task flow, changelogs, Go and Ansible rules, project docs. Installs into Claude Code, Cursor, OpenCode and
any other [skills.sh](https://www.skills.sh/docs)-compatible agent.

[![skills.sh](https://skills.sh/b/phpinfo/pflow-skills)](https://skills.sh/phpinfo/pflow-skills)

## Quickstart

Install the whole catalog into the current project:

```bash
npx skills add phpinfo/pflow-skills
```

Install a single skill:

```bash
npx skills add phpinfo/pflow-skills -s pflow-commit
```

| Flag | Effect |
| --- | --- |
| _(none)_ | Install into the project (`.agents/skills/`) |
| `-g`, `--global` | Install for every project (`~/.agents/skills/`) |
| `--copy` | Copy files instead of symlinking |

Skills with scripts call them by the path `.agents/skills/<name>/scripts/...`, so keep `.agents/skills/` as the
install location; `npx skills` links agent folders such as `.claude/skills/` to it.

## Skills

Manual skills run only when you call them, for example `/pflow-commit`. The agent starts the other skills itself
when the task matches the trigger.

| Skill | What it does | Runs |
| --- | --- | --- |
| [`pflow-commit`](skills/pflow-commit) | Reads the working tree, writes a one-line [Conventional Commit](https://www.conventionalcommits.org/) message, commits and pushes. | Manual |
| [`pflow-task-add`](skills/pflow-task-add) | Clarifies a new task with you and adds it to the `mdtodo` list with a title, description and expected result. | Manual |
| [`pflow-task-next`](skills/pflow-task-next) | Takes the next `mdtodo` task into progress and creates a `feature/`, `fix/` or `chore/` branch for it. | Manual |
| [`pflow-task-plan`](skills/pflow-task-plan) | Builds a step-by-step implementation plan for the active `mdtodo` task and saves it to a file. Does not write code. | Manual |
| [`pflow-task-implement`](skills/pflow-task-implement) | Executes the saved plan step by step with checks. Does not plan, commit or close the task. | Manual |
| [`pflow-task-finish`](skills/pflow-task-finish) | Closes the active `mdtodo` task; with `pflow-commit` installed, also commits the work, merges it into the dev branch and deletes the task branch. | Manual |
| [`pflow-changelog`](skills/pflow-changelog) | Writes a [Keep a Changelog](https://keepachangelog.com/) entry for the current feature version from finished tasks and commits, prepends it to `CHANGELOG.md`, commits and pushes. | Manual |
| [`pflow-refactor`](skills/pflow-refactor) | Studies code and proposes a minimal refactoring: current state, target state, naming, dependencies, migration and trade-offs. Does not change code. | Manual |
| [`pflow-grill`](skills/pflow-grill) | Interviews you about a plan or decision in rounds of questions with lettered options and a recommended answer. Adapted from [mattpocock/skills `grilling`](https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling/SKILL.md). | "grill" phrases |
| [`pflow-bro`](skills/pflow-bro) | Re-explains the previous answer in plain language, with the same facts and no tools. Adapted from [luchasarie/bro-skill](https://github.com/luchasarie/bro-skill/blob/main/SKILL.md). | `/bro` |
| [`pflow-golang`](skills/pflow-golang) | Go rules for writing, reviewing and refactoring code, plus idioms for urfave/cli, testify, mockery, samber/lo and connectrpc when `go.mod` uses them. | Go tasks |
| [`pflow-golang-troubleshoot`](skills/pflow-golang-troubleshoot) | Finds the root cause of Go panics, wrong results, flaky tests, deadlocks, races, leaks, CPU and memory issues, build and module errors, using pprof, the race detector and delve. | Go code misbehaves |
| [`pflow-golang-setup`](skills/pflow-golang-setup) | Creates or audits Go project infrastructure: layout, `go.mod`, golangci-lint v2, Taskfile or Makefile, GitHub Actions. Adds what is missing and keeps existing files. | Manual |
| [`pflow-agents`](skills/pflow-agents) | Writes or rewrites a short `AGENTS.md` with commands, conventions and pitfalls the agent cannot derive from the code, checks its size and copies it to `CLAUDE.md` or imports it there with `@AGENTS.md`. | Manual |
| [`pflow-ansible`](skills/pflow-ansible) | Rules for playbooks, roles, inventories, vault and Jinja2 templates, based on the Ansible docs, Red Hat good practices and the ansible-lint production profile; finishes with `ansible-lint` and `--syntax-check`. | Ansible tasks |
| [`pflow-glossary`](skills/pflow-glossary) | Creates or extends `GLOSSARY.md` with terms, code identifiers, definitions and banned synonyms, and adds a rule to use it to `AGENTS.md`/`CLAUDE.md`. | Glossary changes, new terms |
| [`pflow-docs`](skills/pflow-docs) | Writing rules for READMEs, `docs/` and other docs for people: README structure and plain style, based on [Wikipedia: Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing) and [blader/humanizer](https://github.com/blader/humanizer). Russian docs also follow Simplified Technical Russian (ГОСТ Р 58049-2017). | Writing or reviewing docs |
| [`pflow-backlog`](skills/pflow-backlog) | Adds a task to `docs/backlog/` as a numbered plain-text file, or deletes it when done or moved into a spec. | "add to backlog" phrases |
| [`pflow-skill`](skills/pflow-skill) | Creates or edits skills in this catalog and checks frontmatter and the 120-character line limit. | Edits under `skills/<name>/` |

## Requirements

| Skill | Requires |
| --- | --- |
| `pflow-commit` | `git` |
| `pflow-task-add`, `pflow-task-plan` | `mdtodo` CLI |
| `pflow-task-implement` | `mdtodo`; a plan file from `pflow-task-plan` |
| `pflow-task-next` | `git`, `mdtodo`; a clean working tree on the dev branch |
| `pflow-task-finish` | `mdtodo`; `git` and `pflow-commit` for the git steps, otherwise it only closes the task and prints a warning |
| `pflow-changelog` | `git`, `mdtodo`, `pflow-commit`, `PFLOW_FEATURES_MDTODO_FILE`; no uncommitted changes, on the dev branch |
| `pflow-golang-troubleshoot` | Go toolchain in `PATH` |
| `pflow-golang`, `pflow-golang-setup` | Go toolchain is optional; the scripts report its version when it is present |

Other skills have no requirements. The Go scripts only read `go.mod` and the repository layout; they do not build,
test or write files.

## Configuration

Skills that use `mdtodo` or branches read environment variables. Set them in your shell or in a `.env` file at the
project root. The scripts parse `.env` without executing it, and variables already set in the shell win.

| Variable | Default | Used by | Meaning |
| --- | --- | --- | --- |
| `PFLOW_TASKS_MDTODO_FILE` | `MDTODO_FILE`, then `todo.md` | `pflow-task-*`, `pflow-changelog` | Path to the Markdown task list. Scripts pass it to every `mdtodo` call as `MDTODO_FILE`. |
| `MDTODO_FILE` | `todo.md` | `mdtodo` CLI | Task list path read by `mdtodo` itself. Overridden by `PFLOW_TASKS_MDTODO_FILE`. |
| `PFLOW_TASKS_PLAN_FILE` | `./tmp/pflow-tasks-plan.md` | `pflow-task-plan`, `pflow-task-implement` | Plan file path. `pflow-task-plan` creates missing parent directories. |
| `PFLOW_FEATURES_MDTODO_FILE` | none, required | `pflow-changelog` | Path to the Markdown feature list; the current feature gives the changelog version. |
| `PFLOW_GIT_DEV_BRANCH` | `dev` | `pflow-task-next`, `pflow-task-finish`, `pflow-changelog` | Dev branch. `pflow-task-next` and `pflow-changelog` stop when run on another branch; `pflow-task-finish` merges into it. |
| `PFLOW_GIT_MAIN_BRANCH` | `main` if only `main` exists, otherwise `master` | `pflow-changelog` | Release branch; the changelog uses commits from this branch to `HEAD`. |

### Commit messages

`pflow-commit`, `pflow-task-finish` and `pflow-changelog` commit through `git-lib.sh`, which keeps only the first
non-blank line of the message. Bodies, footers and `Co-Authored-By` trailers never reach the history.

### Dev branch in pflow-task-finish

`pflow-task-finish` picks the merge target in this order: the `--dev` argument, `PFLOW_GIT_DEV_BRANCH`, `develop` when
it exists and `dev` does not, then `dev`. If that branch does not exist, the work stays in the branch you started on.

Run from a work branch, for example one created by `pflow-task-next`, the skill commits and merges that branch. Run
from the dev branch, it first creates `task/<slug>`. After a successful merge it deletes the task branch locally and
on the remote.

### Script arguments

The agent passes these arguments; you need them only to run a script by hand.

| Script | Argument | Meaning |
| --- | --- | --- |
| `task-add-run.sh` | `--title` (required) | Task title, one line. |
| | `--description` | Expected result and details, added as indented lines under the task. |
| | `--version` | Version tag `vX.Y.Z`, only when you name one. |
| `task-next-branch.sh` | `--branch` (required) | Branch to create, for example `feature/login-form`. |
| `task-finish.sh` | `--message` | Commit message; required when the skill commits. |
| | `--slug` | Name for `task/<slug>`; defaults to a slug of the task title. Ignored on a work branch. |
| | `--dev` | Merge target; overrides `PFLOW_GIT_DEV_BRANCH`. |
| `changelog-context.sh` | `--allow-release-dirty` | Skips the uncommitted-changes check. The skill itself does not pass it. |

## Skill layout

```text
skills/
└── <name>/
    ├── SKILL.md        # frontmatter (name, description, allowed-tools) + instructions
    ├── scripts/        # executable helpers the skill calls
    └── references/     # knowledge files the agent reads on demand
```

The agent reads every `SKILL.md` description up front and starts the skill whose description matches the task.
Deterministic logic lives in `scripts/`, which keeps `SKILL.md` short.

## Creating a skill

1. Add `skills/<name>/SKILL.md` with YAML frontmatter: `name`, `description`, and `allowed-tools` for each script.
   Add `disable-model-invocation: true` if the skill must run only when called; a description that says "manual"
   does not stop the agent.
2. Make scripts executable and reference them by the installed path `.agents/skills/<name>/scripts/...`.
3. Keep lines in skill files within 120 characters; tables, code blocks and lines with URLs are exempt.
4. Add a row to the [Skills](#skills) table.

The `description` states what the skill does and when it runs; the agent picks skills by it. The `pflow-skill` skill
follows these steps and checks frontmatter and line length.

## License

[MIT](LICENSE)
