# BilineIME

<!-- markdownlint-disable MD033 -->
<p align="center">
  <img width="120" alt="BilineIME logo" src="https://github.com/user-attachments/assets/93da38f4-0a86-4ba3-8c33-29ad3645cc1b" />
</p>

<p align="center">
  <strong>A macOS input method for bilingual thinking.</strong>
</p>

<p align="center">
  Type Chinese. Glance at English. Stay in flow.
</p>

<p align="center">
  🧪 Experimental · 🍎 macOS · ⌨️ Input Method Kit · 📝 MIT
</p>
<!-- markdownlint-enable MD033 -->

---

## ✨ What Is This?

BilineIME is an experimental Chinese input method for macOS that explores bilingual writing **inside** the input workflow.

The core idea is simple:

- you type Chinese as usual
- the input method shows you the current Chinese candidate
- at the same time, it gives you a lightweight English preview

No copy-paste.
No app switching.
No breaking your sentence halfway through just to check how it would sound in another language.

## 🎯 Current Focus: Mode 1

BilineIME has two long-term ideas, but the first implementation is focused on **Mode 1 only**.

### Mode 1 = Translation Preview During Composition

- first line: Chinese candidate text
- second line: translated preview in a target language

This is the version we are actively building.

<!-- markdownlint-disable MD033 -->
<p align="center">
  <img alt="BilineIME concept mockup" src="https://github.com/user-attachments/assets/241accd9-2a5b-4707-9f55-18b92fd9c95c" width="220" />
</p>
<!-- markdownlint-enable MD033 -->

### Mode 2 = Reversible Translation Operator

Mode 2 is still part of the product vision, but it is deliberately deferred.

That mode would treat `=` as a local transform operator for nearby Chinese text, turning it into translated output and allowing toggling back and forth. It is interesting, but it belongs to a different interaction layer and adds a much heavier editing model.

For now:

- ✅ Mode 1 is in scope
- ⏸️ Mode 2 is parked for later

## 🔥 Why This Exists

Most translation workflows are awkward during writing:

1. type something
2. copy it
3. leave the editor
4. translate it
5. come back
6. try not to lose the sentence in your head

BilineIME is trying to collapse that loop into a single place: the input method itself.

This project is for:

- bilingual drafting
- language learning
- quick expression checking
- writing without breaking cognitive flow

## 🧭 Why Mode 1 First

Mode 1 is the right first move because it:

- validates the bilingual-writing idea without rewriting committed text
- stays inside the normal macOS IME composition lifecycle
- lets the project test latency, UI usefulness, and interaction quality early
- creates a clean foundation before tackling the much harder Mode 2 editing semantics

## ✅ v1 Scope

- macOS only
- Chinese input first
- a custom bilingual candidate panel with two rows per visible candidate
- `Shift` toggles the active layer between Chinese and English for the selected candidate
- confirming a candidate commits the active layer only
- translation must never block typing
- debounce, caching, and stale-result suppression
- target language setting
- English preview never changes Chinese candidate ordering, paging, or ranking
- architecture ready for future expansion, but still centered on Mode 1

## 🚫 v1 Non-Goals

- sentence-level reversible translation
- the `=` transform operator
- `Backspace`-driven reversion logic
- simultaneous Chinese-and-English pair commit
- locking the project to one translation provider forever

## 🏗️ Current Repo State

This repo already contains a real demo foundation:

- a Swift Package for core composition, preview coordination, and fixture-backed demo logic
- an InputMethodKit shell app for macOS
- Xcode project generation via `project.yml`
- scripts for local install and internal package generation
- architecture, standards, and ADR docs to keep the repo from turning into a mess

The source of truth for the app project is:

- `project.yml`

Generated artifacts such as:

- `BilineIME.xcodeproj`
- generated support plists

are intentionally ignored and should be regenerated locally, not committed.

## 🛠️ Development

```bash
make bootstrap
make project
make test
make build-ime
make install-ime
make package-internal
make verify
```

What they do:

- `make bootstrap` installs developer tooling
- `make project` regenerates the Xcode project
- `make test` runs Swift Package tests
- `make build-ime` builds the input method app
- `make install-ime` installs it into `/Library/Input Methods`
- `make package-internal` builds an unsigned internal `.pkg`
- `make verify` runs tests plus a full Xcode build

## 🧠 Architecture

The implementation blueprint lives in:

- `docs/architecture.md`

The engineering rules live in:

- `AGENTS.md`
- `docs/standards/engineering.md`
- `docs/standards/acceptance.md`
- `docs/adr/`

The high-level architecture direction is:

- keep InputMethodKit glue thin
- keep composition and preview logic in testable Swift Package modules
- start with a thin local engine
- keep a clean path toward a future `librime` adapter
- use a custom AppKit bilingual candidate panel for Mode 1

## 🤝 Open-Source Policy

This project can learn from earlier work, but it does not hand-wave attribution.

Rules:

- every upstream project we study or integrate must be recorded in `THIRD_PARTY_NOTICES.md`
- every adapted dependency or code path must keep its source and license visible
- reference-only and reusable sources must be distinguished clearly
- GPL projects may be studied, but their code will not be copied into this MIT repository unless the license strategy changes explicitly

If you care about open-source hygiene, this repo does too.

## 🗺️ Roadmap

### Phase 0 — Shell

- [ ] Create a minimal macOS InputMethodKit project
- [ ] Register and enable the input method
- [ ] Handle basic key events
- [ ] Show marked text and commit selected text
- [ ] Prove the custom candidate panel loop works end to end

### Phase 1 — Mode 1 Vertical Slice

- [ ] Produce simple Chinese candidates from a small local engine or mock engine
- [ ] Display each visible candidate as a Chinese row plus an English row
- [ ] Toggle the active commit layer with `Shift`
- [ ] Trigger English preview loading for the visible candidate page
- [ ] Keep translation requests fully asynchronous
- [ ] Ignore stale translation results when the visible page changes
- [ ] Add target-language configuration

### Phase 2 — Mode 1 Hardening

- [ ] Replace the mock engine with a real Chinese composition backend
- [ ] Add debounce and memory cache for previews
- [ ] Improve failure handling and fallback behavior
- [ ] Test cross-app compatibility on common macOS editors
- [ ] Refine custom panel layout and long-translation behavior

### Later

- [ ] Revisit Mode 2 as a separate architecture track
- [ ] Add simultaneous bilingual pair commit mode
- [ ] Add custom glossary and user phrases
- [ ] Improve cross-app compatibility and settings UX

## 🚧 Status

Early-stage research prototype.

Still rough.
Already real.
Not pretending to be finished.
