# BilineIME

BilineIME is a macOS Chinese input method focused on **Chinese-first typing with
optional bilingual preview**.

The project is currently a **developer / tester lane**, not a release-stable
product. The core typing model, dev lifecycle, tester packaging, and local host
smoke baseline are all real and actively maintained; formal release packaging
and notarized distribution are still paused.

![BilineIME running in TextEdit](docs/assets/readme-mode1-textedit.png)

## Product model

BilineIME has one primary interaction model:

- Type Chinese pinyin.
- Browse Chinese candidates.
- Optionally preview English for the currently visible Chinese candidates.
- Commit either the Chinese candidate or its ready English preview.

The boundary is strict:

- Chinese candidate generation, ranking, paging, and commit state remain the
  source of truth.
- English preview is an overlay on top of Chinese IME behavior, never a
  replacement for it.
- Turning off bilingual capability makes the IME behave like a plain
  Chinese-first pinyin input method.

## What ships today

- Native macOS `InputMethodKit` input method app (`BilineIMEDev.app`).
- Native SwiftUI Settings app with four sections:
  `Translation`, `Input Settings`, `Appearance`, and `Status`.
- Rime-backed Chinese candidate engine with separate simplified and traditional
  schemas and user dictionaries.
- Custom AppKit candidate panel with compact and expanded presentation modes.
- `Shift+Tab` layer switching between Chinese commit and ready English commit.
- A “双语能力” toggle in Settings that disables English candidates and English
  commit behavior for a pure-pinyin workflow.
- Broker-mediated Settings/IME coordination through `BilineBrokerDev`,
  `BilineCommunicationHub`, shared configuration storage, and shared credential
  storage.
- Alibaba Cloud translation support behind user-managed credentials stored in a
  shared Keychain-backed vault.
- Unified dev lifecycle through `bilinectl`, with Make targets as thin wrappers.
- Local real-host smoke harness for `TextEdit`, with baseline scenarios:
  `candidate-popup`, `browse`, `commit`, `settings-refresh`, and `full`.
- Unsigned tester packages for install, safe uninstall, and deep clean.

## Current status

The current state is best described as:

- **Core model is established:** Chinese-first bilingual preview is the fixed
  product boundary.
- **Dev lane is usable:** install, remove, reset, diagnose, tester packaging,
  broker coordination, and local host smoke all exist as supported workflows.
- **Host smoke baseline is green:** the current `full` local harness covers
  candidate popup, browsing, commit, and safe-boundary settings refresh in one
  `TextEdit` session.
- **Release lane is intentionally paused:** the reserved `BilineIME` release
  target remains in project configuration, but there is no supported notarized
  packaging workflow yet.

## Quick start

Full setup and machine handoff live in
[`docs/development-handoff.md`](docs/development-handoff.md). The shortest path
for a developer machine is:

```bash
make bootstrap
make project
make test
make build-ime
make install-ime
```

Useful day-to-day commands:

```bash
make build-settings
make build-broker
make remove-ime
make reset-ime
make prepare-release-env
make diagnose-ime
make dev-pkg
make verify
```

Notes:

- Build products go to `~/Library/Caches/BilineIME/DerivedData`.
- `BilineIME.xcodeproj` is generated from `project.yml`; regenerate it locally
  instead of committing it.
- Do not launch the IME app directly with `open`; let `imklaunchagent` own
  activation.

## Install, enrollment, smoke

The repository treats host verification as **three separate phases**:

1. **Install bundles**
2. **Manual source enrollment** when macOS requires it
3. **Source-ready host smoke**

Use these entrypoints:

```bash
make install-ime
make smoke-ime-host-check
make smoke-ime-host-prepare
make smoke-ime-host SMOKE_SCENARIO=full
```

What each step means:

- `make install-ime` installs the dev IME, Settings app, broker, and local
  diagnostics state. It does **not** force-enable the input source.
- `make smoke-ime-host-check` reports readiness as one of:
  `bundle-missing`, `source-missing`, `source-disabled`,
  `source-not-selectable`, `source-not-selected`, or `ready`.
- `make smoke-ime-host-prepare` only opens System Settings → Keyboard → Input
  Sources and prints remediation. It never clicks `Allow` or enables the source
  for the user.
- `make smoke-ime-host` is the only supported automated real-host entrypoint.
  It is local-only, never a CI gate, and drives exactly one `TextEdit` session.

The default real-host flow is still manual: the user selects `BilineIME Dev`,
focuses the host, types, browses, commits, and reports the result. The harness
exists for explicit local host smoke, not for ordinary CI.

## Storage and coordination

The IME and Settings app no longer behave like two separate processes manually
editing unrelated files.

The current coordination model is:

- `BilineBrokerDev` is the user-scoped coordination process.
- `BilineCommunicationHub` is the shared client façade used by both the IME and
  the Settings app.
- Shared configuration is persisted through the broker-backed configuration
  store.
- Alibaba credentials are persisted through a shared Keychain-backed vault,
  with legacy file fallback retained only for migration / recovery paths.
- The IME applies safe settings refreshes at explicit lifecycle boundaries
  rather than mutating engine-sensitive state mid-composition.

This means the canonical source of truth for runtime configuration is the
broker-mediated shared configuration snapshot, not ad hoc app-local defaults.

## Tester packages

For prerelease tester distribution:

```bash
make dev-pkg
```

This produces three unsigned packages in `build/dist`:

- `BilineIMEDev-<version>.pkg`
- `BilineIMEDev-Uninstall-<version>.pkg`
- `BilineIMEDev-DeepClean-<version>.pkg`

The tester lane installs:

- `BilineIMEDev.app`
- `BilineSettingsDev.app`
- `BilineBrokerDev`
- the broker LaunchAgent

into the appropriate system paths for trusted local testing. Gatekeeper will
still block first launch of these unsigned packages; see
[`docs/development-handoff.md`](docs/development-handoff.md) for the exact
install guidance.

## Documentation map

If you are new to the repo, start here:

- [`docs/development-handoff.md`](docs/development-handoff.md): new machine,
  lifecycle, smoke, credentials, failure recovery
- [`docs/architecture.md`](docs/architecture.md): product model, module
  boundaries, broker/storage architecture, verification model
- [`docs/standards/engineering.md`](docs/standards/engineering.md): coding,
  testing, and host-smoke engineering rules
- [`docs/standards/acceptance.md`](docs/standards/acceptance.md): delivery and
  verification checklist
- [`docs/ime-engine-bugs.md`](docs/ime-engine-bugs.md): active risks and known
  bottlenecks
- [`docs/adr/`](docs/adr/): architectural decision records

## Roadmap

### Now

- Keep simplified and traditional Rime schemas stable.
- Keep Chinese candidate quality and consumed-span behavior correct.
- Keep the broker-backed Settings/IME coordination path boring and reliable.
- Keep the local host smoke baseline green for the current `full` scenario.
- Keep the unsigned tester lane usable for prerelease installs and clean
  removals.

### Next

- Expand host smoke beyond the current baseline into harder scenarios:
  punctuation, raw-buffer behavior, editing keys, `Shift+Tab` persistence,
  phrase/tail commits, and mixed Chinese/Latin stress cases.
- Turn the current engine-side “future toggles” into real behavior where
  appropriate, especially smart spelling and emoji candidates.
- Tighten docs and diagnostics around source enrollment edge cases after install,
  reset, and deep clean.

### Later

- Restore a supported release packaging lane for the reserved `BilineIME`
  target.
- Add broader host coverage beyond `TextEdit` once the baseline lane stays
  stable.
- Revisit richer release/distribution UX only after the current dev/tester lane
  no longer needs frequent recovery guidance.

## Repository policy

BilineIME is GPL-3.0 licensed. Runtime dependencies, bundled data, and major
architecture decisions should stay documented and attributable. Generated build
artifacts and local project files remain untracked.
