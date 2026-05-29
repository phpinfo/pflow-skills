# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A catalog of [Agent Skills](https://docs.claude.com/en/docs/claude-code/skills) published for the [skills.sh](https://github.com/vercel-labs/skills) ecosystem. It contains no application code — each skill is consumed by installing it into a target project via `npx skills add phpinfo/pflow-skills`.

## Layout

Skills live under `skills/<name>/`. Each skill is a self-contained unit:

- `SKILL.md` — YAML frontmatter (`name`, `description`, `allowed-tools`) + minimal instructions for the agent.
- `scripts/` — executable helpers the skill calls. Scripts are referenced by their **installed** path (`.claude/skills/<name>/scripts/...`), not their path in this repo.

## Conventions that matter

- **Installed-path assumption in scripts.** `scripts/git-commit-push.sh` derives the project root as `SKILL_DIR/../../..`, which only resolves correctly once the skill is installed at `.claude/skills/<name>/`. Keep this 3-levels-up layout when adding scripts that need the consuming repo's root.
- **`allowed-tools` paths must match the skill folder name.** When renaming or adding a skill, update the `Bash(.claude/skills/<name>/scripts/...)` entries in `SKILL.md` to the new folder name, or the agent won't be granted permission to run them.
- **Keep SKILL.md minimal.** The body should be the shortest instruction set that still works; push detail/logic into scripts rather than prose. The `description` is the trigger signal — make it state what the skill does and when it fires.
- **Skill language.** `pflow-commit` produces Russian Conventional Commit messages in passive past tense; its instructions are written in Russian by design.

## Adding a skill

1. Create `skills/<name>/SKILL.md` and `skills/<name>/scripts/` (mark scripts executable).
2. Reference scripts via their installed path and list them in `allowed-tools`.
3. Add a row to the skills table in `README.md`.
