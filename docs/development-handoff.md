# BilineIME Development Handoff

This document is the operational handoff for continuing BilineIME on a new
machine or after a long pause. It is intentionally biased toward the **current
dev lane**, not a hypothetical future release workflow.

It does not contain real secrets.

## 1. Current mental model

Before touching the machine, keep these boundaries in mind:

- `BilineIMEDev.app` is the active IME lane for development and trusted tester
  distribution.
- `BilineSettingsDev.app` is the companion Settings app.
- `BilineBrokerDev` is the user-scoped coordination process that mediates
  configuration, diagnostics, and credential access between the Settings app and
  the IME.
- `bilinectl` is the source of truth for lifecycle operations and local host
  smoke.
- `Tests/` is for CI-safe Swift Package tests. Real-host smoke lives under
  `Sources/bilinectl/` because it automates macOS input-source, Accessibility,
  TextEdit, and telemetry flows that do not belong in `swift test`.

The current product boundary is still:

- Chinese composition is the source of truth.
- English preview is optional and must never own ranking or paging.
- Raw pinyin cursor editing belongs to the IME composition state and is rendered
  through host marked text.
- Turning bilingual capability off yields a pure pinyin workflow.
- Formal release packaging is paused.

## 2. Machine prerequisites

Install the base toolchain first:

```bash
xcode-select --install
brew install xcodegen swift-format cmake boost
```

Open Xcode once and sign in with the Apple developer account used for local IME
signing. If auto-detection fails later, pass the team explicitly:

```bash
export BILINE_DEV_TEAM_ID='<APPLE_TEAM_ID>'
```

Clone the repo:

```bash
git clone <REMOTE_URL> BilineIME
cd BilineIME
```

`BilineIME.xcodeproj` is generated from `project.yml`. Regenerate it locally;
do not treat it as a tracked source artifact.

## 3. First local bring-up

Use the repo entrypoints only:

```bash
make bootstrap
make project
make test
make build-ime
make build-settings
make build-broker
make install-ime
```

Do not:

- launch the IME app directly with `open`
- script macOS permission dialogs
- assume install implies source enrollment

A healthy user-scope dev install should leave these paths present:

```text
~/Library/Input Methods/BilineIMEDev.app
~/Applications/BilineSettingsDev.app
~/Library/Application Support/BilineIME/Broker/BilineBrokerDev
~/Library/LaunchAgents/io.github.xixiphus.BilineIME.dev.broker.plist
```

Useful commands during bring-up:

```bash
make diagnose-ime
make remove-ime
make reset-ime
make prepare-release-env
```

`make reset-ime` is a dry-run plan unless `CONFIRM=1` is provided. Use
`RESET_DEPTH=launch-services-reset CONFIRM=1` only as a last resort because it
resets Launch Services and requires a reboot.

## 4. Install, source enrollment, host smoke

Treat these as **three separate phases**:

1. install bundles
2. complete source enrollment if macOS still needs it
3. run source-ready host smoke

### Install

```bash
make install-ime
```

This installs the dev IME, Settings app, broker, and lifecycle metadata. It
does **not** guarantee the source is already enabled or selected.

### Check readiness

```bash
make smoke-ime-host-check
# or
bilinectl smoke-host dev --check
```

Readiness is classified as one of:

- `bundle-missing`
- `source-missing`
- `source-disabled`
- `source-not-selectable`
- `source-not-selected`
- `ready`

### Open the right System Settings page

```bash
make smoke-ime-host-prepare
# or
bilinectl smoke-host dev --prepare
```

This helper only:

- checks readiness
- opens System Settings → Keyboard → Input Sources
- prints remediation
- re-checks readiness

It does **not** click `Allow`, enable the source, or step through the system UI
for the user.

### Run local host smoke

Once readiness is `ready` or `source-not-selected`, use the explicit local
harness:

```bash
make smoke-ime-host SMOKE_SCENARIO=candidate-popup
make smoke-ime-host SMOKE_SCENARIO=browse
make smoke-ime-host SMOKE_SCENARIO=commit
make smoke-ime-host SMOKE_SCENARIO=settings-refresh
make smoke-ime-host SMOKE_SCENARIO=full
```

Current local baseline:

- the `full` scenario covers
  `candidate-popup`, `browse`, `commit`, and `settings-refresh`
- the harness drives exactly one `TextEdit` session
- the harness may temporarily switch the current input source and restore it
  afterwards
- the harness is local-only and must never become a CI gate

Outside an explicit request to run the harness, the default real-host flow is
still manual: the user selects `BilineIME Dev`, focuses TextEdit, types,
browses, commits, and reports the result.

## 5. Tests vs host smoke

Use the right verification layer:

### CI-safe / package layer

```bash
make test
swift test --filter '<FocusedTests>'
```

This is for deterministic logic:

- routing
- session state
- raw pinyin cursor movement and deletion
- Rime integration contracts
- settings serialization
- lifecycle planning

### IME-facing code path

```bash
swift test --filter 'InputControllerEventRouterTests|BilingualInputSessionTests|PinyinTokenizerTests|RimeCandidateEngineTests|ProcessRunnerTests'
make build-ime
make install-ime
```

Then either:

- stop and do manual TextEdit verification, or
- explicitly run `make smoke-ime-host`

Do not claim an IME-facing change is verified if only package tests passed.

## 6. Broker, settings, and shared storage

The current communication model is broker-mediated.

Canonical path:

- Settings app writes configuration through `BilineCommunicationHub`
- the broker persists the shared configuration snapshot
- the IME reloads configuration at safe boundaries
- diagnostics and lifecycle tools read the same shared state model

Storage model:

- configuration lives in the shared configuration store used by the dev lane
- Alibaba credentials live in a shared Keychain-backed vault
- a legacy file store still exists only as fallback / migration support

This means older docs that describe “the Settings app writes the canonical
credential record directly to a single JSON file” are no longer accurate.

The Status page in the Settings app is now the fastest human-readable place to
check:

- IME install state
- broker install / runtime state
- LaunchAgent presence
- current input source
- lifecycle recommendation

## 7. Translation credentials

The production translation path is still Alibaba Cloud Machine Translation.

Provider defaults:

- region: `cn-hangzhou`
- endpoint: `https://mt.cn-hangzhou.aliyuncs.com`
- source language: `zh`
- target language: `en`
- transport: batch translation through the broker-mediated settings path

For development:

- prefer a dedicated RAM user
- do not pass secrets as command-line arguments
- do not paste secrets into docs, commits, or screenshots

Normal local workflow:

```bash
make build-settings
make install-ime
open "$HOME/Applications/BilineSettingsDev.app"
```

Non-secret defaults are still part of the shared configuration snapshot. Secret
material is expected to land in the shared Keychain-backed vault.

Check status without printing secrets:

```bash
make aliyun-credentials-status
```

Live API tests remain opt-in and still use environment variables:

```bash
ALIBABA_CLOUD_ACCESS_KEY_ID='<ACCESS_KEY_ID>' \
ALIBABA_CLOUD_ACCESS_KEY_SECRET='<ACCESS_KEY_SECRET>' \
swift test --filter AlibabaMachineTranslationLiveTests
```

Those environment variables are for live tests only; they are **not** the
runtime credential path used by the product.

## 8. Tester packages and release lane

The supported tester distribution path is:

```bash
make dev-pkg
```

It produces three unsigned packages in `build/dist`:

- install
- safe uninstall
- deep clean

The tester lane may install:

- `BilineIMEDev.app`
- `BilineSettingsDev.app`
- `BilineBrokerDev`
- the broker LaunchAgent

at system paths.

Release packaging status:

- the reserved `BilineIME` release target still exists
- notarized / supported release packaging is paused
- there is no approved Make or script workflow for formal release distribution

## 9. Common failure modes

### Source missing or stale

```bash
make diagnose-ime
make reset-ime
make smoke-ime-host-check
```

If this follows a first install or a metadata change, log out and back in once
before assuming the install is broken.

### IME exists but no candidate panel appears

- confirm the host app is actually using `BilineIME Dev`
- use the local harness or ask the user for host text, screenshots, telemetry,
  and system logs
- check the broker and LaunchAgent status in the Settings app Status page

### Raw cursor or editing keys behave incorrectly

- confirm the host still has marked text, not committed host text
- check whether the raw cursor is at the end of the pinyin composition:
  - plain `Left/Right` browse candidates only at the end
  - plain `Left/Right` move the raw cursor when it is in the middle
- verify modified editing stays inside composition:
  - `Option+Left/Right` moves by pinyin block
  - `Command+Left/Right` jumps to start/end
  - `Option+Backspace` deletes one pinyin block
  - `Command+Backspace` deletes to raw cursor start
- do not diagnose this by injecting keys automatically unless the user has
  explicitly requested the local host harness

### Install appears to hang during build

The lifecycle runner drains subprocess stdout and stderr while waiting. If a
future install hangs during a verbose `xcodebuild`, inspect for a runner
regression before assuming the app build itself is broken.

### Settings changes do not appear to apply

- distinguish “saved to shared configuration” from “applied at a safe boundary”
- use the `settings-refresh` host smoke scenario when the question is about
  runtime propagation, not just persistence

### Translation always unavailable

- confirm the provider is set to Aliyun
- confirm credentials are complete in the shared vault status
- confirm network entitlement and RAM permissions

### Cleanup/build noise

- `xattr` or metadata cleanup warnings are only actionable when they actually
  break build, signing, install, or runtime verification

## 10. Current boundary you should preserve

Keep these decisions intact unless you are intentionally changing architecture:

- Chinese candidate generation, ranking, paging, and commit state belong to
  Rime/session logic
- raw pinyin cursor editing belongs to session state and marked text, not host
  document text
- English remains a preview / alternate commit layer, not the source of truth
- translation must not block Chinese typing, browsing, or commit
- broker coordination should stay the single operational path between Settings
  and the IME for shared runtime state
- CI-safe tests and real-host smoke should remain separate verification layers
