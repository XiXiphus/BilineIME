# ADR 0001: Keep InputMethodKit Outside Core Modules

## Status

Accepted

## Decision

The repository keeps all platform integration inside `App/` and all reusable composition and preview logic inside Swift Package targets under `Sources/`.

## Rationale

Mode 1 must stay replaceable at the engine and preview-provider layers. If `IMKInputController` owns composition state directly, the future `librime` adapter and preview provider work will be harder to test and replace.

## Current Status Note

This ADR is still active. The current repo layout continues to follow it:
host-facing integration stays in `App/`, reusable logic stays in Swift Package
targets under `Sources/`, and CI-safe tests stay in `Tests/` rather than mixing
real-host automation into package test targets.

Recent raw-cursor editing work follows the same boundary: `BilineSession` owns
raw cursor state and editing behavior, `BilineCore` owns shared pinyin
segmentation, and `App/` only adapts those snapshots into marked text and the
candidate panel.
