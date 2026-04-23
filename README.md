<div align="center">
  <h1>BilineIME</h1>

  <p>
    <strong>Type Chinese. Glance at English. Stay in flow.</strong><br>
  </p>

  <p>
    <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-111111?style=for-the-badge&logo=apple&logoColor=white">
    <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-FA7343?style=for-the-badge&logo=swift&logoColor=white">
    <img alt="InputMethodKit" src="https://img.shields.io/badge/InputMethodKit-native-0A84FF?style=for-the-badge">
    <img alt="Rime" src="https://img.shields.io/badge/Rime-backed-33C481?style=for-the-badge">
    <img alt="GPL-3.0" src="https://img.shields.io/badge/License-GPL--3.0-6E56CF?style=for-the-badge">
  </p>
</div>

<table>
  <tr>
    <td><strong>Core model</strong></td>
    <td>Type pinyin, browse Chinese candidates, preview English only when it is ready.</td>
  </tr>
  <tr>
    <td><strong>Runtime lane</strong></td>
    <td>Developer/tester lane with <code>BilineIMEDev.app</code>, Settings, broker, and local host smoke.</td>
  </tr>
  <tr>
    <td><strong>Current boundary</strong></td>
    <td>Chinese candidate ranking, paging, raw cursor editing, and commit state remain source of truth.</td>
  </tr>
</table>

## Product Model

BilineIME has one primary interaction model:

1. Type Chinese pinyin.
2. Browse Chinese candidates.
3. Optionally inspect English preview for visible Chinese candidates.
4. Commit either the Chinese candidate or its ready English preview.

The boundary is strict:

- Chinese candidate generation, ranking, paging, and commit state remain the
  source of truth.
- English preview is an overlay, not a separate input mode.
- Turning bilingual capability off yields a plain Chinese-first pinyin workflow.
- Translation preview must never block Chinese typing, browsing, raw cursor
  editing, or commit.

## Interaction Highlights

<table>
  <tr>
    <th>Workflow</th>
    <th>Behavior</th>
  </tr>
  <tr>
    <td>Candidate browsing</td>
    <td><kbd>=</kbd>/<kbd>]</kbd> expand and move down; <kbd>-</kbd>/<kbd>[</kbd> move up and collapse at the top.</td>
  </tr>
  <tr>
    <td>Layer switching</td>
    <td><kbd>Shift</kbd>+<kbd>Tab</kbd> switches between Chinese commit and ready English commit for the highlighted cell.</td>
  </tr>
  <tr>
    <td>Raw pinyin cursor</td>
    <td><kbd>Option</kbd>+<kbd>←</kbd>/<kbd>→</kbd> moves by pinyin block; <kbd>Command</kbd>+<kbd>←</kbd>/<kbd>→</kbd> jumps to start/end.</td>
  </tr>
  <tr>
    <td>Composition deletion</td>
    <td><kbd>Option</kbd>+<kbd>Backspace</kbd> deletes one pinyin block; <kbd>Command</kbd>+<kbd>Backspace</kbd> deletes to the raw cursor start.</td>
  </tr>
  <tr>
    <td>Candidate panel</td>
    <td>The custom AppKit panel shows only candidates in candidate mode; raw-buffer-only composition keeps a compact raw buffer fallback.</td>
  </tr>
</table>

Plain <kbd>←</kbd>/<kbd>→</kbd> only browse candidates when the raw pinyin cursor
is at the end of the composition. If the cursor is in the middle, those keys
continue moving the raw pinyin cursor inside the marked text instead of touching
the host document.

## What Ships Today

- Native macOS `InputMethodKit` input method app: `BilineIMEDev.app`.
- SwiftUI Settings app with `Translation`, `Input Settings`, `Appearance`, and
  `Status`.
- Rime-backed simplified and traditional schemas with user dictionaries.
- Rime language-model support through `librime-octagram`, with bundled grammar
  model assets in the dev/tester package.
- Custom AppKit bilingual candidate panel with compact and expanded
  presentation.
- Inline marked-text preedit with raw pinyin cursor editing.
- Broker-mediated Settings/IME coordination through `BilineBrokerDev`,
  `BilineCommunicationHub`, shared configuration storage, and shared credential
  storage.
- Alibaba Cloud translation behind user-managed shared Keychain credentials.
- Unified dev lifecycle through `bilinectl`, with Make targets as thin wrappers.
- Local real-host smoke harness for `TextEdit`: `candidate-popup`, `browse`,
  `commit`, `settings-refresh`, and `full`.
- Unsigned tester packages for install, safe uninstall, and deep clean.

## Current Status

<table>
  <tr>
    <td><strong>Core model</strong></td>
    <td>Established. Chinese-first bilingual preview is the fixed product boundary.</td>
  </tr>
  <tr>
    <td><strong>Dev lane</strong></td>
    <td>Usable. Install, remove, reset, diagnose, broker coordination, tester packaging, and host smoke are supported workflows.</td>
  </tr>
  <tr>
    <td><strong>Host smoke</strong></td>
    <td>Baseline is green for candidate popup, browsing, commit, and safe-boundary settings refresh. Hard editing cases still need broader real-host coverage.</td>
  </tr>
  <tr>
    <td><strong>Release lane</strong></td>
    <td>Paused. The reserved <code>BilineIME</code> target remains, but notarized release packaging is not currently supported.</td>
  </tr>
</table>

## Quick Start

Full machine handoff lives in
[`docs/development-handoff.md`](docs/development-handoff.md). The shortest dev
path is:

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

## Install, Enrollment, Smoke

The repository treats host verification as three separate phases:

1. Install bundles.
2. Manually enroll the input source if macOS still requires it.
3. Run source-ready host smoke.

Use these entrypoints:

```bash
make install-ime
make smoke-ime-host-check
make smoke-ime-host-prepare
make smoke-ime-host SMOKE_SCENARIO=full
```

What each step means:

- `make install-ime` installs the dev IME, Settings app, broker, and local
  diagnostics state. It does not force-enable the input source.
- `make smoke-ime-host-check` reports readiness as `bundle-missing`,
  `source-missing`, `source-disabled`, `source-not-selectable`,
  `source-not-selected`, or `ready`.
- `make smoke-ime-host-prepare` only opens System Settings and prints
  remediation. It never clicks `Allow` or enables the source for the user.
- `make smoke-ime-host` is the only supported automated real-host entrypoint.
  It is local-only, never a CI gate, and drives exactly one `TextEdit` session.

The default real-host flow is still manual: the user selects `BilineIME Dev`,
focuses the host, types, edits raw pinyin, browses, commits, and reports the
result.

## Storage And Coordination

The IME and Settings app coordinate through the broker:

- `BilineBrokerDev` is the user-scoped coordination process.
- `BilineCommunicationHub` is the shared client facade used by both the IME and
  the Settings app.
- Shared configuration is persisted through the broker-backed configuration
  store.
- Alibaba credentials are persisted through a shared Keychain-backed vault, with
  legacy file fallback retained only for migration/recovery.
- Engine-sensitive settings apply only at safe lifecycle boundaries, not in the
  middle of live composition.

## Tester Packages

For prerelease tester distribution:

```bash
make dev-pkg
```

This produces three unsigned packages in `build/dist`:

- `BilineIMEDev-<version>.pkg`
- `BilineIMEDev-Uninstall-<version>.pkg`
- `BilineIMEDev-DeepClean-<version>.pkg`

The tester lane installs `BilineIMEDev.app`, `BilineSettingsDev.app`,
`BilineBrokerDev`, and the broker LaunchAgent into trusted test locations.
Gatekeeper will still block first launch of unsigned packages; see
[`docs/development-handoff.md`](docs/development-handoff.md) for exact install
guidance.

## Documentation Map

<table>
  <tr>
    <td><a href="docs/development-handoff.md">development handoff</a></td>
    <td>New machine setup, lifecycle, smoke, credentials, failure recovery.</td>
  </tr>
  <tr>
    <td><a href="docs/architecture.md">architecture</a></td>
    <td>Product model, module boundaries, broker/storage, verification model.</td>
  </tr>
  <tr>
    <td><a href="docs/standards/engineering.md">engineering standards</a></td>
    <td>Coding, testing, and host-smoke engineering rules.</td>
  </tr>
  <tr>
    <td><a href="docs/standards/acceptance.md">acceptance checklist</a></td>
    <td>Delivery, behavior, install, and verification checklist.</td>
  </tr>
  <tr>
    <td><a href="docs/ime-engine-bugs.md">IME risks</a></td>
    <td>Known risks, gaps, and next high-value host smoke coverage.</td>
  </tr>
  <tr>
    <td><a href="docs/adr/">ADRs</a></td>
    <td>Architectural decisions and historical context.</td>
  </tr>
</table>

## Roadmap

<details open>
  <summary><strong>Now</strong></summary>

- Keep simplified and traditional Rime schemas stable.
- Keep Chinese candidate quality and consumed-span behavior correct.
- Keep raw pinyin cursor editing reliable in marked text.
- Keep broker-backed Settings/IME coordination boring and predictable.
- Keep the unsigned tester lane usable for prerelease installs and removals.
</details>

<details>
  <summary><strong>Next</strong></summary>

- Expand host smoke beyond the current baseline into punctuation, raw-buffer
  behavior, editing keys, `Shift+Tab` persistence, phrase/tail commits, and
  mixed Chinese/Latin stress cases.
- Turn current engine-side future toggles into real behavior where appropriate,
  especially smart spelling and emoji candidates.
- Tighten docs and diagnostics around source enrollment edge cases after
  install, reset, and deep clean.
</details>

<details>
  <summary><strong>Later</strong></summary>

- Restore a supported release packaging lane for the reserved `BilineIME`
  target.
- Add broader host coverage beyond `TextEdit` once the baseline lane stays
  stable.
- Revisit richer release/distribution UX after the dev/tester lane no longer
  needs frequent recovery guidance.
</details>

## Repository Policy

BilineIME is GPL-3.0 licensed. Runtime dependencies, bundled data, and major
architecture decisions should stay documented and attributable. Generated build
artifacts and local project files remain untracked.
