---
name: pflow-commit
description: Analyzes the working tree, writes a Conventional Commit message, then commits and pushes. Invoked manually only.
license: MIT
allowed-tools:
  - Bash(.agents/skills/pflow-commit/scripts/git-commit-context.sh)
  - Bash(.agents/skills/pflow-commit/scripts/git-commit-push.sh:*)
---

On any failure (non-zero exit from a Shell command OR an `error` field in JSON output) print `⚠️ <error message>` and stop immediately.

## Steps

1. Get the context: `.agents/skills/pflow-commit/scripts/git-commit-context.sh`. If the output is `No changes detected.`, tell the user there is nothing to commit and stop.
2. Compose MESSAGE (see format below).
3. Commit and push: `.agents/skills/pflow-commit/scripts/git-commit-push.sh --message "MESSAGE"`. The script prints JSON: `{commit_hash, branch_name, push_status}` on success, or `{…, error:{step, message}}` on failure. If `error` is present, print `⚠️ <error.message>` and stop.
4. Reply exactly, substituting values from the JSON:

   ```text
   ✅ Commit message:
   MESSAGE

   ✅ Committed and pushed:
   Hash: <commit_hash> | Branch: <branch_name> | Status: <push_status>
   ```

## Gotchas

- `git-commit-push.sh` runs `git add -A` — the commit includes ALL working-tree changes, not just the ones your message describes. Account for this when composing the text.
- The context from step 1 is truncated: at most 50 lines per file and 600 lines total. Large diffs are shown only partially — don't draw conclusions about the cut-off part.
- `push_status`: `pushed` (upstream already existed) or `pushed_with_upstream` (created via `git push -u origin <branch>`).
- The push script does not write git errors to stderr — they go into the JSON `error` field. Always check it (step 3), otherwise a failed commit/push goes unnoticed.

## Message format (Conventional Commits)

See `.agents/skills/pflow-commit/reference/commit-format.md` for the full format (types, scope, breaking-change rules, examples). In short: `<type>[(scope)][!]: <description>`, imperative mood.

The commit message MUST always be written in English — regardless of the conversation language.
