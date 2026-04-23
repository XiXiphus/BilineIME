# ADR 0005: Use A Custom Bilingual Candidate Panel For Mode 1

## Status

Accepted

## Decision

Mode 1 uses a custom AppKit candidate panel instead of stock `IMKCandidates` annotation.

The panel renders a bilingual matrix:

- current page: up to `5x5`
- all visible Chinese rows stay grouped in the upper block and all visible English rows stay grouped in the lower block

`Shift+Tab` switches the active layer for the current highlighted cell, `=` /
`]` expand from compact mode and jump to the next candidate row when candidate
browsing is active, `-` / `[` browse upward and collapse back to the compact
first item when already on the first row, raw-buffer-only composition preserves
the physical `=` / `-` / `[` / `]` input while rendering Chinese/full-width
punctuation in the UI, and confirming a candidate commits the current layer
only.

The candidate panel is not a second pinyin input field. In candidate mode, raw
pinyin and its insertion caret belong to host marked text. The panel renders
the candidate matrix only. Raw-buffer-only composition is the exception where
the panel may render the raw buffer because there is no candidate matrix.

Raw cursor editing follows macOS-style text editing while staying inside the IME
composition:

- `Option+Left/Right` moves by pinyin block
- `Command+Left/Right` moves to the composition edges
- `Option+Backspace` deletes one pinyin block
- `Command+Backspace` deletes to the raw cursor start
- plain `Left/Right` browse candidates only when the raw cursor is at the end;
  otherwise they move the raw cursor by character

## Rationale

This interaction is now part of the product definition rather than a future polish step.

The stock candidate path can show a selected candidate plus annotation, but it does not naturally support:

- a bilingual matrix for the whole current page while keeping macOS-style candidate browsing
- a maximum page size of `25` without forcing empty cells or rows when fewer candidates are available
- persistent active-layer highlighting
- English-layer selection and commit behavior
- raw-buffer-only fallback rendering without turning the candidate matrix into
  a duplicate pinyin editor

A custom panel keeps the interaction model explicit while still allowing the Chinese engine and translation provider to remain modular.

The panel is also now coupled to a thin host bridge:

- `IMKInputController` owns event routing, marked-text synchronization, and anchor resolution
- session state stays free of `NSTextInputClient` and AppKit window geometry
- anchor resolution prefers the client's line-height rectangle
- missing fresh geometry may reuse the current session's last valid anchor, but never falls back to mouse position

## Current Status Note

This ADR is still active. The custom panel is the supported candidate UI path
in the dev lane. The current local host smoke baseline explicitly verifies
panel popup, browsing, commit, and safe-boundary settings refresh. Raw cursor
editing is currently covered by package tests and remains part of the next
real-host smoke expansion set.
