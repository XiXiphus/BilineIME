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
<img width="500" height="100" alt="image" src="https://github.com/user-attachments/assets/c82b595c-3b4f-496d-85dc-4e5043728cd1" />
</p>
<p align="center">
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
- scripts for developer install, diagnostics, and release package generation
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
make build-ime-release
make install-ime
make uninstall-ime
make reset-ime
make repair-ime
make package-release
make diagnose-ime
make verify
```

What they do:

- `make bootstrap` installs developer tooling
- `make project` regenerates the Xcode project
- `make test` runs Swift Package tests
- `make build-ime` builds the developer input method target
- `make build-ime-release` builds the release input method target in a temporary derived-data directory and unregisters it afterwards
- `make install-ime` installs the developer build into `~/Library/Input Methods`
- `make uninstall-ime` removes the developer bundle and unregisters the local dev lane
- `make reset-ime` runs the safe uninstall flow first, then reinstalls the dev lane
- `make repair-ime` runs the staged local repair flow for ghost Biline sources and broken Keyboard settings state
- `make package-release` builds the release installer package
- `make diagnose-ime` prints bundle, TIS, HIToolbox, Launch Services, and recent IMK logs
- `make verify` runs tests plus both IME build variants

Build products are generated under `~/Library/Caches/BilineIME/DerivedData` instead of the repo tree. This avoids Finder/file-provider metadata inside the workspace from breaking app signing.

### Input Method Registration Notes

- The dev lane installs to `~/Library/Input Methods` so it does not collide with the release lane in `HIToolbox`, `TIS`, or Launch Services.
- `make build-ime` and `make install-ime` now try to detect a local Xcode development team from `com.apple.dt.Xcode.plist`. Override that auto-detection with `BILINE_DEV_TEAM_ID=<TEAM_ID>` if needed.
- `make install-ime` now stops at a conservative install boundary:
  - build the dev bundle
  - replace `~/Library/Input Methods/BilineIMEDev.app`
  - refresh Launch Services and `TextInputMenuAgent`
  - leave source enabling and selection to macOS UI
- `make install-ime` no longer treats `TISSelectInputSource == 0` as part of install success. Re-select `BilineIME Dev` manually in Keyboard settings or from the input menu.
- `make uninstall-ime` no longer doubles as a system-cache repair tool. Use `make repair-ime` when Keyboard settings shows blank Biline rows, stale raw ids, or crashes.
- The release lane installs to `/Library/Input Methods` and should be distributed via the installer package, not by manually copying a debug build into the system directory.
- Installing into an Input Methods directory is necessary, but it is not sufficient. The bundle must also expose keyboard input modes through both `ComponentInputModeDict` and `InputMethodServerModeDictionary`, and `IMKInputController.modes(_:)` must return that dictionary.
- `tsVisibleInputModeOrderedArrayKey` must reference the keys inside `tsInputModeListKey`, not the `TISInputSourceID` values.
- The keyboard menu can only select the child input mode, not the root input-method source. Give the child mode a localized display name in `InfoPlist.strings`, or macOS may surface the non-selectable parent row and leave it grey.
- Biline now ships explicit input-method and mode icon metadata so the system picker is less likely to fall back to a raw id or blank row.
- If Keyboard settings shows blank Biline rows, run `make diagnose-ime`.
  - `STALE_BUNDLE_NODE=1` means Launch Services still tracks a missing Biline bundle.
  - `BLANK_TIS_NAME=1` means `TIS` still has a Biline source whose localized name is empty.
- If the input-source picker shows a raw `io.github...` Biline row, that is usually stale Biline state. Run `make repair-ime`.
- `make repair-ime` is staged:
  - level 1: uninstall Biline dev/release, unregister Biline bundles, prune Biline from `HIToolbox`, restart text-input agents
  - level 2: clear `IntlDataCache` and require a reboot
  - level 3: delete the Launch Services database and require a reboot
- `make repair-ime` defaults to level 2. Run `make repair-ime REPAIR_LEVEL=3` only as a last resort.
- First install, bundle-id changes, mode-list changes, and display-name/icon changes should be treated as metadata changes. For those cases, log out and log back in before adding the input source in Keyboard > Input Sources.
- Code-only updates usually do not require a full relogin. Reinstall the bundle, then re-select the input source in the system UI if needed.
- Do not `open` the input method app as part of installation. The expected launch path is: add/select the input source, then let macOS and `imklaunchagent` start the process.
- If the input method appears grey or disappears from the menu, run `make diagnose-ime` before blaming the install path.
- If Launch Services still reports a Biline bundle whose path no longer exists, the explicit last-resort recovery is:
  - `sudo /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -delete`
  - reboot

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
