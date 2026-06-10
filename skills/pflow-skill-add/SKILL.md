---
name: pflow-skill-add
description: Creates a new pflow skill. Analyzes existing skills for patterns, scaffolds SKILL.md and optional scripts. Invoked manually only.
license: MIT
allowed-tools:
  - Bash(.agents/skills/pflow-skill-add/scripts/skill-add-context.sh)
  - Bash(.agents/skills/pflow-skill-add/scripts/skill-add-finalize.sh:*)
---

On any failure (non-zero exit or `error` field in JSON) print `⚠️ <message>` and stop.

## Steps

1. **Context.** Run `.agents/skills/pflow-skill-add/scripts/skill-add-context.sh` → JSON `{skills_dir, skills:[{name,description,scripts}]}`.
2. **Clarify.** You MUST know (a) what the skill does and (b) when it triggers. If ambiguous, ask — never assume. Propose a kebab-case NAME.
3. **Build.** Write `skills/<NAME>/SKILL.md` and optional `skills/<NAME>/scripts/` following the template below. Add a row for the new skill to the Skills table in `README.md`.
4. **Validate.** Run `.agents/skills/pflow-skill-add/scripts/skill-add-finalize.sh --name "<NAME>"` → `{status:"ok",skill_dir,scripts_chmod}`.

## Template

New skills use a 3-phase structure (phases 1 and 3 are optional):

**Phase 1 — Preparation** (optional): read-only script gathers data → JSON. SKILL.md step: `1. Run <path> → {json}`.

**Phase 2 — Agent work**: agent makes creative/judgment decisions. SKILL.md step: `2. <description of the decision>`.

**Phase 3 — Finalization** (optional): action script takes agent output, mutates state → JSON. SKILL.md step: `3. Run <path> --arg "VALUE" → {json}`.

### Frontmatter

```yaml
---
name: <kebab-case>
description: <third person: what + when, ≤1024 chars>
license: MIT
allowed-tools:
  - Bash(.agents/skills/<name>/scripts/<script>)
---
```

### SKILL.md body (in order)

1. Error handling: `On any failure (non-zero exit, or an \`error\` field / \`"status":"error"\` in the JSON) print \`⚠️ <message>\` and stop.`
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
- `allowed-tools` uses installed path `.agents/skills/<name>/scripts/...`.
- Ask about corner cases; never guess user intent.
