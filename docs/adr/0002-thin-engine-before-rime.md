# ADR 0002: Start With A Thin Local Engine Before librime

## Status

Accepted

## Decision

The first demo uses a fixture-driven Swift implementation behind `CandidateEngineSession`. A future `librime` adapter will conform to the same protocol in a separate target.

## Rationale

This keeps the first iteration focused on session state, candidate flow, and preview integration instead of C++ build and packaging complexity.

## Current Status Note

This ADR should now be read as historical bootstrap context. The app runtime has
since moved to a Rime-backed engine, while fixture-driven and dictionary-backed
engines remain only for tests, diagnostics, and deterministic examples.
