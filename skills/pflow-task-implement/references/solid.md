# SOLID: five principles of OO design

Definitions the model already knows are useless here. What matters: the **smell** that signals a violation and the **fix**.

## S — Single Responsibility

One reason to change. If describing the class needs "and" (validates *and* saves *and* formats), split it.

- **Smell:** unrelated methods; a change for one reason forces edits for another; "Manager"/"Util" god-classes.
- **Fix:** separate by axis of change — each collaborator owned by whoever has a reason to change it.

## O — Open/Closed

Add behavior without editing working code.

- **Smell:** a growing `switch`/`if` on a type tag that you extend for every new case.
- **Fix:** make the varying part a strategy/polymorphic type; new case = new class, not a new branch. Don't pre-build this for two stable, unchanging cases.

## L — Liskov Substitution

A subtype must work everywhere its base type does, without surprises.

- **Smell:** overrides that throw `NotSupported`, tighten inputs, weaken outputs, or need `instanceof` checks at call sites.
- **Fix:** if a subtype can't honor the contract, it isn't a subtype — prefer composition over inheritance.

## I — Interface Segregation

No client should depend on methods it doesn't use.

- **Smell:** implementers stubbing methods with empty bodies or throws; one fat interface serving unrelated callers.
- **Fix:** split into small role-based interfaces; each client sees only what it calls.

## D — Dependency Inversion

Depend on abstractions, not concretes; high-level policy must not depend on low-level detail.

- **Smell:** business logic that `new`s a concrete DB/HTTP/clock, hard-coding an untestable dependency.
- **Fix:** depend on an interface, inject the implementation.
