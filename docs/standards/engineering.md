# Engineering Standards

## Goals

- Keep the InputMethodKit shell thin.
- Keep the domain model deterministic and testable.
- Keep project regeneration, installation, and packaging reproducible.

## Module boundaries

- `BilineCore` owns composition state, candidates, paging, commit behavior, and engine protocols.
- `BilineCore` also owns shared pinyin segmentation helpers used by both
  runtime candidate consumption and raw-cursor navigation. Do not fork pinyin
  tokenization rules in host code.
- `BilinePreview` owns translation provider contracts, cache behavior, and stale-result suppression.
- `BilineSession` owns bilingual composition snapshots, active-layer state, and visible-page preview orchestration.
- `BilineSettings` owns settings snapshots, defaults wrappers, shared configuration stores, and credential-store abstractions.
- `BilineOperations` owns lifecycle planning, install/remove/reset execution support, diagnostics, and readiness state.
- `BilineIPC` owns broker models, XPC contracts, client transport, and the communication hub.
- `BilineMocks` owns fixture-driven demo implementations and demo resources.
- `BilineTestSupport` owns reusable test fixtures and test helpers.
- `App/` adapts platform events to package APIs and renders current state into `IMKInputController` plus the custom AppKit candidate panel.
- `Sources/bilinectl/` owns local developer tooling, including lifecycle commands and real-host smoke harness code.
- `Tests/` owns CI-safe Swift Package tests only. Real-host automation must not be moved into `Tests/`.

## Dev-only assets

- `BilineMocks`, `BilineTestSupport`, demo fixtures, and mock translation providers are developer/test assets, not dead runtime code.
- `.env.example` exists only as a template for opt-in live API tests. The Settings app and IME runtime do not read `.env`.
- Live Alibaba translation tests are explicit opt-in; do not treat their environment-variable path as the product credential path.

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
- Treat install, manual source enrollment, and source-ready host smoke as three separate phases. Bundle install does not imply source enrollment; source enrollment is a one-time manual step in System Settings.
- Automated real-host operation is allowed only through the explicit local harness (`bilinectl smoke-host dev --confirm` / `make smoke-ime-host`) and only when the user asks for that exact action in the moment.
- The harness must refuse to start (fail fast with a remediation message) when readiness is not `ready`/`source-not-selected`. Use `bilinectl smoke-host dev --check` to inspect readiness, and `bilinectl smoke-host dev --prepare` to open System Settings without clicking `Allow` for the user.
- Outside that explicit request, Codex and scripts must not switch input sources, focus TextEdit, inject keys, or drive candidate browsing.
- The local host harness must use exactly one `TextEdit` session. If host state is dirty, restart that one session instead of opening multiple windows/documents.
- `scripts/select-input-source.sh current` and `scripts/select-input-source.sh readiness` are read-only and may be used only to report state.
- The baseline smoke-test host is `TextEdit`.
- When validating candidate UI, ask for user-provided screenshots across all active displays when needed.
- `Computer Use` must not operate the input method unless the user explicitly asks for that specific action in the moment.
- Keep the host smoke harness structurally split (support / host driver / harness / CLI) rather than letting one file regrow into a monolith.

### IME Smoke Baseline

CI-safe tests should cover router/session/anchor ordering for the same critical paths. Real-host smoke, manual or harness-driven, should cover at minimum:

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
  - `Option+Backspace`
  - `Command+Backspace`
  - `Space`
  - `Return`
  - digit select
  - `Esc`
- raw cursor editing:
  - `Option+Left` / `Option+Right`
  - `Command+Left` / `Command+Right`
  - plain `Left` / `Right` when the raw cursor is at the end
  - plain `Left` / `Right` when the raw cursor is in the middle
- active-layer persistence:
  - `Shift+Tab`
  - continue typing after layer switch
  - continue browsing after layer switch
- bilingual candidate-aligned commit:
  - `haopingguo` defaults to phrase candidate `好苹果`
  - confirming the phrase in English commits `good apple`
  - selecting the later short-prefix candidate `好` commits `good` and keeps `pingguo` as the new tail composition

### Host Smoke Stress Set

These are not all part of today's automated baseline, but they are the next
high-value stress cases and should guide future harness expansion or manual
verification:

- ambiguous syllable boundaries:
  - `xi'an`
  - `lv`
- mixed full/abbreviated pinyin:
  - `pingguogs`
- punctuation and raw-buffer stress:
  - `shi_`
  - `shi%`
  - `shi()`
  - `shi,`
  - `ni----====+`
- editing and confirmation:
  - `Backspace`
  - `Option+Backspace`
  - `Command+Backspace`
  - `Space`
  - `Return`
  - `Esc`
- raw cursor / candidate-boundary behavior:
  - `nihao`, `Option+Left`, `men`
  - `haopingguo`, `Option+Backspace`
  - plain `Left/Right` should browse only when the raw cursor is at the end
  - plain `Left/Right` should move the raw cursor when it is in the middle
- active-layer persistence:
  - `Shift+Tab`
  - continue typing after layer switch
  - continue browsing after layer switch
- mixed Chinese / Latin:
  - inline Latin input such as `ipad`

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
