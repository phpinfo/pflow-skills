---
name: pflow-agents
description: Creates or rewrites a minimal AGENTS.md for the current project and syncs it to CLAUDE.md. Audits the repo, asks the user only for facts that cannot be derived from code or docs, drafts a file of non-guessable commands, conventions, gotchas and boundaries (no project overview, no README duplication, no generic advice), then lint-checks it for size, filler and verbatim duplication before writing. Use when asked to create, update, trim or audit AGENTS.md or CLAUDE.md. Invoked manually only.
license: MIT
allowed-tools:
  - Bash(.agents/skills/pflow-agents/scripts/agents-context.sh)
  - Bash(.agents/skills/pflow-agents/scripts/agents-finalize.sh:*)
---

If `agents-context.sh` or `agents-finalize.sh` fails (non-zero exit or `"status":"error"` in its JSON) print `⚠️ <error.message>` and stop — except a `lint` error from finalize: cut lines and retry (max 2 retries). Other failing commands are findings — report and continue.

## Steps

1. **Audit.** Run `.agents/skills/pflow-agents/scripts/agents-context.sh` → `{agents_md, claude_md, other_rule_files[], nested_agent_files[], docs[], manifests[], package_manager, task_runner, runner_targets[], npm_scripts[], composer_scripts[], tooling[], ci[], monorepo[], top_dirs[], installed_skills[], gitignored[]}`.
2. **Learn the rules.** Read `.agents/skills/pflow-agents/references/agents-md-guide.md`. Apply its three tests (removal, derivability, duplication) to every line you write.
3. **Read inputs, not to copy them.** Read existing `AGENTS.md`, `CLAUDE.md`, `other_rule_files` (candidate rules to keep or drop), then `docs` (README, CONTRIBUTING…) to learn what is *already documented* and must not be repeated, and the task runner / CI config to get the real command names. Do not read the whole codebase; skim entry points only when a gotcha needs confirming.
4. **Ask once.** With one AskUserQuestion round (skip questions the conversation already answers; every question gets a "nothing / skip" option), collect the facts only the user knows:
   - mistakes agents or new contributors keep making here;
   - directories or files agents must not edit, or must ask before touching;
   - the gate that must pass before a commit or PR, if `ci`/`runner_targets` leave it ambiguous;
   - conventions no tool enforces (commits, branches, PR rules, where new code goes) that README does not already state;
   - for `monorepo` projects: whether per-package `AGENTS.md` files are wanted (this skill writes the root file only).
5. **Draft.** Write the file in the guide's shape, ≤ 60 lines. Every bullet: imperative, concrete, one instruction, exact command or path. When an existing file had lines that fail the tests, drop them and list what you dropped and why. Point to `installed_skills` instead of restating their procedures. If `package_manager`, `task_runner` or the test command is unambiguous from the manifests alone, mention it only if several choices are plausible.
6. **Write.** One non-interactive Bash call feeding the Markdown through a quoted heredoc:

   ```bash
   .agents/skills/pflow-agents/scripts/agents-finalize.sh --overwrite <<'__PFLOW_AGENTS_EOF__'
   <full AGENTS.md Markdown>
   __PFLOW_AGENTS_EOF__
   ```

   → `{status, agents_md:{lines,bytes}, claude_md:{mode,result}, warnings:[{code,line,text}]}`. Pass `--overwrite` only when step 3 read the existing files. Default `--claude copy` copies AGENTS.md to CLAUDE.md; use `--claude import` when the user prefers a one-line `@AGENTS.md` import, `--claude none` to leave CLAUDE.md alone. Fix every `generic`, `duplicate`, `overview`, `placeholder` warning by deleting or rewriting the line and rerun; `long` and `emphasis` warnings are findings to report if you keep the lines deliberately.
7. **Report.** Print the final line count, the CLAUDE.md result, lines dropped from previous files, and remaining warnings. Do not echo the file.

## Gotchas

- `claude_md.kind` `symlink` or `import` means CLAUDE.md already delegates to AGENTS.md — keep that mode (`--claude none` for symlink, `--claude import` for import) unless the user asks for a copy.
- `gitignored` lists AGENTS.md/CLAUDE.md entries ignored by git; tell the user, since a shared file should be committed.
- Never write a project overview, tech-stack list, or directory tree — the agent derives them, and studies show they hurt.
- `other_rule_files` stay untouched; suggest replacing their content with a pointer to AGENTS.md when they duplicate it.
