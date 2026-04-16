# ADR 0001: Keep InputMethodKit Outside Core Modules

## Status

Accepted

## Decision

The repository keeps all platform integration inside `App/` and all reusable composition and preview logic inside Swift Package targets under `Sources/`.

## Rationale

Mode 1 must stay replaceable at the engine and preview-provider layers. If `IMKInputController` owns composition state directly, the future `librime` adapter and preview provider work will be harder to test and replace.
