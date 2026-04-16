# BilineIME

BilineIME is an experimental Chinese input method for macOS that explores bilingual writing directly inside the input workflow.

The project has two long-term interaction ideas, but the first implementation will focus only on **Mode 1**.

## Current Focus — Mode 1

Mode 1 keeps Chinese composition as the primary input flow while showing a lightweight translation preview for the currently selected candidate:

- first line: Chinese candidate text
- second line: translated preview in a target language

The goal is to help the user think bilingually without leaving the input method or interrupting normal Chinese typing.

<img width="1536" height="1024" alt="BilineIME concept mockup" src="https://github.com/user-attachments/assets/241accd9-2a5b-4707-9f55-18b92fd9c95c" />

## Deferred Direction — Mode 2

Mode 2 is still part of the product vision, but it is intentionally deferred until after Mode 1 works well.

In that mode, typing `=` after a Chinese clause or sentence would translate the nearby text in place and allow reversible toggling between source and target. That interaction requires a different set of document-range and edit-session rules, so it is not part of the first implementation milestone.

## Why Mode 1 First

- It validates the core idea of bilingual assistance inside the IME without taking on document rewrite semantics.
- It stays inside the normal composition lifecycle of a macOS input method.
- It lets the project test latency, candidate UI, and translation usefulness before designing reversible editing.
- It creates a clean foundation for later deciding whether Mode 2 belongs inside the same IME or in a separate extension layer.

## Why Two Modes?

These two modes serve different writing needs:

- **Mode 1** is preview-oriented: it helps the user think bilingually while still committing Chinese text.
- **Mode 2** is transform-oriented: it lets the user quickly turn a Chinese draft into target-language text and revert back for further editing when needed.

Together, they frame BilineIME not only as an input method, but as an experimental bilingual writing interface.

<img width="1536" height="1024" alt="BilineIME modes concept" src="https://github.com/user-attachments/assets/09e01b0a-884e-4b07-9ee8-bbd3e045956b" />

## Current Scope

- macOS only
- Chinese input first
- translation preview for the currently selected candidate
- translation must never block input
- debounce, caching, and stale-result suppression
- target language setting
- architecture prepared for Mode 2, but Mode 2 is not part of v1

## Non-Goals For v1

- sentence-level reversible translation
- `=` transform operator
- `Backspace`-driven reversion logic
- bilingual commit mode
- a custom candidate window before the stock IME candidate flow is validated
- locking the project to a single translation provider

## Architecture

The implementation blueprint lives in `docs/architecture.md`.

That document records:

- the v1 product boundary
- macOS InputMethodKit constraints
- candidate UI and translation preview options
- Chinese composition engine options
- the recommended delivery path for a first working prototype

## Open-Source Attribution

This project may learn from earlier input methods, sample projects, and language-engine work, but it will reference them explicitly and conservatively.

Rules for this repository:

- every upstream project we study or integrate must be recorded in `THIRD_PARTY_NOTICES.md`
- every bundled dependency or adapted code path must carry its original project name, URL, and license
- reference-only projects and code-reuse candidates must be distinguished clearly
- GPL-licensed projects may be studied as references, but their code will not be copied into this MIT-licensed repository unless the licensing decision changes explicitly

At the moment this repository contains no vendored third-party code yet; the notices file exists to keep that boundary explicit from the start.

## Status

Early-stage research prototype.

There is currently no implementation in this repository yet; the immediate goal is to turn the product idea into a concrete build plan for Mode 1.

# Roadmap

## Phase 0 — Shell

- [ ] Create a minimal macOS InputMethodKit project
- [ ] Register and enable the input method
- [ ] Handle basic key events
- [ ] Show marked text and commit selected text
- [ ] Prove the stock candidate UI loop works end to end

## Phase 1 — Mode 1 Vertical Slice

- [ ] Produce simple Chinese candidates from a small local engine or mock engine
- [ ] Display the current candidate with the system candidate UI
- [ ] Trigger translation preview for the selected candidate
- [ ] Keep translation requests fully asynchronous
- [ ] Ignore stale translation results when selection changes
- [ ] Add target-language configuration

## Phase 2 — Mode 1 Hardening

- [ ] Replace the mock engine with a real Chinese composition backend
- [ ] Add debounce and memory cache for previews
- [ ] Improve failure handling and fallback behavior
- [ ] Test cross-app compatibility on common macOS editors
- [ ] Evaluate whether the stock annotation UI is good enough or a custom bilingual panel is needed

## Later Exploration

- [ ] Revisit Mode 2 as a separate architecture track
- [ ] Add bilingual commit mode
- [ ] Add custom glossary and user phrases
- [ ] Improve cross-app compatibility and settings UX
