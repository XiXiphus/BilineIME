# ADR 0008: Unified Dev App Lifecycle

## Status

Accepted.

## Context

BilineIME now has two dev apps:

- `BilineIMEDev.app` in `~/Library/Input Methods`
- `BilineSettingsDev.app` in `~/Applications`

Trusted tester packaging may also place those same dev apps at system paths:

- `BilineIMEDev.app` in `/Library/Input Methods`
- `BilineSettingsDev.app` in `/Applications`

The old lifecycle was split across IME install scripts, Settings install
scripts, diagnose scripts, reset scripts, and repair scripts. That made it too
easy to rebuild one app while continuing to run the other from an old stable
path or a DerivedData Launch Services record.

## Decision

`bilinectl` is the source of truth for dev lifecycle operations.

- `install` builds and installs both dev apps, refreshes Launch Services and
  text-input agents, and preserves credentials, Rime userdb, and defaults.
- `remove` removes dev app bundles and can either preserve or purge Biline-local
  data.
- `reset` handles system-side recovery depth, from local refresh through
  `IntlDataCache` cleanup to full Launch Services database reset.
- `prepare-release` removes dev installs and purges Biline-local data before a
  future release-style install.

Make targets are thin wrappers around `bilinectl`; shell scripts remain only
for low-level build, runtime embedding, and read-only diagnostics.

Real-host validation is layered. The default flow is manual TextEdit smoke. The
only automated host path is the explicit local harness
`bilinectl smoke-host dev --confirm` / `make smoke-ime-host`; it is local-only,
must export telemetry/artifacts, and must not become a CI gate.

## Consequences

- `make install-ime` runs the intent-first install flow for both dev apps.
- `make reset-ime` prints a dry-run reset plan unless `CONFIRM=1` is provided.
- Settings App reads the same lifecycle snapshot used by the CLI and shows
  stable-path and action recommendation state.
- `make dev-pkg` emits unsigned tester packages for install, safe uninstall, and
  deep clean on the dev lane.
- Release packaging is paused and has no supported notarized Make or script
  entrypoint.
