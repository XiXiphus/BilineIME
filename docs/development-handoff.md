# BilineIME Development Handoff

This document is the new-Mac checklist for continuing BilineIME development.
It intentionally keeps operational steps in one place and does not contain any
real AccessKey, password, or provider secret.

## 1. Machine Prerequisites

Install the base macOS developer toolchain first:

```bash
xcode-select --install
brew install xcodegen swift-format cmake boost
```

Open Xcode once and sign in with the Apple developer account that can sign the
local IME build. If auto-detection fails later, pass the team explicitly:

```bash
export BILINE_DEV_TEAM_ID='<APPLE_TEAM_ID>'
```

Clone the remote repository and enter the workspace:

```bash
git clone <REMOTE_URL> BilineIME
cd BilineIME
```

Generated files such as `BilineIME.xcodeproj` are local artifacts. Regenerate
them instead of committing them.

## 2. First Local Build

Use the repo entrypoints only:

```bash
make bootstrap
make project
make test
make build-ime
make install-ime
```

Important constraints:

- Dev build installs to `~/Library/Input Methods/BilineIMEDev.app`.
- Do not launch the IME app directly with `open`.
- Do not script System Settings permission dialogs. Click macOS prompts manually.
- After install, manually add/select `BilineIME Dev` in the target host app.

If the input source does not appear or looks stale:

```bash
make diagnose-ime
make repair-ime
```

`make repair-ime` is a dry-run plan by default. Use `make repair-ime CONFIRM=1`
only when ready to execute Level 2 repair, and use
`make repair-ime REPAIR_LEVEL=3 CONFIRM=1` only as a last resort because it
resets Launch Services state and requires a reboot.

## 3. Rime Runtime Notes

The app runtime is Rime-only. The dictionary engine remains for tests and
diagnostics, not as an app fallback.

Build scripts embed `librime` and its dylib dependency closure into the app
bundle, rewrite install names to `@loader_path`, then re-sign nested dylibs and
the main app. Homebrew can be a build source, but the installed IME must not
depend on `/opt/homebrew/...` dylibs at runtime.

Useful checks:

```bash
APP="$HOME/Library/Input Methods/BilineIMEDev.app"
codesign --verify --deep --strict "$APP"
codesign -d --entitlements :- "$APP"
otool -L "$APP/Contents/Frameworks/librime.1.dylib"
```

Expected entitlement signals include sandbox, network client, and the dev IMK
mach-register exception:

```text
com.apple.security.app-sandbox = true
com.apple.security.network.client = true
io.github.xixiphus.inputmethod.BilineIME.dev_Connection
```

## 4. Alibaba Translation Provider

The translation provider is selected at runtime. The current primary provider
is Alibaba Cloud Machine Translation through `GetBatchTranslate`.

Provider defaults:

- Region: `cn-hangzhou`
- Endpoint: `https://mt.cn-hangzhou.aliyuncs.com`
- Source language: `zh`
- Target language: `en`
- Batch path: `GetBatchTranslate`
- Scheduler profile for Aliyun: high-QPS batch mode behind local rate limiting

Create a RAM user for development rather than using the main account key:

- User name suggestion: `biline-ime-translate`
- Console access: off
- Permanent AccessKey: on
- Permission: start with Aliyun Machine Translation access for development; later
  tighten to the smallest policy that still allows batch translation.

For normal use, enter credentials in the native settings app. It stores the key
material in the dev IME container with user-only file permissions, so the IME
can read it without a cross-process authorization prompt. Do not pass
secrets as command-line arguments, because shell history and process listings
are easy to leak from a public project workflow.

```bash
make build-settings
make install-ime
open "$HOME/Applications/BilineSettingsDev.app"
```

The settings app writes key material to:

```text
~/Library/Containers/io.github.xixiphus.inputmethod.BilineIME.dev/Data/Library/Application Support/BilineIME/alibaba-credentials.json
```

It writes non-secret provider defaults to the dev IME domain:

```text
BilineTranslationProvider=aliyun
BilineAlibabaRegionId=cn-hangzhou
BilineAlibabaEndpoint=https://mt.cn-hangzhou.aliyuncs.com
```

The CLI helper writes the same local credential file for development:

```bash
make configure-aliyun-credentials
```

Do not launch `BilineSettingsDev.app` from DerivedData. A valid dev install has:

```text
~/Library/Input Methods/BilineIMEDev.app
~/Applications/BilineSettingsDev.app
```

Use `make diagnose-ime` when app registration, current input source, or
credential status is unclear.

Check credential presence without printing secrets:

```bash
make aliyun-credentials-status
```

Do not commit credentials. Do not paste production secrets into docs, tests, or
commits. If a key was shared in chat or logs, rotate it after validation.
The app and IME runtime do not read AccessKey values from environment
variables, defaults, or system credential stores.

Live API tests are intentionally skipped unless credentials are provided through
environment variables:

```bash
ALIBABA_CLOUD_ACCESS_KEY_ID='<ACCESS_KEY_ID>' \
ALIBABA_CLOUD_ACCESS_KEY_SECRET='<ACCESS_KEY_SECRET>' \
swift test --filter AlibabaMachineTranslationLiveTests
```

## 5. Normal Verification Flow

For non-host-facing package changes:

```bash
swift test --filter '<FocusedTests>'
```

For IME-facing changes, use the full layered flow:

```bash
swift test --filter 'InputControllerEventRouterTests|BilingualInputSessionTests|BilineRimeTests'
make build-ime
make install-ime
```

Then manually switch the target host app, usually TextEdit, to `BilineIME Dev`.
Codex and project scripts must stop here. The user must select the input source,
focus TextEdit, type, browse, commit, and report the result manually.

```bash
./scripts/select-input-source.sh current
```

Release packaging is paused. The release target remains in `project.yml`, but
there is no supported Make or script entrypoint for release packaging until the
dev lifecycle and first-use flow are stable.

Automated probes and key-injection scripts were removed. Do not recreate them
without an explicit project decision that reverses the manual-only host rule.

## 6. Smoke-Test Rules

The smoke harness is manual-only and evidence-first:

- User manually switches the host app to `BilineIME Dev`.
- User manually types, browses candidates, commits, and reports host text.
- Codex may read logs and run read-only diagnostics after the user finishes.
- Codex must not switch input sources, focus TextEdit, inject keys, or drive
  candidate browsing.
- Candidate panel visibility is proven by all-display screenshots, not only by
  a host accessibility tree.
- `Computer Use` is a visual/debugging aid, not the primary smoke runner.

If a macOS prompt asks whether to allow an input method or `swift-frontend`, the
human should click it. Do not automate that prompt in scripts.

## 7. Common Failure Modes

Input source is missing or stale:

```bash
make diagnose-ime
make repair-ime
```

IME process exists but no panel appears:

- Confirm the host app is actually using `BilineIME Dev`.
- Ask the user to type manually and provide screenshots, host text, telemetry,
  and system logs as evidence.

Candidate commits leak raw pinyin:

- Check Rime consumed-span telemetry.
- Re-run focused session/Rime tests before changing UI or router behavior.

Alibaba preview always fails:

- Confirm `com.apple.security.network.client` is present in entitlements.
- Confirm provider defaults are written to the dev domain.
- Confirm the native settings app has saved both AccessKey fields to the local
  credential file.
- Confirm the RAM user has machine translation permission.
- Run live tests only after explicitly opting in with environment variables.

`xattr: Permission denied` during local cleanup:

- Treat it as noise unless build, signing, install, or runtime verification
  fails.
- Do not add broad destructive cleanup to the build path. Keep cleanup in
  install/repair paths where possible.

## 8. Current Product Boundary

Keep this architecture boundary intact:

- Rime decides Chinese candidates, ranking, paging, and commit state.
- English is only a translation of the currently selected Chinese candidate.
- Whole-phrase Chinese candidate commits end the composition.
- Prefix Chinese candidate commits may leave a proven Rime tail.
- Translation preview must never block Chinese typing, browsing, or commit.
- Provider requests must go through the preview scheduler; UI/session code must
  not call cloud APIs directly.
