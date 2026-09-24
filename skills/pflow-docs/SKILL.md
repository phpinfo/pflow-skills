---
name: pflow-docs
description: Writing rules for user docs — README, docs/, root-level Markdown for people (CONTRIBUTING, CHANGELOG…) or whatever AGENTS.md/CLAUDE.md declares. Plain style, no AI-writing tells. Use when writing, editing or reviewing them; not for agent instructions or code comments.
license: MIT
---

User docs are `README*` at any level, everything under `docs/`, and root-level Markdown for people (`CONTRIBUTING.md`, `CHANGELOG.md`, `SECURITY.md`…). The project's `AGENTS.md`/`CLAUDE.md` or the user may redefine this; their definition wins. Vendor, clipped or generated text is read-only.

## Steps

1. Read `AGENTS.md`/`CLAUDE.md` for doc conventions, and the glossary if any (`GLOSSARY.md`, `Глоссарий.md` or similar; often absent). Project conventions win; say so on conflict.
2. Take the language from the document or the project's other docs. For Russian, also read `.agents/skills/pflow-docs/references/ru.md`.
3. Check every command, flag, path and name against the code, manifests or the user. Never fill a gap with a guess: ask or leave it out.
4. Apply the rules below only to text you write or change. Report other violations; rewrite them only when asked.
5. Before finishing, confirm no fact was lost or added, and search for the tells that survive rewrites: "not X but Y", a restating closer, a run-up, a reflex triad, bold labels. Run documented commands that are safe to run; a failure is a finding, not a stop.

## Content

- Write for someone who has not seen the code or this conversation, as you would explain it to a colleague out loud.
- Every sentence adds a new fact. Cut run-ups ("It's worth noting", "Let's dive in"), closers that restate, "not X but Y" when nobody claimed X, and replies to objections nobody raised.
- Do not inflate ("key", "crucial", "robust", "seamless", "plays a role", "ensures"): say what breaks without it or what the reader gets. No sales tone, no outlook paragraphs.
- Be concrete: a number, a name, a command. Name the relation instead of "related to".
- Describe what is true now; history belongs in `CHANGELOG.md` or a migration guide.
- One concept, one name: glossary terms verbatim, no synonyms for variety. Identifiers, commands, paths and fields in backticks, as in the code.
- No chat residue or placeholders ("I hope this helps", "Let me know", `[insert …]`).

## Style

- Plain verbs ("is", "has", "runs"), not "serves as", "boasts", "utilizes", "leverages", "allows you to".
- Active voice with a visible actor.
- No stock AI words (delve, additionally, underscore, showcase, foster, landscape, testament, pivotal, vibrant, intricate) and no "-ing" riders that fake depth ("…, ensuring reliability").
- One hedge at most, only for real doubt.

## Form

- Lists only for real enumerations; three items only when there are three. A "**Label:** text" list becomes prose unless the labels carry information.
- Bold only for warnings. No decorative emoji or arrows, no `---` between sections.
- Sentence-case headings, one H1, no skipped levels, no heading that only holds subheadings or that the next sentence repeats, no restating "Summary".
- A dash is fine; a sentence held together by several is not.
- A table needs several items and attributes; two rows that read as a sentence stay a sentence.
- Code blocks have a language tag and paste as is: no `$` prompt, output in a separate block.

## README

Only the sections that apply, in this order:

1. `# <project name>` and one sentence: what it is, for whom. No tagline or emoji.
2. Status badges (CI, version, license) on one line.
3. Quickstart: at most five steps, one copy-paste block, the expected result.
4. Usage: two to four real scenarios, simplest first.
5. Configuration: a table of option, default, meaning.
6. Links to `docs/`; with several docs, an index table `File | What's inside`.
7. Contributing, license.

Each `docs/` file covers one topic; its first paragraph says what the reader can do after reading it.
