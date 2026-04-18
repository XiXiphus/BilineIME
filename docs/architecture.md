# BilineIME Architecture Blueprint

## Purpose

This document turns the current product idea into a concrete implementation plan.

It intentionally treats **Mode 1** as the only first-phase target:

- Chinese composition remains the primary workflow
- candidates are rendered as a bilingual matrix for the current page, with compact mode showing the first row and expanded mode showing all real visible rows up to `5x5`, with Chinese rows grouped above English rows
- `Shift+Tab` switches the active commit layer for the current highlighted candidate cell between Chinese and English without changing the selected candidate
- once switched, the active layer persists across further typing and candidate browsing until commit, cancel, or session end
- `=` / `]` expand from compact mode and jump to the next candidate row while candidate browsing is active; in raw-buffer-only composition they are preserved as literal input
- `-` / `[` move to the previous candidate row and collapse back to the compact first item when already on the first row; before any successful expansion they may push composition into a raw-buffer-only literal state
- `+` is treated as an ordinary input character with no IME-specific behavior
- punctuation is handled by a fixed Chinese-mode punctuation policy, so raw preedit display and committed punctuation render as Chinese/full-width forms without pushing symbol-specific rules into the key router
- translation never blocks typing

Mode 2 remains a later extension and is documented here only as a deferred architecture concern.

## Product Boundary For v1

### In Scope

- a macOS input method built on InputMethodKit
- Chinese composition with marked text and candidate selection
- a custom bilingual candidate panel for the current candidate page
- English preview for each visible candidate
- active-layer commit between Chinese and English
- asynchronous translation requests
- caching and stale-result suppression
- a settings surface for target language and preview behavior

### Out Of Scope

- reversible sentence-level translation triggered by candidate browse keys
- tracking committed document ranges after composition ends
- backspace-driven restoration of earlier source text
- simultaneous bilingual pair commit formats
- shipping a production-grade Chinese IME on day one

## Facts That Shape The Design

The following are platform facts, not project guesses:

1. Apple's `InputMethodKit` provides the core macOS IME integration points through `IMKServer` and `IMKInputController`.
2. `IMKServer` creates an `IMKInputController` for each input session, so composition state is naturally session-scoped.
3. The client side of composition is still based on marked-text semantics through `NSTextInputClient`, where marked text and committed text are separate states.
4. `NSTextInputClient` exposes caret geometry, so a custom candidate panel can be anchored near the active insertion point.

These facts lead to three immediate design conclusions:

- Mode 1 should stay inside the normal composition lifecycle rather than edit already committed document text.
- Mode 1 should own its bilingual candidate presentation explicitly rather than approximate it through annotation.
- Session-local composition state and app-wide shared services should be separated from the start.

One additional implementation rule now follows from the same platform boundary:

- host-event routing, marked-text synchronization, and anchor resolution should live in a thin IMK bridge layer rather than leak into the composition session model
- custom candidate anchoring should prefer the client-provided line-height rectangle rather than document-range rect lookup
- if the host cannot provide a fresh valid caret rect, the custom panel may reuse the last valid rect from the current IME session, but must never fall back to mouse position
- editing keys outside composition should pass through to the host application unchanged

## Decision Summary

| Area | Decision For First Blueprint | Why |
| --- | --- | --- |
| IME host | Native macOS `InputMethodKit` app in Swift/AppKit | This is the canonical integration path on macOS. |
| Candidate UI | Custom bilingual AppKit candidate panel | Required to render both rows for every visible candidate and support layer switching. |
| Chinese engine | Use a pluggable engine interface; start with a simple local engine or mock, but leave a clean path to a mature backend | The interaction can be validated before solving full Chinese IME quality. |
| Durable engine target | Prefer a mature adapter such as `librime` if the goal becomes daily-usable Chinese input | Avoids rebuilding a full Chinese IME from scratch. |
| Translation provider | Protocol-based async provider with cache and cancellation | Keeps preview logic independent from vendor or transport. |
| Process model | Single process first; XPC helper only if later required by sandboxing, distribution, or stability concerns | Avoid early complexity. |

## Installation Model

The repository treats developer installation and release installation as two different system states:

- `BilineIME Dev` is the developer-only input method installed into `~/Library/Input Methods`
- `BilineIME` is the release-facing input method installed into `/Library/Input Methods`

This split keeps debug iteration from colliding with release-facing `TIS`, `HIToolbox`, and Launch Services state.

The repository also treats **repair** as a separate concern from **install**:

- install scripts should only build, copy, and register Biline bundles
- repair scripts may prune Biline state from `HIToolbox`, clear text-input caches, or reset Launch Services as a last resort
- install is conservative by default; it does not promise automatic source selection

The expected launch model is also explicit:

- installation copies the bundle into an Input Methods directory
- the user enables or selects the input source in Keyboard settings or the menu bar
- macOS and `imklaunchagent` launch the process when the input source is activated

The project does not treat `open /path/to/InputMethod.app` as a normal installation step.

## Attribution And License Policy

This project is MIT-licensed, so upstream reuse must be intentional and documented.

The project will use four different labels for external work:

| Label | Meaning | Required action |
| --- | --- | --- |
| Documentation reference | Apple docs, Q&A pages, API references | Cite in docs when they shape behavior or architecture. |
| Architecture reference | Another project's high-level structure or delivery approach informed a design choice | Record in `THIRD_PARTY_NOTICES.md` as reference-only. |
| Code adaptation candidate | Small snippets, bootstrap patterns, or implementation ideas may be adapted | Record source, license, and touched files before landing code. |
| Bundled dependency | Upstream library or engine shipped with or linked into BilineIME | Preserve original license/notice files and document scope of use. |

Practical rules:

- never copy code from a project unless its license is compatible with BilineIME's MIT license or the repository license is deliberately changed
- keep GPL projects as reference-only unless the licensing strategy is revisited explicitly
- when adapting code from a permissive project, keep the source project and license visible in both `THIRD_PARTY_NOTICES.md` and the relevant implementation area
- if a future commit vendors a third-party component, that commit must update notices in the same change

Current implications for the projects already referenced in this blueprint:

- `librime` is BSD-3-Clause and is a viable future dependency candidate
- Squirrel is GPL-3.0 and should be treated as an architecture reference, not a copy source, under the current MIT license
- `libpinyin` is GPL-3.0 and should also stay reference-only unless licensing changes
- `IMKitSample_2021` and `pinyinIME` are permissively licensed references and may be adapted only with explicit attribution

## Option Analysis

### 1. How To Build The Chinese Composition Engine

#### Option A: Build A Minimal Engine From Scratch

Pros:

- smallest conceptual surface
- full control over composition and ranking behavior
- easiest way to get a shell prototype running

Cons:

- Chinese IME quality becomes the main project instead of bilingual preview
- candidate quality, segmentation, learning, and dictionaries become a large parallel effort
- likely needs replacement before the project is usable beyond demos

Use when:

- the immediate goal is only to validate the IME event loop and preview interaction

#### Option B: Integrate `librime`

Pros:

- mature open-source input method core
- explicit support for Chinese input method scenarios
- existing macOS frontend precedent through Squirrel
- BSD-3-Clause core is friendlier than GPL-based alternatives for downstream flexibility

Cons:

- heavier dependency and build setup
- its schema/configuration model is more complex than a tiny prototype needs
- adaptation work is still non-trivial

Use when:

- the project wants a realistic path from prototype to a usable Chinese IME

#### Option C: Use A Smaller Sidecar Engine Such As `pinyinIME`

Pros:

- small and easy to understand
- explicit support for HTTP-sidecar integration with native IME frontends
- useful for rapid experimentation

Cons:

- adds Python/runtime and local HTTP process complexity
- weaker long-term macOS-native story than a direct native engine
- becomes another moving part before the product interaction is proven

Use when:

- the project values iteration speed over native purity for early experiments

#### Recommendation

Use a **two-step path**:

1. Build the IME shell against a very small local engine or mock engine.
2. Keep the engine behind a protocol so the project can later swap in `librime` without rewriting UI, session, or preview logic.

This keeps the first milestone small while preserving a serious long-term path.

### 2. How To Show The Translation Preview

#### Option A: Use A Custom Bilingual Candidate Panel

Pros:

- exact control over two-line layout for every visible candidate
- explicit active-layer highlighting for Chinese and English
- matches the commit behavior required by Mode 1

Cons:

- significantly higher UI and positioning complexity
- more chances of app-specific compatibility problems
- requires the app shell to own more rendering code

#### Recommendation

Use **Option A**.

The required interaction already assumes a custom panel, so the system candidate window is no longer the product baseline.

### 3. How To Execute Translation Requests

#### Option A: In-Process Provider

Pros:

- simpler architecture
- easiest path for a prototype
- lower integration overhead

Cons:

- network errors or slow provider code live in the IME process
- may need refactoring if sandboxing or distribution constraints appear later

#### Option B: XPC Helper

Pros:

- isolates network and model execution work
- cleaner process boundaries
- better long-term stability if translation becomes complex

Cons:

- more moving parts
- more packaging and debugging overhead
- too much complexity for the first vertical slice

#### Recommendation

Start with **Option A**, but keep translation behind a protocol and coordinator boundary so an XPC helper can be added later without rewriting the input controller.

## Recommended Architecture

## High-Level Structure

```text
InputMethod App Bundle
  AppDelegate / Bootstrap
  SessionController (IMKInputController)
  CandidatePanelController (custom bilingual panel)
  Menu / Preferences bridge

Core Domain
  BilingualInputSession
  CandidateEngine protocol
  PreviewCoordinator
  TranslationProvider protocol
  TranslationCache
  SettingsStore

Future Optional Layer
  TranslationHelperXPC
  Real engine adapter (for example librime)
```

### Responsibilities

#### `SessionController`

- owns one active composition session per IME session
- receives key events and composition callbacks
- updates marked text and candidate UI
- updates the active layer when the user presses `Shift+Tab`
- commits the selected candidate in the current layer
- forwards visible-page changes to the preview coordinator

#### `BilingualInputSession`

- stores raw input buffer
- stores current page candidate list, selected index, and active layer
- stores English preview state for the visible page
- knows whether marked text is active
- exposes state transitions for typing, paging, selection, commit, and cancel

This should be a plain Swift domain object, not a UI object.

#### `CandidateEngine`

- turns the raw phonetic input into Chinese candidates
- can be backed by a mock implementation first
- later can be backed by a mature engine adapter

Important rule:

The session controller should not know whether candidates came from a mock engine, a native engine, or a sidecar service.

#### `PreviewCoordinator`

- listens to candidate selection changes
- listens to visible-page changes
- computes preview request keys
- debounces rapid candidate-page refreshes
- checks cache first
- launches async translation tasks
- drops late results if the session token or visible-page token has changed

#### `TranslationProvider`

- translates a Chinese candidate string into the target language
- reports success, timeout, or failure
- does not know about IME state or candidate UI

#### `TranslationCache`

- keyed by source text + target language + provider identifier
- memory cache first
- optional disk cache later if repeated phrases matter enough

## Runtime Flow

### Normal Composition

1. The user types phonetic input.
2. `SessionController` forwards input to `CompositionSession`.
3. `CompositionSession` asks the active `CandidateEngine` for candidates.
4. `SessionController` updates marked text and refreshes the custom bilingual panel.
5. The current visible page becomes the preview source set.
6. `PreviewCoordinator` checks cache and schedules async translation for visible candidates as needed.
7. When translation returns, the matching English row is updated in place.
8. If the user changes pages or input before the translation returns, the old result is ignored.

### Commit

1. The user confirms a candidate.
2. The active layer text for the selected candidate is committed to the client document.
3. Marked text is cleared.
4. Candidate UI and preview UI are dismissed.
5. The preview session state is reset.

### Failure Cases

- If translation is slow, keep Chinese input responsive and show no preview yet.
- If translation fails, keep composition intact and optionally show a lightweight failure state or nothing at all.
- If the cache has a stale-but-valid preview, it may be shown immediately while a refresh happens in the background, but only if that does not cause UI flicker.

## State Model

The first implementation should use explicit state instead of ad hoc booleans.

### Composition State

Suggested fields:

- `rawInput`
- `markedText`
- `items`
- `presentationMode`
- `selectedRow`
- `selectedColumn`
- `pageIndex`
- `activeLayer`
- `isComposing`

### Preview State

Suggested states:

- `idle`
- `loading(requestKey, token)`
- `ready(requestKey, previewText)`
- `failed(requestKey)`

### Stale Result Rule

Every async translation request must carry:

- session identifier
- visible-page version
- request key

A result may update UI only if all three still match current state.

This rule is critical. Without it, fast candidate navigation will show the wrong translation under the wrong candidate.

## Delivery Plan

### Milestone 1: IME Shell

- create the InputMethodKit bundle
- register the input source
- show marked text
- show candidates from a tiny local engine or fixed candidate source
- commit selected Chinese text

Success condition:

The input method works like a real IME even without translation.

### Milestone 2: Mode 1 Matrix Slice

- add `PreviewCoordinator`
- add async `TranslationProvider`
- show a custom bilingual candidate panel for the visible page
- support a whole-page bilingual matrix, with at most `5` columns and at most `5` rows per page
- support `Shift+Tab` layer switching on the current highlighted candidate cell, candidate-aware `=`/`]` and `-`/`[` row browsing, raw-buffer-only literal input preservation, a fixed Chinese punctuation policy for raw preedit and committed punctuation, and active-layer commit
- ignore stale results
- add target language setting

Success condition:

Typing and candidate navigation stay responsive while the visible page renders as a bilingual matrix with English preview rows.

### Milestone 3: Hardening

- add cache and debounce
- improve failure handling
- add test coverage for state transitions
- run cross-app manual verification
- refine custom panel behavior for long translations and loading states

Success condition:

The feature feels stable enough to evaluate as a real writing aid, not just a demo.

### Milestone 4: Real Engine Upgrade

- replace the toy engine with a real backend
- keep the rest of the stack unchanged except for the engine adapter

Success condition:

Chinese input quality improves without architectural rewrites to the preview stack.

## Testing Strategy

### Unit Tests

- composition state transitions
- candidate selection and pagination
- stale-result suppression
- cache hits and misses
- preview state transitions for success, timeout, and failure

### Manual Smoke Matrix

At minimum test:

- TextEdit
- Notes
- Safari search fields
- Xcode or VS Code
- one terminal app

The goal is to catch marked-text and custom candidate-panel behavior differences across client apps early.

## Why Mode 2 Is Deferred

Mode 2 looks related on the surface, but architecturally it is different.

Mode 1 lives inside composition.
Mode 2 edits already-formed document text near the caret.

That means Mode 2 needs additional machinery:

- clause detection before the caret
- reversible mapping between source text and translated text
- rules for invalidating a reversible edit session
- backspace and repeated-operator semantics
- potentially more surrounding-text awareness than the composition-only path needs

If Mode 2 is mixed into the first milestone, the project will blur two separate systems:

- an IME composition preview system
- a local document transformation system

The correct blueprint is to finish Mode 1 first, then decide whether Mode 2 belongs:

- inside the same IME session model
- inside a helper/editor integration layer
- or in a separate tool entirely

## Open Questions

These are intentionally left open until implementation begins:

- Should the first real engine target simplified Chinese only, or simplified and traditional from the start?
- Which translation backend should be used first: mock glossary, local model, or remote API?
- What latency threshold still feels acceptable for preview usefulness?
- Does the first settings surface live inside the IME menu only, or should it have a separate preferences window?

## References

Primary platform references:

- Apple InputMethodKit overview: <https://developer.apple.com/documentation/inputmethodkit>
- Apple `IMKInputController`: <https://developer.apple.com/documentation/inputmethodkit/imkinputcontroller>
- Apple `NSTextInputClient`: <https://developer.apple.com/documentation/appkit/nstextinputclient>

Project and ecosystem references used for option analysis:

- `librime`: <https://github.com/rime/librime>
- Squirrel (Rime frontend for macOS): <https://github.com/rime/squirrel>
- `libpinyin`: <https://github.com/libpinyin/libpinyin>
- `pinyinIME`: <https://pypi.org/project/pinyinIME/>
- IMKit sample project: <https://github.com/ensan-hcl/macOS_IMKitSample_2021>
