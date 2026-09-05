# Writing AGENTS.md

AGENTS.md is loaded into every session of every agent (Codex, Cursor, Copilot, Claude via CLAUDE.md). Every line costs tokens on every task and every line is *obeyed*. Research on real repositories (ETH Zurich 2026, 2607.27250, 2601.20404) found that generated context files which restate the README and the codebase **lower** task success by ~3% and raise cost by 20%+, while short hand-written files with only non-derivable facts raise success by ~4%. The file is a list of corrections, not documentation.

## Budget

| Measure | Target | Hard limit |
| --- | --- | --- |
| Lines | ≤ 60 | 100 (`agents-finalize.sh` refuses more) |
| Instructions | ≤ 30 | ~150 total incl. the agent's own system prompt |
| Bytes | a few KB | 32 KiB (Codex stops reading) |
| Emphasis (`IMPORTANT`, `NEVER`) | 0–2 lines | more → none stands out |

An empty file beats a padded one. Five true lines beat sixty plausible ones.

## Three tests every line must pass

1. **Removal test** — "If this line vanished, would an agent make a mistake on a typical task?" No → delete.
2. **Derivability test** — "Can an agent learn this in under a minute from the code, manifests, or lockfile?" Yes → delete. Stack, framework, directory layout, dependency list, language conventions are all derivable.
3. **Duplication test** — "Is this already in README, CONTRIBUTING, docs/, or enforced by a linter, formatter, hook, or CI?" Yes → delete, or replace with a one-line pointer to the file.

## Include (only when true for *this* project and not derivable)

- **Commands an agent cannot guess**: the exact test, lint, typecheck, build command when several are plausible (`pnpm` vs `npm`, `task check` vs `make check`, `uv run pytest -x`). Prefer file-scoped variants (`pytest path/to/test.py`) over repo-wide ones. Note expensive operations ("full suite takes 20 min — run the package tests").
- **Verification**: what "done" means here — which gate must pass before committing or opening a PR.
- **Conventions no tool enforces**: commit format, branch naming, PR expectations, changelog rules, where new modules go, how migrations are created, naming rules that differ from language defaults.
- **Gotchas**: non-obvious behaviours that caused real mistakes — generated files, ordering constraints, env vars required for tests, a mock that must be regenerated, a directory that must never be edited by hand.
- **Boundaries**: frozen or generated directories, vendored code, files that need human approval, secrets locations, deploy actions that are off-limits.
- **Architecture decisions that are not visible in code**: why two ways exist and which one is current, what is deprecated, the one entry point to read first.
- **Pointers**: `See docs/architecture.md for the request lifecycle` — the pointer, not the content. Prefer `path:line` over pasted snippets; snippets go stale.

## Exclude

- Project description, purpose, feature list, tech stack, framework versions → README and manifests.
- Directory tree or file-by-file map → the agent lists directories itself.
- Code style that a formatter or linter owns → run the tool; never make the model do a linter's job.
- Generic engineering advice ("write clean code", "handle errors", "add tests", SOLID/DRY/KISS) → the model knows it; such lines increase reasoning tokens 14–22% with no gain.
- Personas ("You are a senior engineer…"), praise, tone instructions.
- Task-specific, one-off, or in-progress notes (hotfix steps, current sprint, ticket details).
- Anything that changes often (version numbers, team roster, roadmap).
- Personal preferences → `CLAUDE.local.md`, user-level rules, or the user's own config.
- Multi-step procedures that only matter sometimes → a skill or a path-scoped rule, referenced by one line.
- Copies of other agent files (`.cursorrules`, `copilot-instructions.md`): merge them into AGENTS.md once, then delete or point them at it.

## Shape

Flat Markdown, headings and bullets, no prose paragraphs. Suggested order (skip empty sections; never add a section to look complete):

```markdown
# AGENTS.md

## Commands            # only the non-guessable ones, copy-pasteable
## Verify before done  # the gate; file-scoped tests first
## Conventions         # what no tool enforces
## Gotchas             # non-obvious behaviours, expensive operations
## Boundaries          # do not touch / ask first
## Read first          # 1–5 pointers to docs or entry points
```

Wording: imperative, concrete, verifiable. "Run `task check` before every commit" not "make sure the code is tested". One instruction per bullet. Name exact paths and commands. No hedging, no rationale longer than a clause — if a rule needs a paragraph of why, link to the ADR instead.

## Monorepos and large repos

Keep the root file to global commands, conventions and pointers. Put package-specific rules in a nested `AGENTS.md` next to the package; every agent reads the nearest file first and merges it with the parents. Claude Code loads nested `CLAUDE.md` when it reads files in that directory, so mirror nested files too if Claude is used there.

## CLAUDE.md

Claude Code reads `CLAUDE.md`, not `AGENTS.md`. Options: an identical copy (works everywhere, no symlink issues on Windows, must be re-synced — this skill does that), a one-line `@AGENTS.md` import (single source of truth, Claude Code only), or a symlink (fails on Windows without Developer Mode). Claude-only additions go below the import line, never into AGENTS.md.

## Maintenance

Add a line when the agent makes the same mistake twice, when a review catches something it should have known, or when you type the same correction into chat again. Delete a line when the agent does the right thing without it. Re-run this skill after a stack or workflow change; it re-audits and re-applies the three tests.

## Sources

- Anthropic, "How Claude remembers your project" and "Best practices" — https://code.claude.com/docs/en/memory, https://code.claude.com/docs/en/best-practices
- agents.md spec — https://agents.md/ ; Codex AGENTS.md guide (32 KiB limit, nesting) — https://learn.chatgpt.com/docs/agent-configuration/agents-md
- Gloaguen et al., "Evaluating AGENTS.md" (ETH Zurich) — https://arxiv.org/abs/2602.11988 ; "Do Context Files Help Coding Agents?" — https://arxiv.org/abs/2607.27250 ; "On the Impact of AGENTS.md Files on Efficiency" — https://arxiv.org/abs/2601.20404 ; "Agent READMEs" (2,303 files studied) — https://arxiv.org/abs/2511.12884
- HumanLayer, "Writing a good CLAUDE.md" — https://www.humanlayer.dev/blog/writing-a-good-claude-md
- Upsun, "Your AGENTS.md is probably too long" — https://developer.upsun.com/posts/ai/agents-md-less-is-more
- Vercel, "AGENTS.md outperforms skills in our agent evals" — https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals
