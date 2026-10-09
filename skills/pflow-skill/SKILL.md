---
name: pflow-skill
description: >-
  Creates or edits pflow skills: scaffolds SKILL.md and scripts from existing patterns, then validates frontmatter
  and the 120-character line limit. Use whenever a task adds or renames a skill or edits any file under skills/<name>/
  (SKILL.md, references, scripts, evals).
license: MIT
allowed-tools:
  - Bash(.agents/skills/pflow-skill/scripts/skill-context.sh)
  - Bash(.agents/skills/pflow-skill/scripts/skill-finalize.sh:*)
---

If `skill-context.sh` or `skill-finalize.sh` fails (non-zero exit or `"status":"error"` in its JSON)
print `⚠️ <error.message>` and stop.

## Steps

1. **Context.** Run `.agents/skills/pflow-skill/scripts/skill-context.sh` →
   `{skills_dir, skills:[{name,description,scripts}]}`.
2. **Clarify.** New skill: you MUST know (a) what it does and (b) when it triggers — ask if ambiguous, never assume;
   propose a kebab-case NAME. Edit: confirm the change if intent is unclear.
3. **Build.** Write or edit `skills/<NAME>/` following the template below. New or renamed skill: update its row
   in the Skills table of `README.md`; rename: update `allowed-tools` paths and every mention of the old name.
4. **Validate.** Run `.agents/skills/pflow-skill/scripts/skill-finalize.sh --name "<NAME>"`
   → `{status:"ok",skill_dir,scripts_chmod,long_lines:["file:line:length"]}`.
   Rewrap every `long_lines` entry and rerun until it is empty.

## Template

Skills use a 3-phase structure (phases 1 and 3 are optional):

**Phase 1 — Preparation** (optional): read-only script gathers data → JSON. SKILL.md step: `1. Run <path> → {json}`.

**Phase 2 — Agent work**: agent makes creative/judgment decisions. SKILL.md step: `2. <description of the decision>`.

**Phase 3 — Finalization** (optional): action script takes agent output, mutates state → JSON.
SKILL.md step: `3. Run <path> --arg "VALUE" → {json}`.

### Frontmatter

```yaml
---
name: <kebab-case>
description: >-
  <third person: what + when, ≤1024 chars, wrapped at 120>
license: MIT
allowed-tools:
  - Bash(.agents/skills/<name>/scripts/<script>)
---
```

### SKILL.md body (in order)

1. Error handling, scoped to the skill's scripts:
   `If \`<script>\` fails (non-zero exit or \`"status":"error"\` in its JSON) print \`⚠️ <error.message>\` and stop.` If
   later steps run project commands, add: `Other failing commands are findings — report and continue.`
2. **Steps** — numbered, mixing script calls and agent decisions.
3. **Gotchas** (optional) — only facts affecting agent behavior.
4. **Format** (optional) — only when agent must produce structured output.

### Script conventions

```bash
#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$SKILL_DIR/../../.." && pwd)"
```

- One JSON line on stdout; errors as JSON fields (`error`/`status`), not stderr.
- Reuse helpers (`json_escape`, `emit_error`, `load_dotenv`) from sibling skills.

## Rules

- If it can be a script → it must be a script. Agent steps = judgment only.
- Every SKILL.md line must earn its tokens.
- Lines ≤120 characters in every skill file; tables, code blocks and lines with URLs are exempt.
- `allowed-tools` uses installed path `.agents/skills/<name>/scripts/...`.
- Ask about corner cases; never guess user intent.
