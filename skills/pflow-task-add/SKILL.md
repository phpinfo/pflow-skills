---
name: pflow-task-add
description: Adds a new task to the mdtodo task list. The agent clarifies the task's essence, formulates a concise title and description with expected result, then adds it via mdtodo. Invoked manually only.
license: MIT
allowed-tools:
  - Bash(.agents/skills/pflow-task-add/scripts/task-add-run.sh:*)
---

On any failure (non-zero exit, or `"status":"error"` in the JSON) print `⚠️ <error.message>` and stop.

## Steps

1. **Clarify.** You MUST understand (a) what the task is about and (b) the expected result. If the user's description is ambiguous, ask — never assume. Formulate:
   - `TITLE` — concise task name (single line).
   - `DESCRIPTION` — expected result and key details (optional, may be multiline).
   - `VERSION` — version tag in `vX.Y.Z` format (optional, only if the user specifies one).
2. **Add.** Run `.agents/skills/pflow-task-add/scripts/task-add-run.sh --title "TITLE" [--description "DESCRIPTION"] [--version "VERSION"]` → JSON `{status:"ok",title,version,mdtodo_file,has_description}`. Reply:

   ```text
   ✅ Task added: <title>
   File: <mdtodo_file>
   ```

## Gotchas

- If the tasks file does not exist, the script creates an empty file before adding the task.
- `--description` inserts indented lines under the task in the markdown file, visible via `mdtodo list`.
