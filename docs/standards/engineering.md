# Engineering Standards

## Goals

- Keep the InputMethodKit shell thin.
- Keep the domain model deterministic and testable.
- Keep project regeneration, installation, and packaging reproducible.

## Module boundaries

- `BilineCore` owns composition state, candidates, paging, commit behavior, and engine protocols.
- `BilinePreview` owns translation provider contracts, cache behavior, and stale-result suppression.
- `BilineMocks` owns fixture-driven demo implementations and demo resources.
- `BilineTestSupport` owns reusable test fixtures and test helpers.
- `App/` adapts platform events to package APIs and renders current state into `IMKInputController` / `IMKCandidates`.

## Naming

- Use nouns for long-lived types and verbs for side-effectful methods.
- Use `Snapshot`, `State`, `Result`, `Config`, and `Key` for value types.
- Keep one primary type per file unless two types are tightly coupled and trivial.

## Logging and errors

- Use `OSLog` in app and integration code.
- Use typed errors for package targets.
- Do not leave `print()` statements in tracked code.

## Testing

- New core behavior needs unit tests in `Tests/`.
- Prefer fixture-driven tests over brittle stringly ad hoc setup.
- Treat stale-result handling as required behavior, not best effort.

## Dependency policy

- Runtime dependencies require an ADR and a `THIRD_PARTY_NOTICES.md` update.
- Developer tooling may be added when it reduces long-term maintenance overhead.
- Prefer Apple platform APIs, Swift Package modules, and local scripts before adding new tools or libraries.

## Task template

Use this task structure when asking Codex to work in this repo:

- Goal
- Context
- Constraints
- Done when
