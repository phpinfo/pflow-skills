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
