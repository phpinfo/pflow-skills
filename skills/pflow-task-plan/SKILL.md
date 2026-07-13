---
name: pflow-task-plan
description: Builds a concrete implementation plan for the current active task in the mdtodo task list. The agent clarifies open questions, analyzes the codebase and project docs, decomposes the work into small steps, and saves the plan to a file. This skill plans only — it does not implement the task. Invoked manually only.
license: MIT
allowed-tools:
  - Bash(.agents/skills/pflow-task-plan/scripts/plan-context.sh:*)
  - Bash(.agents/skills/pflow-task-plan/scripts/plan-save.sh:*)
---

On failure (non-zero exit, or `"status":"error"` in the JSON): if the message is `empty plan content on stdin`, retry the save **exactly once** with a proper quoted-heredoc call. On a repeated error — or any other error — print `⚠️ <error.message>` and stop. Never retry endlessly.

If file editing is unavailable in the current mode, print `⚠️ Agent cannot write files in this mode. Switch to a mode with write access.` and stop.

## Steps

1. **Context.** Run `.agents/skills/pflow-task-plan/scripts/plan-context.sh` → JSON `{status,current_task,previous_tasks,next_tasks}`. Plan only `current_task`. Use `previous_tasks` (up to 2 just completed) and `next_tasks` (up to 2 upcoming) only to understand what came before and what follows — never plan or pull in those tasks.
2. **Clarify.** Resolve anything ambiguous before planning. Answer from the codebase and project docs when you can; only ask the user about genuine decision points. Ask **one question at a time**, walk each decision branch to its end, and offer a recommended answer for every question (via AskUserQuestion). If the user passed extra detail when invoking the skill, treat it as task input.
3. **Plan.** Decompose the task into steps small enough for another agent to execute correctly. Write the plan as Markdown with the sections in **Format** below.
4. **Save.** Save the plan with **one** non-interactive Bash call, feeding the full Markdown to `plan-save.sh` through a quoted heredoc → JSON `{status,plan_filename,bytes}`:

   ```bash
   .agents/skills/pflow-task-plan/scripts/plan-save.sh <<'__PFLOW_PLAN_EOF__'
   <full plan Markdown>
   __PFLOW_PLAN_EOF__
   ```

   - Never run `plan-save.sh` without redirected stdin.
   - Never use a PTY, an interactive session, or `write_stdin` to feed the plan.
   - The heredoc terminator must be a unique marker that does not appear anywhere inside the plan.
   - The terminator **must** be quoted (`<<'__PFLOW_PLAN_EOF__'`) so backticks, `$`, `$()`, and any other shell constructs inside the Markdown stay literal text and are not expanded.

   On success reply exactly:

   ```text
   ✅ Plan saved to <plan_filename>
   ```

   Do not echo the plan or a summary back to the user — only the line above.

## Gotchas

- Write for an engineer with zero context for this codebase: exact file paths, real names, concrete steps. No placeholder language (`TBD`, `add error handling`, `similar to the step above`).
- Do **not** add steps for: build checks, testing, cache resets, planning, or diagrams.
- If the current milestone folder has a design doc, factor it into the plan.
- Before saving, self-review: every requirement is covered, no placeholders remain, file paths and names are consistent across steps.

## Format

Markdown using headings and lists (not a checklist). Include at least these sections:

- **Goal** — one sentence.
- **Scope** — what is in and explicitly out.
- **Context** — relevant findings from code and docs.
- **Affected files** — exact paths, each with its responsibility.
- **Analysis** — reasoning and chosen approach.
- **Implementation** — ordered, small steps.
- **Definition of Done** — the expected result.
