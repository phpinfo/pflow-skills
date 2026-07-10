---
name: pflow-refactor
description: Performs evidence-based refactoring research for a user-specified code, component, or subsystem. Produces an As Is analysis and a minimal, justified To Be proposal with naming, dependency, migration, and trade-off recommendations. Applies SOLID, KISS, YAGNI, BDUF, APO, Occam's Razor, DRY, Law of Demeter, and composition over inheritance. Analysis only; does not implement changes. Invoked manually only.
license: MIT
---

## Workflow

1. **Scope.** Infer the target and desired depth from the conversation. Ask only about a decision that cannot be resolved from available context.
2. **Inspect.** Read applicable project rules, architecture docs, implementation, tests, consumers, and relevant history. Consult current framework or language guidance when it materially affects the design. Ignore unrelated code.
3. **Principles.** Read `.agents/skills/pflow-refactor/references/clean-code.md` and `.agents/skills/pflow-refactor/references/solid.md`. Use their smells to spot problems and their fixes to justify the To Be — cite the specific principle, not a generic appeal to cleanliness.
4. **Analyze As Is.** Establish evidence: responsibilities, ownership, dependencies, mutation and event boundaries, invariants, public API, tests, duplication, naming, change frequency, and concrete size or coupling indicators. Distinguish facts from inferences.
5. **Design To Be.** Propose the smallest architecture that addresses observed problems. Prefer composition and existing extension points. Preserve behavior, reduce coupling, define ownership and atomic change boundaries, and explain naming.
6. **Challenge.** Reject speculative abstractions and premature optimization. Add managers, repositories, interfaces, base classes, event buses, or generic mechanisms only when current evidence requires them.
7. **Report.** Lead with the conclusion, then present `As Is`, `To Be`, rationale and trade-offs, a safe migration sequence, risks, and explicit non-goals. Use exact paths and symbols where available. Mark unresolved decisions instead of inventing requirements.

## Boundaries

- Do not edit files, implement, commit, or turn the research into a task plan unless explicitly requested separately.
- Do not recommend a rewrite when incremental migration can preserve behavior.
- Do not extract abstractions solely to reduce line count or superficial duplication.
- Do not optimize without measurements.
