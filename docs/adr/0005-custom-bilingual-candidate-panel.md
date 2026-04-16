# ADR 0005: Use A Custom Bilingual Candidate Panel For Mode 1

## Status

Accepted

## Decision

Mode 1 uses a custom AppKit candidate panel instead of stock `IMKCandidates` annotation.

Each visible candidate is rendered as a vertically stacked pair:

- upper line: Chinese candidate
- lower line: English preview

`Shift` toggles the active layer for the selected candidate. Confirming a candidate commits the current layer only.

## Rationale

This interaction is now part of the product definition rather than a future polish step.

The stock candidate path can show a selected candidate plus annotation, but it does not naturally support:

- two-line rendering for every visible candidate
- persistent active-layer highlighting
- English-layer selection and commit behavior

A custom panel keeps the interaction model explicit while still allowing the Chinese engine and translation provider to remain modular.
