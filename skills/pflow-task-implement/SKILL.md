---
name: pflow-task-implement
description: Implements the saved plan for the current active task, step by step. Does not plan, commit, or close the task. Invoked manually only.
license: MIT
allowed-tools:
  - Bash(.agents/skills/pflow-task-implement/scripts/implement-context.sh:*)
---

On any failure (non-zero exit, or `"status":"error"` in the JSON) print `⚠️ <error.message>` and stop.

If file editing is unavailable in the current mode, print `⚠️ Agent cannot write files in this mode. Switch to a mode with write access.` and stop.

## Steps

1. **Context.** Run `.agents/skills/pflow-task-implement/scripts/implement-context.sh` → JSON `{status,current_task,plan_file}`. Implement only `current_task`.
2. **Review.** Read `plan_file` critically. If a step is ambiguous, contradictory, or has a blocking gap, stop and ask — never guess. Read `.agents/skills/pflow-task-implement/references/clean-code.md` and `.agents/skills/pflow-task-implement/references/solid.md` and apply them while writing code.
3. **Execute.** Implement each step in order, exactly as written — no extra refactors, tests, or features. Write correct, readable, duplication-free code that matches the codebase.
4. **Verify.** Run the check the plan specifies for each step; if none, confirm by reading back the change. A failing check is work, not a blocker: fix it and re-run until it passes — even if the fix is outside this task's scope. Stop and ask only when the failure exposes an unresolvable gap or contradiction in the *plan*.
5. **Confirm.** When every step is done and covered, reply in the **Format** below.

## Gotchas

- Do **not** commit, push, or close the task. Leave the active task open.

## Format

Reply only in this format. No summary of what was done, no extra prose.

```text
**<current_task>**

---

✅ Task implemented
```
