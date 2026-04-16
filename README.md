# BilineIME

BilineIME is an experimental Chinese input method for macOS that provides translation preview during text composition.

Instead of treating input methods as pure text entry tools, BilineIME explores a new interaction model:

- first line: Chinese candidate text
- second line: translated preview in a target language

The goal is to support bilingual writing, language learning, and multilingual drafting with minimal context switching.
<img width="1536" height="1024" alt="a5151a4e-c91c-4dde-9089-f1fa39920189" src="https://github.com/user-attachments/assets/241accd9-2a5b-4707-9f55-18b92fd9c95c" />

## Current Scope
- macOS only
- Chinese input first
- translation preview for the currently selected candidate
- focus on interaction quality, latency, and usability

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
- [ ] Add bilingual commit mode
- [ ] Add custom glossary and user phrases
- [ ] Improve cross-app compatibility
