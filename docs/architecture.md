# BilineIME Architecture

## Product boundary

BilineIME is a macOS Chinese input method with one fixed product model:
**Chinese-first composition with optional bilingual preview**.

The non-negotiable rules are:

- Chinese candidate generation, ranking, paging, and commit state remain the
  source of truth.
- English preview is an overlay, not a separate input mode.
- Turning bilingual capability off yields a plain Chinese-first pinyin workflow.
- Translation preview must never block Chinese typing, browsing, or commit.

The user-facing interaction remains:

- type pinyin
- edit the live pinyin composition with a raw cursor when needed
- browse Chinese candidates
- optionally inspect English preview for visible candidates
- commit either the Chinese candidate or the ready English preview

## Runtime components

### 1. IME host layer (`App/`)

The InputMethodKit app owns macOS integration:

- `IMKServer` bootstrap
- `IMKInputController` lifecycle
- host key-event routing
- marked-text synchronization
- candidate-panel anchoring and presentation
- text insertion into the current client

This layer should stay thin. Host-facing glue belongs here; durable composition
state and ranking logic do not.

### 2. Composition / preview / engine packages (`Sources/`)

The Swift package targets own the deterministic core:

- `BilineCore`: shared core models and protocols
- `BilineSession`: composition state machine, active-layer state, snapshot
  shaping, raw-cursor editing, browsing, commit behavior
- `BilinePreview`: request scheduling, debounce, cache, stale-result suppression
- `BilineRime`: runtime candidate engine integration
- `BilineSettings`: settings snapshot model, defaults wrappers, shared
  configuration/credential stores
- `BilineOperations`: lifecycle planning, install/remove/reset/diagnose
- `BilineIPC`: broker contracts, client, and coordination hub

This split is the reason `Tests/` can stay CI-safe: most stateful behavior lives
outside AppKit and can be exercised without a real host app.

### 3. Settings app (`Companion/`)

The Settings app is a native SwiftUI companion app. It does not own composition
logic; it owns human-facing configuration and diagnostics.

Current top-level sections are:

- Translation
- Input Settings
- Appearance
- Status

Its responsibilities are:

- editing the shared configuration snapshot
- saving translation credentials
- surfacing lifecycle and broker status
- opening system settings and local folders from user actions

### 4. Broker / shared state layer (`Broker/`, `BilineIPC`, `BilineSettings`)

Settings/IME coordination is broker-mediated.

The active model is:

- `BilineBrokerDev` is the user-scoped coordination process
- `BilineCommunicationHub` is the shared façade used by both the IME and the
  Settings app
- shared configuration is persisted through the shared configuration store
- Alibaba credentials are persisted through a shared Keychain-backed vault, with
  a legacy file fallback retained only for migration/recovery
- the IME observes broker invalidations and applies engine-sensitive settings at
  safe boundaries rather than mid-composition

This replaced the older “each process writes its own local state and hopes the
other side notices” model.

### 5. Developer tooling (`Sources/bilinectl/`)

`bilinectl` owns local developer workflows:

- install / remove / reset / prepare-release
- diagnose
- credentials helpers
- source-readiness checks
- local real-host smoke

The important boundary is:

- `Tests/` is for CI-safe package tests
- `Sources/bilinectl/` is for local machine automation that drives TextEdit,
  input-source state, and telemetry

The host smoke harness lives in `bilinectl` on purpose; it is not a SwiftPM
test target and is not a CI gate.

## Data ownership

### Chinese candidates

Chinese candidate generation is behind `CandidateEngine`. The production runtime
uses Rime. Fixture/dictionary engines remain useful for tests and deterministic
examples, but not as app-level fallbacks.

Current Rime schemas:

- `biline_pinyin_simp`
- `biline_pinyin_trad`

### Preview state

Preview work is owned by `PreviewCoordinator` and
`TranslationPreviewScheduler`:

- request-key generation
- debounce
- visible-page scheduling
- selected-candidate priority
- request coalescing
- provider concurrency and rate limiting
- cache lookup
- stale-result suppression
- timeout and failure states

### Configuration and credentials

The canonical runtime configuration is the shared snapshot loaded through
`BilineCommunicationHub`, not ad hoc per-process local defaults.

Credentials are expected to resolve through the shared Keychain-backed vault.
Legacy file storage still exists only to avoid breaking old local data during
migration and recovery.

## Runtime flows

### Composition

1. The user types pinyin.
2. The IME host controller routes the event into `BilingualInputSession`.
3. The session updates the active engine snapshot.
4. The host layer synchronizes marked text and candidate panel state.
5. Visible candidates are handed to preview coordination.
6. Cached previews appear immediately when available.
7. Async preview results are ignored when they no longer match the visible-page
   state.

Raw pinyin editing is part of composition, not host text editing. The session
owns a raw cursor inside `rawInput`; the host layer renders it through marked
text. `Option+Left/Right` move by pinyin block, `Command+Left/Right` move to
the composition edges, `Option+Backspace` deletes the previous pinyin block, and
`Command+Backspace` deletes to the raw cursor start. Plain `Left/Right` browse
candidate columns only when the raw cursor is at the end of the composition;
otherwise they move the raw cursor by character and are consumed by the IME.
Modified arrows/backspace must not leak to the host while composing.

### Browsing and commit

Browsing changes only selection and presentation state. It must never let
preview text reorder Chinese candidates.

Commit behavior is explicit:

- Chinese layer commits the selected Chinese candidate.
- English layer commits only a ready preview.
- Whole-composition commits clear composition.
- Prefix commits may leave a proven tail when the engine can justify it.

The custom candidate panel remains a candidate UI: in candidate mode it renders
the bilingual matrix only. Raw-buffer-only composition is the fallback case where
the panel renders the raw buffer because no candidate matrix exists. Normal
pinyin and cursor presentation belong to marked text in the host.

### Settings refresh

Settings updates are intentionally split:

- lightweight view/config changes may apply immediately
- engine-sensitive fields such as candidate layout, page size, and fuzzy pinyin
  must respect safe boundaries

The broker queues invalidation; the IME consumes it at lifecycle boundaries such
as activate / idle / commit so the live composition is not invalidated midway
through typing.

## Installation and lifecycle

The active lifecycle lane is the dev lane:

- `BilineIMEDev.app` installs into `~/Library/Input Methods`
- `BilineSettingsDev.app` installs into `~/Applications`
- `BilineBrokerDev` installs into `~/Library/Application Support/BilineIME/Broker`
- its LaunchAgent installs into `~/Library/LaunchAgents`

Trusted tester packages may install those same dev-lane components at system
paths.

The release target still exists in project configuration, but supported release
packaging is paused.

`bilinectl` is the lifecycle source of truth. Make targets are wrappers around
it.

## Verification model

Verification is layered:

1. focused package tests
2. `make build-ime`
3. `make install-ime`
4. manual source enrollment if macOS still needs it
5. real-host TextEdit verification

The real-host layer has two modes:

- manual smoke
- explicit local harness: `bilinectl smoke-host dev --confirm` /
  `make smoke-ime-host`

The harness:

- is local-only
- is never a CI gate
- classifies readiness before it drives the host
- may temporarily switch the current input source and restore it afterwards
- keeps exactly one `TextEdit` session alive
- exports telemetry/artifacts for candidate popup, browse, commit, and
  settings-refresh checks

The current baseline `full` scenario exercises:

- candidate popup
- browsing
- commit
- safe-boundary settings refresh

The baseline does not yet cover the full raw-cursor editing surface, including
modified arrows, block deletion, and middle-of-composition insertion. Those are
covered by package tests and remain high-priority real-host smoke expansion
targets.

## Current priorities

- keep Chinese IME behavior as the source of truth
- keep simplified and traditional Rime schemas stable
- keep raw pinyin cursor editing host-safe
- keep broker-backed configuration and credential coordination reliable
- expand host smoke beyond the current baseline into harder punctuation, editing,
  mixed-input, and layer-persistence scenarios
- keep the docs, diagnostics, and lifecycle tooling aligned with the actual dev
  lane

## References

Primary platform references:

- Apple InputMethodKit overview:
  <https://developer.apple.com/documentation/inputmethodkit>
- Apple `IMKInputController`:
  <https://developer.apple.com/documentation/inputmethodkit/imkinputcontroller>
- Apple `NSTextInputClient`:
  <https://developer.apple.com/documentation/appkit/nstextinputclient>

Project and ecosystem references:

- `librime`: <https://github.com/rime/librime>
- Squirrel: <https://github.com/rime/squirrel>
- `libpinyin`: <https://github.com/libpinyin/libpinyin>
- IMKit sample project:
  <https://github.com/ensan-hcl/macOS_IMKitSample_2021>
