# pflow-skills

[![skills.sh](https://skills.sh/b/phpinfo/pflow-skills)](https://skills.sh/phpinfo/pflow-skills)

A curated catalog of [Agent Skills](https://docs.claude.com/en/docs/claude-code/skills) for everyday development workflows — installable into Claude Code, Cursor, OpenCode, and any [skills.sh](https://www.skills.sh/docs)-compatible agent.

Skills are small, composable folders of instructions and scripts that teach your agent to do one task well. No application code here — just the skills.

## Quickstart

Install the whole catalog into the current project (30 seconds):

```bash
npx skills add phpinfo/pflow-skills
```

Or pick a single skill:

```bash
npx skills add phpinfo/pflow-skills -s pflow-commit
```

| Flag | Effect |
| --- | --- |
| _(default)_ | Install into the project (`.claude/skills/`) |
| `-g`, `--global` | Install for every project (`~/.claude/skills/`) |
| `--copy` | Copy files instead of symlinking |

## Skills

| Skill | What it does |
| --- | --- |
| [`pflow-commit`](skills/pflow-commit) | Analyzes your working tree, writes a [Conventional Commit](https://www.conventionalcommits.org/) message, then commits and pushes. Invoked manually. |
| [`pflow-task-finish`](skills/pflow-task-finish) | Closes the current `mdtodo` task; when `pflow-commit` is installed, branches the work, commits it, and merges into `dev`. Degrades to mdtodo-only with a warning otherwise. Invoked manually. |

## Configuration

Most skills work with zero configuration. `pflow-task-finish` accepts optional settings, supplied as **CLI arguments** (passed by the agent to its script) or as **environment variables** — either exported in your shell or placed in a `.env` file at the project root, which the script loads automatically (parsed, never executed; values already set in the real environment take precedence).

### `pflow-task-finish`

**CLI arguments** (`task-finish.sh`):

| Argument | Required | Description |
| --- | --- | --- |
| `--message "<msg>"` | yes (when committing) | Conventional Commit message for the finished work. Ignored in fallback mode (no `pflow-commit`), where no commit happens. |
| `--slug "<slug>"` | no | Kebab-case name for the task branch (`task/<slug>`). Defaults to a slug derived from the current task title. |
| `--dev "<branch>"` | no | Branch to merge the task branch into. Highest-priority override of the dev branch (see below). |

**Environment variables** (env or `.env`):

| Variable | Default | Description |
| --- | --- | --- |
| `PFLOW_TASKS_MDTODO_FILE` | _(mdtodo's own default, `todo.md`)_ | Path to the Markdown todo list. Exported as `MDTODO_FILE` once before any `mdtodo` call, so the whole flow operates on this file. |
| `PFLOW_GIT_DEV_BRANCH` | `dev` | Branch the task branch is merged into. If the chosen branch does not exist, the work merges into the branch you started on. |
| `MDTODO_FILE` | `todo.md` | Read directly by the `mdtodo` CLI. `PFLOW_TASKS_MDTODO_FILE` sets this for you; set it yourself if you prefer. |

**Dev-branch precedence:** `--dev` flag → `PFLOW_GIT_DEV_BRANCH` → autodetected `dev`/`develop` → default `dev`. If the resolved branch is absent, the merge target falls back to the branch you started on.

> `pflow-task-finish` reuses `pflow-commit`'s git logic. Without `pflow-commit` installed it still closes the task via `mdtodo`, prints a warning, and skips all git steps. `pflow-commit` itself takes no configuration.

## How it works

Each skill is a self-contained folder under `skills/`:

```
skills/
└── <name>/
    ├── SKILL.md        # frontmatter (name, description, allowed-tools) + instructions
    └── scripts/        # executable helpers the skill calls
```

The agent reads every `SKILL.md` description up front and triggers the matching skill when the task fits. Heavy logic lives in `scripts/` so the prompt stays short and reliable.

## Creating a skill

1. Add `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`, and `allowed-tools` for any scripts).
2. Make scripts executable and reference them by their **installed** path — `.claude/skills/<name>/scripts/...`.
3. Add a row to the [Skills](#skills) table above.

Write the `description` to say plainly *what the skill does and when it fires* — it's the signal the agent uses to decide whether to reach for it.

## License

MIT
