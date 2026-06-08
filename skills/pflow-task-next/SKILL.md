---
name: pflow-task-next
description: Takes the next mdtodo task into progress and creates a git branch named for it. Invoked manually only.
license: MIT
allowed-tools:
  - Bash(.agents/skills/pflow-task-next/scripts/task-next-context.sh)
  - Bash(.agents/skills/pflow-task-next/scripts/task-next-branch.sh:*)
---

On any failure (non-zero exit, or `"status":"error"` in the JSON) print `⚠️ <error.message>` and stop.

## Steps

1. **Take the task.** Run `.agents/skills/pflow-task-next/scripts/task-next-context.sh`. It prints one JSON line; act on `status`:
   - `no_tasks` — tell the user there's nothing to take and stop.
   - `error` — print `⚠️ <error.message>` and stop.
   - `ready` — continue with `task.title` and `task.description`.
2. **Name the branch** from the task (rules below) → `BRANCH = TYPE/SLUG`.
3. **Create it:** `.agents/skills/pflow-task-next/scripts/task-next-branch.sh --branch "BRANCH"`. On `status:created`, reply:

   ```text
   ✅ Task in progress: <task.title>
   Branch: <branch> (from <previous_branch>)
   ```

## Branch naming

- `TYPE` — one of `feature` (new functionality), `fix` (bug fix), `chore` (maintenance).
- `SLUG` — short kebab-case English summary of the task title, git-safe (`a-z0-9-`).
- Result: `TYPE/SLUG`, e.g. `feature/login-form`.

## Gotchas

- The context script requires a clean working tree on the dev branch (`PFLOW_GIT_DEV_BRANCH`, default `dev`) and no task already in progress — otherwise it errors.
- `mdtodo take` already marked the task `[~]`; that working-tree change is carried onto the new branch and committed later by `pflow-task-finish`.
