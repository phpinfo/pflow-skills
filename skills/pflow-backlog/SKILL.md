---
name: pflow-backlog
description: 'Manages docs/backlog: adds a task as a numbered Markdown file (<NNN>-<slug>.md) or deletes it when done or moved into a spec. Fires on "добавь в бэклог" / "add to backlog" or when a fix is deferred.'
license: MIT
allowed-tools:
  - Bash(.agents/skills/pflow-backlog/scripts/backlog-add.sh:*)
  - Bash(.agents/skills/pflow-backlog/scripts/backlog-remove.sh:*)
---

If `backlog-add.sh` or `backlog-remove.sh` fails (non-zero exit or `"status":"error"` in its JSON) print `⚠️ <error.message>` and stop — except a `slug` error from `backlog-add.sh`: invent another slug and retry until the script accepts it.

## Steps

1. **Clarify.** You MUST know what to record and why. If the request is ambiguous, ask — never assume.
2. **Write the task.** Plain text for people, in the project's documentation language (from `AGENTS.md`/`CLAUDE.md` or the existing docs; else the conversation language). No title, frontmatter, status, lists or emphasis. State what must be done and only the technical detail that helps. At most 10 non-blank lines, each at most 140 characters — add line breaks instead of long lines.
3. **Slug.** Invent a latin kebab-case slug from the task, at most 100 characters.
4. **Add.** Run:

   ```bash
   .agents/skills/pflow-backlog/scripts/backlog-add.sh --slug "SLUG" <<'__PFLOW_BACKLOG_EOF__'
   <task text>
   __PFLOW_BACKLOG_EOF__
   ```

   → `{status,path,number,slug,lines,width}`. On a `slug` error, choose a new slug and rerun. Reply `✅ Backlog: <path>`.
5. **Close or promote.** When a backlog task is done or moved into a spec, delete it: run `.agents/skills/pflow-backlog/scripts/backlog-remove.sh --name "<NNN-slug>"` (or `--name "<slug>"`) → `{status,removed,number}`. No history is kept.

## Gotchas

- Status is implicit: a file in `docs/backlog` is new; deleting it means closed. Never add a status line or frontmatter to a task.
- The script creates `docs/backlog` when missing and takes the next number from the highest existing file, so numbers stay sequential only while that file is present.
- Backlog files are user documentation — follow `pflow-docs` when writing them.
- When a task flows into a spec, remove the backlog file in the same step; do not keep both.
