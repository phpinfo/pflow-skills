---
name: pflow-grill
description: Grills the user relentlessly about a plan, decision, or idea until both sides reach a shared understanding. Maps the subject as a design tree and interviews in rounds — each round asks every question whose prerequisites are already settled, with answer options and a recommended answer, then waits. Use when the user wants to stress-test their thinking, pressure-test a plan or a design, or uses a "grill" trigger phrase.
license: MIT
---

## Workflow

1. **Map.** Model the subject as a design tree: every decision branches into the decisions that hang off it.
2. **Frontier.** The frontier is every decision whose prerequisites are already settled — the questions you can ask _now_ without guessing at answers you have not heard yet. A question whose answer depends on another question still open belongs to a _later_ round, not this one.
3. **Ask.** Before asking a question with a recommended answer, estimate confidence in that answer. At 90% or higher, accept it and skip the question. Put the remaining frontier to the user in one round, numbered, with your recommended answers. Write every question so it clicks on first read — see Voice. Use the harness's native user-input tool when callable in the active mode; otherwise use the plain-text format below if permitted. If neither is allowed, explain the limitation and offer supported recovery, such as switching modes or continuing without Grill. Adapt to the native tool's schema; never infer callability from its name, invent a tool call, or violate the active mode. If the frontier exceeds its per-call limit, split the same round across calls before recomputing.
4. **Research.** Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, docs), dispatch a sub-agent to find it. Do not block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the report — ask the rest of the frontier now. The _decisions_ are the user's; put each to them and wait.
5. **Recompute.** Each round of answers reshapes the tree — settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round.
6. **Close.** The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on the result until the user confirms you have reached a shared understanding.

## Codex (ChatGPT)

- Before grilling, ask the user to switch the app to Plan mode; do not start until they do. Then begin grilling by calling `functions.request_user_input` directly, never through `functions.exec`. It accepts at most three questions per call, so split larger frontiers into batches of three.
- After grilling and before writing a plan, use the user-input tool to offer switching back or continuing the plan in Plan mode. Wait for their choice.

## Format

When using a native tool, put questions only in the tool call. Never preview or repeat them in commentary or plain text. For the plain-text fallback, render each question as:

```
❓ **Q1** - **<question title>**: <question body, may span multiple short paragraphs>

A. <answer option>
B. <answer option>

➡️ <your recommended answer>
```

- One answer option per line, each labeled with a capital Latin letter followed by a period and a space: `A. `, `B. `, `C. `…
- Never inline the options into the question body and never separate them with commas, slashes, or bullets — the lettered lines are the only place options appear.
- The recommendation names the letter it picks.
- A question with no genuine choice carries no options: question body, then the recommendation. Never invent options to fill the block.

## Voice

The reader is a smart friend who does not already live in this codebase. Goal: impossible to misunderstand on first read — not fewer words. Options and the recommendation use the same voice as the body.

- **Lead with the point.** The first sentence is the one thing that matters. Then supporting detail.
- **One idea per sentence.** No telegraphic colon-chains. If two things got mixed, split them into labeled parts, then recap in one line.
- **Facts stay verbatim.** Names, paths, commands, env vars, IDs are never paraphrased. Explain around them. When a term is jargon, say what it means in the same breath.
- **Title is a plain phrase**, not a compressed label. The body ends with the actual decision in one sentence. In the plain-text fallback, the lettered options follow it.
- **Same language as the user.** Direct, not consultant-speak, not memes.
- **Keep it simple.** Use ordinary words and short sentences. Avoid jargon and mixing languages when plain wording works. Never sound clever.

## Boundaries

- Ask the frontier, then stop. Except for the 90% rule, never answer for the user or assume an answer to keep moving.
- Never ask the user for a fact you could look up yourself.
- Do not implement, plan, edit files, or commit — this skill interrogates only.
