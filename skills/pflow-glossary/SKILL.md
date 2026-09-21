---
name: pflow-glossary
description: Creates or extends GLOSSARY.md — one table of canonical terms, code identifiers, one-sentence definitions and banned synonyms. Use when a glossary is created, updated or audited, when a new domain term or a naming synonym appears, or when the user asks to define project terms.
license: MIT
allowed-tools:
  - Bash(.agents/skills/pflow-glossary/scripts/glossary-context.sh:*)
  - Bash(.agents/skills/pflow-glossary/scripts/glossary-finalize.sh:*)
---

If `glossary-context.sh` or `glossary-finalize.sh` fails (non-zero exit or `"status":"error"` in its JSON) print `⚠️ <error.message>` and stop — except a `lint` error from finalize: fix the named line and retry (max 3 retries).

## Steps

1. **Audit.** Run `.agents/skills/pflow-glossary/scripts/glossary-context.sh` → `{glossary:{path,format,rows,default_path}, files_scanned, identifiers:[{name,count}]}`.
2. **Collect candidates.** Read the existing glossary (if `path` is set) and skim README and docs for domain nouns; their language is the glossary language. In `identifiers` look for several names of one concept (`Customer`/`Client`/`Account`, `Order`/`Purchase`). Include only project-specific concepts; skip words a dictionary or the language already defines. Do not read the whole codebase.
3. **Ask once.** With one AskUserQuestion round (skip what the conversation already answers), settle: for every synonym cluster, which name is canonical; which candidates are out of scope; and, when the user asked for specific terms, anything ambiguous in them.
4. **Draft** the file per **Format**. New terms are added to the existing tables; existing rows are kept unless the user asked to change them.
5. **Write.** One non-interactive Bash call feeding the Markdown through a quoted heredoc:

   ```bash
   .agents/skills/pflow-glossary/scripts/glossary-finalize.sh --overwrite <<'__PFLOW_GLOSSARY_EOF__'
   <full glossary Markdown>
   __PFLOW_GLOSSARY_EOF__
   ```

   → `{status, path, tables, rows, agents_md, claude_md, warnings:[{code,line,text}]}`. Pass `--overwrite` only when step 2 read the existing file; `--path <file>` only when the user named a location; `--agents none` when the user does not want the AGENTS.md/CLAUDE.md rule. Fix every warning (`circular`, `long`, `form`) by rewriting the definition and rerun.
6. **Report.** Terms added or changed, the AGENTS.md/CLAUDE.md result, and any candidates you left out with the reason. Do not echo the file.

## Format

The file is `GLOSSARY.md` at the project root (an existing `glossary*.md` is reused) and contains nothing but an H1, optional H2 group headings, and tables. No intro, no notes.

```markdown
# Glossary

| Term | Code | Definition | Avoid |
| --- | --- | --- | --- |
| Invoice | `Invoice` | Request for payment sent to a customer after delivery. | bill, payment request |
| Stock keeping unit | `SKU` | Unique code of one sellable product variant. | — |
```

- **Term** — canonical name in the docs language, singular, plain text, as written in prose.
- **Code** — the identifier used in code, always English, backticked (`Invoice`, `SKU`); `—` when the term never appears in code.
- **Definition** — one sentence in the docs language: what kind of thing it is plus what distinguishes it. Must be substitutable for the term in a sentence; never starts with the term, never "is when" / "это когда".
- **Avoid** — synonyms banned in code and docs, comma-separated, any language; `—` when none.
- Rows are sorted by the script; group into H2 sections only above ~40 terms, one table per section.

## Gotchas

- An existing glossary in another layout (cards, lists) is converted to the table; keep every term and say so in the report.
- A word in `Avoid` cannot also be a `Term` — the script rejects it; pick one canonical name.
- `identifiers` counts are hints for synonym hunting, not a term list; most identifiers are not domain terms.
