# ADR 0003: Retire Annotation-First Mode 1

## Status

Superseded by ADR 0005

## Decision

The original prototype decision was to validate Mode 1 through `IMKCandidates` plus annotation before building custom UI.

## Rationale

That decision no longer matches the current product definition.

Mode 1 now requires:

- a two-line bilingual row for every visible candidate
- `Shift`-based layer switching between Chinese and English
- committing either layer for the selected candidate

Those interaction requirements exceed what stock annotation can express cleanly, so the annotation-first path is retained only as historical context.
