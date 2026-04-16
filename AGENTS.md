# BilineIME Agent Guide

## Repo layout

- `App/` contains the InputMethodKit shell, app lifecycle glue, and packaging assets.
- `Sources/` contains Swift Package targets with pure domain and preview logic.
- `Tests/` contains Swift Package unit tests.
- `docs/adr/` stores architecture decisions.
- `docs/standards/` stores durable engineering conventions and acceptance rules.
- `scripts/` contains developer automation for project generation, install, and packaging.

## Commands

- `make bootstrap` installs developer tools used by this repo.
- `make project` regenerates `BilineIME.xcodeproj` from `project.yml`.
- `make test` runs Swift Package unit tests.
- `make build-ime` builds the macOS input method app with Xcode.
- `make install-ime` builds and installs the app into `/Library/Input Methods`.
- `make package-internal` builds an unsigned internal package for trusted testers.
- `make verify` runs the package tests and Xcode build together.

## Architecture rules

- Keep `InputMethodKit`, `AppKit`, and packaging concerns inside `App/`.
- Keep composition state, candidate models, preview coordination, and provider protocols inside Swift Package targets.
- Do not introduce catch-all `Utils`, `Helpers`, or `Manager` files.
- Prefer explicit roles such as `Session`, `Coordinator`, `Store`, `Provider`, and `Adapter`.
- Add or update an ADR before changing core module boundaries, engine strategy, packaging strategy, or third-party dependency direction.
- Do not commit generated `.xcodeproj` contents or XcodeGen-generated support plists; commit `project.yml` and the source inputs instead.

## Third-party and licensing

- Record every external dependency, tooling integration, or adapted sample in `THIRD_PARTY_NOTICES.md`.
- GPL projects remain reference-only while this repository stays MIT licensed.
- Preserve upstream notice requirements when adapting permissively licensed code or workflows.

## Done means

- Package tests pass.
- The Xcode project regenerates cleanly from `project.yml`.
- The IME app target builds on Xcode without local manual edits.
- New behavior is documented if it changes developer workflow, packaging, or architecture.
