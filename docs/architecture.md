# BilineIME Architecture

## Product Model

BilineIME has one interaction model: composition-time bilingual preview.

Chinese composition remains the primary workflow. The user types pinyin, browses
Chinese candidates, optionally previews English for visible candidates, and
commits either the Chinese candidate or its ready English preview. English
preview is an overlay on top of Chinese input behavior; it never owns candidate
ranking, paging, segmentation, or marked-text state.

The core interaction rules are:

- Candidates render as a bilingual matrix for the current visible page.
- Compact mode shows the first visible row; expanded mode shows all real rows
  up to `5x5`.
- Chinese rows stay grouped above English rows with matching columns.
- `Shift+Tab` switches the active commit layer for the highlighted candidate
  without changing selection.
- Active layer persists across typing and browsing until commit, cancel, or
  session end.
- `=` / `]` browse downward or expand during candidate composition.
- `-` / `[` browse upward or collapse when appropriate.
- `+` is literal input.
- Punctuation rendering follows the configured punctuation form.
- Translation never blocks typing or Chinese commit.

## System Boundaries

### IME Host Layer

The InputMethodKit app owns macOS integration:

- `IMKServer` bootstrap.
- `IMKInputController` session lifecycle.
- Key-event routing.
- Marked-text synchronization with the host.
- Candidate-panel anchoring and presentation.
- Committing text into the current client.

Host-facing code should stay thin. State transitions belong in package modules
where they can be tested without a host app.

### Composition Layer

`BilingualInputSession` owns the composition state:

- raw input buffer
- engine snapshot
- visible candidates
- compact or expanded presentation mode
- selected row, column, flat index, and page
- active commit layer
- preview state for visible candidates
- raw-buffer-only fallback state

It exposes explicit transitions for typing, literal input, browsing, layer
switching, selection, commit, cancel, and delete.

### Chinese Candidate Layer

Chinese candidate generation is behind `CandidateEngine`.

The app runtime uses a Rime-backed engine. Fixture and dictionary engines remain
useful for tests, fallback diagnostics, and deterministic examples. The host and
session layers should not depend on whether candidates came from Rime or a
fixture-backed implementation.

Rime uses separate schemas and user dictionaries for simplified and traditional
output:

- `biline_pinyin_simp`
- `biline_pinyin_trad`

### Preview Layer

`PreviewCoordinator` and `TranslationPreviewScheduler` own preview work:

- request-key generation
- debounce
- visible-page scheduling
- selected-candidate priority
- request coalescing
- provider concurrency and rate limiting
- cache lookup
- stale-result suppression
- timeout and failure states

`TranslationProvider` owns translation transport. The current production path is
Alibaba Cloud Machine Translation, with credentials stored through the native
Settings app.

## Runtime Flow

### Composition

1. The user types pinyin.
2. The host controller routes the key event into the session.
3. The session asks the active candidate engine for a snapshot.
4. The host updates marked text and candidate-panel state.
5. The visible candidate page is sent to preview coordination.
6. Cached previews appear immediately when available.
7. Missing previews are requested asynchronously.
8. Late preview results are ignored when they no longer match current session
   and visible-page state.

### Candidate Browsing

Browsing changes only the selection and presentation state. It must not reorder
Chinese candidates or make preview text influence candidate ranking.

Digit selection chooses a visible column only while composing with candidates.
Editing keys pass through to the host when Biline is not composing.

### Commit

1. The user confirms the selected candidate.
2. The session resolves the active layer.
3. Chinese layer commits the selected Chinese candidate.
4. English layer commits only a ready preview; loading or failed preview does
   not block Chinese commit.
5. Marked text, candidate UI, and preview session state are cleared.

Partial candidate commits preserve remaining raw input when the engine can prove
the consumed span.

## Installation And Lifecycle

Developer installation is the active workflow:

- `BilineIME Dev` installs into `~/Library/Input Methods`.
- `BilineSettingsDev.app` installs into `~/Applications`.
- Trusted tester packages may install the same dev apps into `/Library/Input Methods`
  and `/Applications`.
- `BilineIME` remains as a reserved release target in project configuration,
  but release packaging is paused.

`bilinectl` is the source of truth for dev lifecycle operations. Make targets
are thin wrappers.

Lifecycle operations are intent-first:

- `install` builds and installs the dev apps, then refreshes Launch Services and
  text-input agents.
- `remove` removes installed bundles and can either preserve or purge Biline-local
  data.
- `reset` prunes HIToolbox state and can additionally clear `IntlDataCache` or
  reset the Launch Services database, depending on reset depth.
- `prepare-release` removes dev installs and purges Biline-local data to leave a
  clean release-style environment.

Installation success does not require automatic input-source selection. The user
must manually select the input source and verify in a real host.

## Settings App Structure

The Settings app is a native SwiftUI companion app. It configures the dev input
method bundle and reports lifecycle diagnostics, but it does not own composition
state or host-facing IME behavior.

Settings code is split by responsibility:

- `BilineSettingsModel` stores observable Settings state and small derived
  display strings.
- Defaults persistence owns reads and writes for `BilineDefaultsKey` values.
- Diagnostics owns dev install state, Launch Services registration, current
  input source reporting, Rime user dictionary status, and repair plan text.
- Translation credentials owns Alibaba credential save flow and the manual
  connection test.
- System actions open macOS Settings or local Rime directories only from user
  button actions.
- SwiftUI pages are file-scoped by section: status, translation, and input,
  with shared row/card scaffolding kept separate.

The Settings app must preserve existing defaults keys, bundle identifiers, and
credential paths. It should not duplicate IME session rules, candidate behavior,
or preview scheduling logic.

## Verification Model

Package tests cover deterministic state transitions, preview scheduling, Rime
candidate behavior, and lifecycle planning.

For host-facing IME changes, verification is layered:

1. Focused package tests for the touched behavior.
2. `make build-ime`.
3. `make install-ime`.
4. Manual source enrollment by the user (one-time, in System Settings → Keyboard
   → Input Sources).
5. Real-host TextEdit smoke.

Steps 3 and 4 are separate phases. `make install-ime` only installs the bundle.
Apple's published model for first-time input method onboarding requires the user
to add and enable the source manually, including any "Allow" prompt. The
toolchain does not script that step.

The real-host layer has two modes. The default mode is user-driven: the user
selects `BilineIME Dev`, focuses TextEdit, types, browses, commits, and reports
the result. The explicit local harness mode is `bilinectl smoke-host dev
--confirm` / `make smoke-ime-host`; it may switch input sources and drive
TextEdit only when the user asks for that exact automated action. It is never a
CI gate.

The harness classifies pre-run state as one of `bundle-missing`,
`source-missing`, `source-disabled`, `source-not-selectable`,
`source-not-selected`, or `ready`. It refuses to drive TextEdit unless the state
is `ready` or `source-not-selected`. Use `bilinectl smoke-host dev --check` to
print the report, and `bilinectl smoke-host dev --prepare` to open System
Settings → Keyboard → Input Sources without clicking through any prompts.

Host-smoke telemetry records composition snapshots, anchor resolution, panel
render/show/hide events, browsing state, commits, and settings refresh
boundaries. Candidate-panel visibility is verified through telemetry plus
user-prepared screenshots or manual observation across active displays when
needed.

## Current Engineering Priorities

- Keep Chinese IME behavior as the source of truth.
- Stabilize simplified and traditional Rime schemas and user dictionaries.
- Improve candidate quality without coupling preview logic to the engine.
- Keep preview latency isolated from typing latency.
- Keep Settings and dev lifecycle diagnostics aligned with `bilinectl`.
- Reduce duplicated roadmap/status text outside the README.

## References

Primary platform references:

- Apple InputMethodKit overview: <https://developer.apple.com/documentation/inputmethodkit>
- Apple `IMKInputController`: <https://developer.apple.com/documentation/inputmethodkit/imkinputcontroller>
- Apple `NSTextInputClient`: <https://developer.apple.com/documentation/appkit/nstextinputclient>

Project and ecosystem references:

- `librime`: <https://github.com/rime/librime>
- Squirrel: <https://github.com/rime/squirrel>
- `libpinyin`: <https://github.com/libpinyin/libpinyin>
- `pinyinIME`: <https://pypi.org/project/pinyinIME/>
- IMKit sample project: <https://github.com/ensan-hcl/macOS_IMKitSample_2021>
