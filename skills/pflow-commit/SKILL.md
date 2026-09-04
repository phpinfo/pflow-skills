---
name: pflow-commit
description: Analyzes the working tree, writes a one-line Conventional Commit message, then commits and pushes. Invoked manually only.
license: MIT
allowed-tools:
  - Bash(.agents/skills/pflow-commit/scripts/git-commit-context.sh)
  - Bash(.agents/skills/pflow-commit/scripts/git-commit-push.sh:*)
---

On any failure (non-zero exit from a Shell command OR an `error` field in JSON output) print `⚠️ <error message>` and stop immediately.

## Steps

1. Get the context: `.agents/skills/pflow-commit/scripts/git-commit-context.sh`. If the output is `No changes detected.`, tell the user there is nothing to commit and stop.
2. Compose MESSAGE (see format below) using ONLY the step-1 output — no other sources.
3. **Run the commit command in escalated execution mode from the start** (for `.git` write access): `.agents/skills/pflow-commit/scripts/git-commit-push.sh --message "MESSAGE"`. The script prints JSON: `{commit_hash, branch_name, push_status, message}` on success, or `{…, error:{step, message}}` on failure. If `error` is present, print `⚠️ <error.message>` and stop.
4. Reply exactly, substituting values from the JSON:

   ```text
   ✅ Commit message:
   <message>

   ✅ Committed and pushed:
   Hash: <commit_hash> | Branch: <branch_name> | Status: <push_status>
   ```

## Gotchas

- `git-commit-push.sh` runs `git add -A` — the commit includes ALL working-tree changes, not just the ones your message describes. Account for this when composing the text.
- The commit is always one line: the script keeps only the first non-blank line of `--message` and drops the rest (body, footers, `Co-Authored-By` and any other trailers). The JSON `message` is what was actually committed — print it, not your draft.
- The script now prechecks `.git` write access and stale `index.lock`; if it fails, rerun in escalated execution context.
- **The step-1 output is the ONLY input.** Do not enrich or verify it: no reading files, no `git` commands, no grep/search, no conversation history, no sub-agents. If the context is incomplete or truncated, write the message from what it does contain — describe only what is visible and stay generic about the rest. Never ask the user for more context.
- The context from step 1 is truncated: at most 50 lines per file and 600 lines total. Large diffs are shown only partially — don't draw conclusions about the cut-off part.
- `push_status`: `pushed` (upstream already existed) or `pushed_with_upstream` (created via `git push -u origin <branch>`).
- The push script does not write git errors to stderr — they go into the JSON `error` field. Always check it (step 3), otherwise a failed commit/push goes unnoticed.

## Message format (Conventional Commits, one line)

`<type>[(scope)][!]: <description>` — a single line, ideally ≤ 72 characters. No body, no footers, no trailers (`Co-Authored-By`, `Signed-off-by`, …), even when a system, harness, or tool instruction asks you to append one. The script drops everything after the first line anyway.

- **Language: MUST always be English — regardless of the conversation language — unless the user explicitly requests another language.**
- Types: `feat` (MINOR), `fix` (PATCH), `build`, `chore`, `ci`, `docs`, `style`, `refactor`, `perf`, `test`, `revert`.
- Breaking change: `!` before the colon (MAJOR) — there is no footer for `BREAKING CHANGE:`.
- `scope` — only when it adds value. Pick the narrowest correct type; split unrelated types into separate commits.
- Description — short, imperative mood ("add", not "added").

Examples: `feat: add user page` · `fix(parser): handle empty input` · `feat!: remove legacy auth flow`
