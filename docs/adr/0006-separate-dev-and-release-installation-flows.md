# ADR 0006: Separate Dev And Release Installation Flows

## Status

Accepted

## Decision

The repository now uses two distinct installation lanes for the macOS input method:

- `BilineIME Dev`
  - bundle id: `io.github.xixiphus.inputmethod.BilineIME.dev`
  - install location: `~/Library/Input Methods`
  - purpose: developer iteration and debugger attach flow
- `BilineIME`
  - bundle id: `io.github.xixiphus.inputmethod.BilineIME`
  - install location: `/Library/Input Methods`
  - purpose: release-facing installation through an installer package

The application bundle remains a single-process InputMethodKit app, but both lanes now use the sandbox entitlement plus the `mach-register.global-name` exception for the IMK connection name.

The installation workflow also changes:

- the dev installer script copies only the dev bundle into the user Input Methods directory
- the release package installs only the release bundle into the system Input Methods directory
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
- release installs can be packaged and documented like a real input method product
- diagnostics can target a single bundle id at a time

## Consequences

- `make build-ime` and `make install-ime` now target `BilineIME Dev`
- `make package-release` builds the release installer package for `BilineIME`
- metadata changes such as bundle id, mode list, or display name should be followed by log out / log in before re-adding the input source
- code-only changes usually require reinstall plus re-selection, not a full relogin
