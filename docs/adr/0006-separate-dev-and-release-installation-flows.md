# ADR 0006: Separate Dev And Release Installation Flows

## Status

Accepted

## Decision

The repository now uses two distinct installation lanes for the macOS input method:

- `BilineIME Dev`
  - bundle id: `io.github.xixiphus.inputmethod.BilineIME.dev`
  - local dev install location: `~/Library/Input Methods`
  - tester pkg install location: `/Library/Input Methods`
  - purpose: developer iteration, debugger attach flow, and prerelease tester distribution
- `BilineIME`
  - bundle id: `io.github.xixiphus.inputmethod.BilineIME`
  - purpose: reserved release target with packaging temporarily paused

The application bundle remains a single-process InputMethodKit app, but both lanes now use the sandbox entitlement plus the `mach-register.global-name` exception for the IMK connection name.

The installation workflow also changes:

- local dev reinstall copies only the dev bundle into the user Input Methods directory
- tester packaging may ship an unsigned `.pkg` that installs `BilineIMEDev.app` into `/Library/Input Methods` and `BilineSettingsDev.app` into `/Applications`
- release packaging is paused and has no supported Make or script entrypoint
- neither flow launches the input method app directly with `open`
- first install and metadata changes are treated as relogin-required operations

## Rationale

The earlier packaging path mixed three unstable behaviors:

- debug bundles copied into `/Library/Input Methods`
- release-like installs reusing the same bundle id as local debug builds
- manual app launching instead of letting `imklaunchagent` activate the input method

That combination made `Launch Services`, `HIToolbox`, and `TIS` state harder to reason about and increased the chance of grey or disappearing menu items.

Separating dev and release lanes makes the system state more legible:

- dev installs no longer pollute the release input source
- release packaging can be restored later without affecting the dev lane bundle id
- diagnostics can target a single bundle id at a time

## Consequences

- `make build-ime` and `make install-ime` now target `BilineIME Dev`
- `make dev-pkg` emits unsigned tester packages on the dev lane without enabling the release lane
- release packaging is paused; no Make workflow is supported
- metadata changes such as bundle id, mode list, or display name should be followed by log out / log in before re-adding the input source
- code-only changes usually require reinstall plus re-selection, not a full relogin
