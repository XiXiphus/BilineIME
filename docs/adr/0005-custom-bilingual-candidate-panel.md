# ADR 0005: Use A Custom Bilingual Candidate Panel For Mode 1

## Status

Accepted

## Decision

Mode 1 uses a custom AppKit candidate panel instead of stock `IMKCandidates` annotation.

The panel renders a bilingual matrix:

- current page: up to `5x5`
- all visible Chinese rows stay grouped in the upper block and all visible English rows stay grouped in the lower block

`Shift` toggles the active layer for the selected cell, `=` / `]` expand from compact mode and jump to the next candidate row, `-` / `[` browse upward and collapse back to the compact first item when already on the first row, `+` has no candidate-window behavior, and confirming a candidate commits the current layer only.

## Rationale

This interaction is now part of the product definition rather than a future polish step.

The stock candidate path can show a selected candidate plus annotation, but it does not naturally support:

- a bilingual matrix for the whole current page while keeping macOS-style candidate browsing
- a maximum page size of `25` without forcing empty cells or rows when fewer candidates are available
- persistent active-layer highlighting
- English-layer selection and commit behavior

A custom panel keeps the interaction model explicit while still allowing the Chinese engine and translation provider to remain modular.

The panel is also now coupled to a thin host bridge:

- `IMKInputController` owns event routing, marked-text synchronization, and anchor resolution
- session state stays free of `NSTextInputClient` and AppKit window geometry
- anchor resolution prefers the client's line-height rectangle
- missing fresh geometry may reuse the current session's last valid anchor, but never falls back to mouse position
