# Engineering Standards

## Goals

- Keep the InputMethodKit shell thin.
- Keep the domain model deterministic and testable.
- Keep project regeneration, installation, and packaging reproducible.

## Module boundaries

- `BilineCore` owns composition state, candidates, paging, commit behavior, and engine protocols.
- `BilinePreview` owns translation provider contracts, cache behavior, and stale-result suppression.
- `BilineSession` owns bilingual composition snapshots, active-layer state, and visible-page preview orchestration.
- `BilineMocks` owns fixture-driven demo implementations and demo resources.
- `BilineTestSupport` owns reusable test fixtures and test helpers.
- `App/` adapts platform events to package APIs and renders current state into `IMKInputController` plus the custom AppKit candidate panel.

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
- For any IME-facing behavior change, do not stop at tests and build:
  - run focused tests
  - `make build-ime`
  - `make install-ime`
- stop and ask the user to manually select the input source, focus the host, type, browse, commit, and report the result
- Automated real-host operation is prohibited. Codex and scripts must not switch input sources, focus TextEdit, inject keys, or drive candidate browsing.
- `scripts/select-input-source.sh current` is read-only and may be used only to report the current source.
- The baseline smoke-test host is `TextEdit`.
- When validating candidate UI, ask for user-provided screenshots across all active displays when needed.
- `Computer Use` must not operate the input method unless the user explicitly asks for that specific action in the moment.

### IME Smoke Baseline

Manual host verification should cover, at minimum:

- candidate browsing:
  - `shi`
  - `=` expand/down
  - expanded `-` up/collapse
  - left/right arrows
  - up/down arrows
- punctuation and raw-buffer behavior:
  - `shi_`
  - `shi%`
  - `shi()`
  - `shi,`
  - `ni----====+`
- editing and commit:
  - `Backspace`
  - `Space`
  - `Return`
  - digit select
  - `Esc`
- active-layer persistence:
  - `Shift+Tab`
  - continue typing after layer switch
  - continue browsing after layer switch
- bilingual candidate-aligned commit:
  - `haopingguo` defaults to phrase candidate `好苹果`
  - confirming the phrase in English commits `good apple`
  - selecting the later short-prefix candidate `好` commits `good` and keeps `pingguo` as the new tail composition

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
