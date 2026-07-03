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
2. **Review.** Read `plan_file` and review it critically. If a step is ambiguous, contradictory, or has a blocking gap, stop and ask the user — never guess.
3. **Execute.** Implement each plan step in order, exactly as written. Write correct, readable, duplication-free code that matches the surrounding codebase.
4. **Verify.** Run whatever check the plan specifies for each step; if none, confirm by reading back the change. Stop and ask the user on any blocker (failed verification, missing dependency, unclear step) rather than working around it.
5. **Confirm.** When every plan step is done and covered, reply in the **Format** below.

## Gotchas

- Implement the plan as written. If reality diverges, stop and surface it — do not silently improvise.
- Do **not** commit, push, or close the task. Leave the active task open.
- Add nothing beyond the plan: no extra refactors, tests, or features.

## Format

Reply only in this format. No summary of what was done, no extra prose.

```text
**<current_task>**

---

✅ Task implemented
```
