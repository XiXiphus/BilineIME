# ADR 0008: Unified Dev App Lifecycle

## Status

Accepted.

## Context

BilineIME now has two dev apps:

- `BilineIMEDev.app` in `~/Library/Input Methods`
- `BilineSettingsDev.app` in `~/Applications`

The old lifecycle was split across IME install scripts, Settings install
scripts, diagnose scripts, reset scripts, and repair scripts. That made it too
easy to rebuild one app while continuing to run the other from an old stable
path or a DerivedData Launch Services record.

## Decision

`bilinectl` is the source of truth for dev lifecycle operations.

- Level 1 reinstalls both dev apps, refreshes Launch Services and text-input
  agents, and preserves credentials, Rime userdb, and defaults.
- Level 2 removes dev app bundles and local input-method state, clears
  `IntlDataCache`, and requires reboot before a Level 1 reinstall.
- Level 3 performs Level 2 plus a Launch Services database reset and requires
  reboot before a Level 1 reinstall.

Make targets are thin wrappers around `bilinectl`; shell scripts remain only
for low-level build, runtime embedding, and read-only diagnostics.

Real-host validation is manual-only. Codex and scripts must not switch input
sources, focus host apps, inject keys, browse candidates, or commit text.

## Consequences

- `make install-ime` runs the Level 1 dev lifecycle reinstall for both dev apps.
- `make repair-ime` prints a dry-run plan unless `CONFIRM=1` is provided.
- Settings App reads the same lifecycle snapshot used by the CLI and shows
  stable-path and repair recommendation state.
- Release packaging is paused and has no supported Make or script entrypoint.
