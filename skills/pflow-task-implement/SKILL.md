---
name: pflow-task-implement
description: Implements the saved plan for the current active task in the mdtodo task list. The agent reads the plan from PFLOW_TASKS_PLAN_FILE, critically reviews it, decomposes it into todo items, then executes each step in order with verification. Implements only — it does not plan, commit, or close the task. Invoked manually only.
license: MIT
allowed-tools:
  - Bash(.agents/skills/pflow-task-implement/scripts/implement-context.sh:*)
---

On any failure (non-zero exit, or `"status":"error"` in the JSON) print `⚠️ <error.message>` and stop.

If file editing is unavailable in the current mode, print `⚠️ Agent cannot write files in this mode. Switch to a mode with write access.` and stop.

## Steps

1. **Context.** Run `.agents/skills/pflow-task-implement/scripts/implement-context.sh` → JSON `{status,current_task,plan_file}`. Implement only `current_task`.
2. **Review.** Read `plan_file` and review it critically before doing anything. If a step is ambiguous, contradictory, or has a gap that blocks execution, stop and ask the user — never guess or fill in missing decisions.
3. **Decompose.** Turn the plan into todo items with your todo tool — one item per plan step, in plan order. Create exactly the steps the plan lists; do not invent, merge, or skip steps.
4. **Execute.** Work the todos one at a time: mark in_progress, implement the step following the plan exactly, then mark completed. Write code that is correct, readable, and free of duplication, matching the surrounding codebase.
5. **Verify.** Run whatever verification the plan specifies for each step. If a step has no stated check, confirm by reading back the change. Stop and ask the user on any blocker (failed verification, missing dependency, unclear instruction) rather than working around it.
6. **Confirm.** When all todos are done, walk every plan item to confirm it is covered, then reply in the **Format** below.

## Gotchas

- Implement the plan as written. If reality diverges from the plan, stop and surface it — do not silently improvise a different approach.
- Do **not** commit, push, or close the task — those are separate skills (`pflow-commit`, `pflow-task-finish`). Leave the active task open.
- Do not add work beyond the plan: no extra refactors, tests, or features the plan does not call for.

## Format

Reply only in this format. No summary of what was done, no extra prose.

```text
**<current_task>**

---

✅ Task implemented
```
