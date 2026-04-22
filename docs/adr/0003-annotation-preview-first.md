# ADR 0003: Retire Annotation-First Mode 1

## Status

Superseded by ADR 0005

## Decision

The original prototype decision was to validate Mode 1 through `IMKCandidates` plus annotation before building custom UI.

## Rationale

That decision no longer matches the current product definition.

Mode 1 now requires:

- a two-line bilingual row for every visible candidate
- `Shift+Tab`-based layer switching between Chinese and English on the current highlighted candidate cell
- committing either layer for the selected candidate

Those interaction requirements exceed what stock annotation can express cleanly, so the annotation-first path is retained only as historical context.

## Current Status Note

This ADR remains superseded. The current dev lane and local host smoke baseline
assume the custom candidate panel is the active UI path; stock annotation is no
longer part of the supported product direction.
