---
name: pflow-grill
description: Grills the user relentlessly about a plan, decision, or idea until both sides reach a shared understanding. Maps the subject as a design tree and interviews in rounds — each round asks every question whose prerequisites are already settled, with lettered answer options and a recommended answer, then waits. Use when the user wants to stress-test their thinking, pressure-test a plan or a design, or uses a "grill" trigger phrase.
license: MIT
---

## Workflow

1. **Map.** Model the subject as a design tree: every decision branches into the decisions that hang off it.
2. **Frontier.** The frontier is every decision whose prerequisites are already settled — the questions you can ask _now_ without guessing at answers you have not heard yet. A question whose answer depends on another question still open belongs to a _later_ round, not this one.
3. **Ask.** Put the whole frontier to the user in one round, numbered, each in the format below with your recommended answer. Then wait for the user's answers.
4. **Research.** Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, docs), dispatch a sub-agent to find it. Do not block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the report — ask the rest of the frontier now. The _decisions_ are the user's; put each to them and wait.
5. **Recompute.** Each round of answers reshapes the tree — settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round.
6. **Close.** The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on the result until the user confirms you have reached a shared understanding.

## Format

Each question:

```
❓ **Q1** - **<question title>**: <question body, may span multiple paragraphs>

A. <answer option>
B. <answer option>

➡️ <your recommended answer>
```

- One answer option per line, each labeled with a capital Latin letter followed by a period and a space: `A. `, `B. `, `C. `…
- Never inline the options into the question body and never separate them with commas, slashes, or bullets — the lettered lines are the only place options appear.
- The recommendation names the letter it picks.
- A question with no genuine choice carries no options: question body, then the recommendation. Never invent options to fill the block.

## Boundaries

- Ask the frontier, then stop. Never answer for the user or assume an answer to keep moving.
- Never ask the user for a fact you could look up yourself.
- Do not implement, plan, edit files, or commit — this skill interrogates only.
