# ADR 0005: Use A Custom Bilingual Candidate Panel For Mode 1

## Status

Accepted

## Decision

Mode 1 uses a custom AppKit candidate panel instead of stock `IMKCandidates` annotation.

The panel renders a bilingual matrix:

- compact mode: `2x5`
- expanded mode: `5x5`
- each candidate cell keeps Chinese on the upper line and English on the lower line

`Shift` toggles the active layer for the selected cell, `+` expands or collapses the current page, and confirming a candidate commits the current layer only.

## Rationale

This interaction is now part of the product definition rather than a future polish step.

The stock candidate path can show a selected candidate plus annotation, but it does not naturally support:

- a compact bilingual matrix plus an expanded matrix for the same page
- persistent active-layer highlighting
- English-layer selection and commit behavior

A custom panel keeps the interaction model explicit while still allowing the Chinese engine and translation provider to remain modular.

The panel is also now coupled to a thin host bridge:

- `IMKInputController` owns event routing, marked-text synchronization, and anchor resolution
- session state stays free of `NSTextInputClient` and AppKit window geometry
- anchor resolution prefers the client's line-height rectangle
- missing fresh geometry may reuse the current session's last valid anchor, but never falls back to mouse position
