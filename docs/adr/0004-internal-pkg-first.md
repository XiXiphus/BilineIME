# ADR 0004: Internal Package Before Public Distribution

## Status

Superseded by ADR 0006

## Decision

The first deliverable supported local developer installation and unsigned internal `.pkg` generation for trusted testers. That decision has now been replaced by a split dev/release installation model.

## Rationale

This was the smallest packaging path that still allowed real-user feedback without blocking on Apple distribution setup, but it mixed debug installs and release-like installs too aggressively for stable TIS registration.
