# Clean code: read like prose, not a puzzle

Code is clean when another developer quickly sees **what** it does, **why**, and **where** it's safe to change.

## Fit the codebase

- **Familiar beats clever.** Follow the project's style and conventions; a novel approach costs more than a known one.
- **Fix the cause, not the symptom.** Trace the error to its source instead of patching over it.
- **Leave it cleaner.** Improve what you touch, but don't turn the task into a rewrite.

## Names are free documentation

- Name the role, not the type: `retryLimit` not `x`, `expiresAt` not `date`, `isActive` not `flag`.
- Make names unambiguous, pronounceable, searchable. Name magic values. No type prefixes / Hungarian notation.

## Functions: one verb, one level of thought

Short, single-purpose, named for its result or action, few arguments, no surprising side effects.
A boolean flag often hides two functions: `save(draft: true)` → `saveDraft()` / `publish()`.

## Structure reads top-down

- Lead with the main thing, details below.
- Keep related things close: use near declaration, caller near callee, related operations together.
- Group meaning with blank lines; don't decorate.
- Deep nesting is a signal — extract a condition, return early, or split responsibility.

## Comments aren't a second copy of the code

Prefer names and structure first. Comment only to record: intent, a non-obvious constraint, the reason for a strange decision, or a dangerous consequence.
Don't comment the obvious. Don't keep commented-out code — Git has it.

## Hide details, expose meaning

- Objects protect their rules; they don't just leak internals.
- Don't scatter primitives when a value has meaning and constraints: `string email` → `Email`, `int amount` → `Money`/`Quantity`.
- Don't make a module know a chain of others' internals: `order.customer.address.city` is a coupling smell.

## Abstractions come from pressure, not imagination

- Don't build interfaces, factories, or hierarchies "for the future."
- Polymorphism pays off when variants genuinely grow; for two clear branches a plain `if` is honest.
- Config should control what actually varies. If everything is configurable, the system has no shape.

## Quarantine concurrency

Keep async, threads, locks, and retries away from business logic — otherwise you must understand both the task and the execution order at once.

## Tests are readers with authority

A good test explains its scenario fast, checks observable behavior, is independent and repeatable, and fails for a clear reason. One tested idea matters more than a literal single assert.

## Smells: the code asking for help

Look closer when: a small change triggers a cascade; a fix breaks unrelated places; logic is scary to reuse; identical code multiplies; there are more abstractions than problem; nothing makes sense without the author.

## Final filter

1. Can it be understood without investigation?
2. Does each part do one clear thing?
3. Any hidden effects or needless coupling?
4. Anything built "just in case"?
5. Is the main behavior covered by tests?
6. Does anything trip a SOLID smell?

**Clean code isn't the cleverest. It's the most predictable.**
