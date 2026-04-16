# BilineIME

BilineIME is an experimental Chinese input method for macOS that explores bilingual writing directly inside the input workflow.

Instead of treating input methods as pure text entry tools, BilineIME explores two complementary interaction models:

## Mode 1 — Translation Preview During Composition

- first line: Chinese candidate text
- second line: translated preview in a target language

This mode keeps the Chinese input flow intact while surfacing a lightweight translation preview for the currently selected candidate.

## Mode 2 — Reversible Sentence-Level Translation

BilineIME also explores a second interaction model designed for bilingual drafting and fast rewriting.

In this mode, the user can type `=` at the end of a Chinese clause or sentence to trigger translation for the text immediately before the caret.

Rather than forcing the user to manually select text, copy it, translate it, and switch back, BilineIME treats `=` as a transform operator:

- type Chinese normally
- press `=` to translate the nearest Chinese clause before the caret
- replace the Chinese text with the translated result
- press `Backspace` to revert the translated block back to the original Chinese
- press `=` again to toggle between source and target
- type `==` to insert a literal `=`

This makes translation a reversible local edit rather than a separate tool or context switch.

The goal is to support bilingual writing, language learning, and multilingual drafting with minimal interruption.
<img width="1536" height="1024" alt="a5151a4e-c91c-4dde-9089-f1fa39920189" src="https://github.com/user-attachments/assets/241accd9-2a5b-4707-9f55-18b92fd9c95c" />

## Why Two Modes?

These two modes serve different writing needs:

- **Mode 1** is preview-oriented: it helps the user think bilingually while still committing Chinese text.
- **Mode 2** is transform-oriented: it lets the user quickly turn a Chinese draft into target-language text and revert back for further editing when needed.

Together, they frame BilineIME not only as an input method, but as an experimental bilingual writing interface.

## Current Scope
- macOS only
- Chinese input first
- translation preview for the currently selected candidate
- reversible translation triggered by `=`
- focus on interaction quality, latency, and usability

## Interaction Notes

### Translation Preview Mode
- Chinese composition remains the primary input flow
- translation is shown as a live preview for the currently selected candidate
- translation should never block input

### Reversible Translation Mode
- `=` triggers translation for the nearest Chinese clause before the caret
- the translated text replaces the original Chinese text
- `Backspace` at the end of the translated block reverts it to the original Chinese
- pressing `=` again toggles between source and target
- `==` inserts a literal `=`
- the reversible session is dropped if the user moves too far away or edits the surrounding text substantially

## Status
Early-stage research prototype.

# Roadmap

## Phase 1
- [ ] Set up a minimal macOS IME project
- [ ] Register and enable the input method
- [ ] Handle basic key events
- [ ] Display simple Chinese candidates
- [ ] Commit selected Chinese text

## Phase 2
- [ ] Add translation preview for current candidate
- [ ] Add debounce and caching
- [ ] Add target language settings
- [ ] Ensure translation never blocks input

## Phase 3
- [ ] Explore two-line candidate UI
- [ ] Prototype reversible translation triggered by `=`
- [ ] Detect the nearest clause before the caret
- [ ] Replace Chinese text with translated output
- [ ] Add revert behavior with `Backspace`
- [ ] Add toggle behavior with repeated `=`

## Phase 4
- [ ] Add bilingual commit mode
- [ ] Add custom glossary and user phrases
- [ ] Improve cross-app compatibility
- [ ] Refine invalidation rules for reversible translation sessions
- [ ] Evaluate whether preview mode and reversible mode should coexist or be user-switchable
