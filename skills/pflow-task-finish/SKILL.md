---
name: pflow-task-finish
description: Closes the current mdtodo task; when pflow-commit is installed, branches the work, commits it, and merges into dev. Invoked manually only.
license: MIT
allowed-tools:
  - Bash(.agents/skills/pflow-commit/scripts/git-commit-context.sh)
  - Bash(.agents/skills/pflow-task-finish/scripts/task-finish.sh:*)
---

On any failure (non-zero exit, or an `error` field / `"status":"error"` in the JSON) print `⚠️ <message>` and stop.

## Steps

1. **Compose MESSAGE** (see format below). Run `.agents/skills/pflow-commit/scripts/git-commit-context.sh` (read-only) and write a Conventional Commit message for the diff. If the script reports no changes — or is missing because `pflow-commit` isn't installed — use a minimal message like `chore: finish task <title>`. Optionally add a kebab-case SLUG; otherwise the script derives one from the task title.
2. **Run once:** `.agents/skills/pflow-task-finish/scripts/task-finish.sh --message "MESSAGE" [--slug "SLUG"] [--dev "BRANCH"]`. It prints one JSON line; act on `status`:
   - `no_current_task` — tell the user there's nothing to finish.
   - `closed_no_git` — task closed, git skipped; print the JSON `warning` so they install `pflow-commit`.
   - `finished` — report the result:

   ```text
   ✅ Task closed: <task>
   Branch: <task_branch> → merged into <dev_branch> (<merge_status>)
   Commit: <commit_hash> (<commit_status>) | push task: <push_status_task> | push dev: <push_status_dev>
   Cleanup: local <delete_local_status> | remote <delete_remote_status>
   ```

## Message format (Conventional Commits)

`<type>[(scope)][!]: <description>` plus an optional blank line, body, and footer(s).

- **Language: the entire message (description, body, and footers) MUST always be written in English — regardless of the conversation language — unless the user explicitly requests another language.**
- Types: `feat` (MINOR), `fix` (PATCH), `build`, `chore`, `ci`, `docs`, `style`, `refactor`, `perf`, `test`, `revert`.
- Breaking change: `!` in the header or a `BREAKING CHANGE: ...` footer (MAJOR).
- `scope` — only when it adds value. Pick the narrowest correct type; split unrelated types into separate commits.
- Description — short, in English, imperative mood ("add", not "added").

Examples: `feat: add user page` · `fix(parser): handle empty input` · `feat!: remove legacy auth flow`

## Gotchas

- **`git add -A`** — the commit includes ALL working-tree changes, not just the closed-task markdown; account for that in MESSAGE.
- **Branch reuse** — when run from a non-dev branch (e.g. one created by `pflow-task-next`), it commits and merges THAT branch and ignores `--slug`. Only when finishing straight from the dev branch does it create `task/<slug>`.
- **Merge conflict** (`error.step == "git merge"`) leaves the repo on the dev branch mid-merge to resolve by hand.
- **Branch cleanup** — after a successful merge the task branch is deleted locally (`git branch -d`) and on the remote. It's best-effort: failures surface as `failed` in `delete_local_status`/`delete_remote_status` but don't fail the task. No deletion happens when finishing straight on the dev branch (`merge_status == "same_branch"`).
