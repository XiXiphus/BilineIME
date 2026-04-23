# Repo Instructions

## Working defaults

- Keep the Chinese IME core as the primary system. Treat bilingual preview and English-layer commit as an add-on, never the source of truth for base IME behavior.
- Treat raw pinyin cursor editing as composition state, not host text editing. Candidate mode renders candidates only; raw pinyin/caret belongs in host marked text. Raw-buffer-only is the only panel fallback that may show raw input.
- Keep modified cursor/editing keys inside the IME while composing: `Option/Command+Left/Right`, `Option/Command+Backspace`, and their Shift variants must not leak to the host.
- Prefer the smallest correct change. Preserve the current state-machine structure unless a broader refactor is required to remove repeated special cases.

## Verification for IME changes

If a change affects composition, punctuation, candidate browsing, active layer, marked text, candidate panel rendering, install flow, or any host-facing IME behavior, do not stop at unit tests or build success.

Always run this sequence:

1. Narrow package tests for the behavior you changed.
2. `make build-ime`
3. `make install-ime`
4. Stop and ask the user to run the real-host typing step manually.

Real-host verification is layered, and the layers are separate phases:

1. Install the bundle. `make install-ime` / `bilinectl install dev --confirm` only installs the IME, Settings, and broker bundles; it does not enable the input source.
2. Manual source enrollment. The user opens System Settings → Keyboard → Input Sources, adds `BilineIME Dev`, and clicks any macOS `Allow` prompt by hand. Apple expects this onboarding step to be human-driven, so Codex and scripts must not try to automate it.
3. Source-ready host smoke. Only after the source is `enabled + selectable` may the automated harness drive TextEdit. Use `bilinectl smoke-host dev --check` to inspect readiness; the harness fails fast with remediation hints when readiness is not satisfied.

Inside that third phase the rules are:

- use `TextEdit` as the first host
- default to user-driven real-host validation: the user manually selects `BilineIME Dev`, focuses the host, types, browses, commits, and reports the result
- Codex must not switch input sources, focus the host, inject keys, or run scripts that do those actions unless the user explicitly asks for that exact automated host-smoke action in the moment
- the only supported automated real-host entrypoint is `bilinectl smoke-host dev --confirm` / `make smoke-ime-host`; it is local-only, never a CI step, and must export telemetry/artifacts
- the automated host harness must drive exactly one `TextEdit` session; reuse or restart that single session instead of opening multiple `TextEdit` windows/documents
- `Tests/` is reserved for CI-safe Swift Package tests; the real-host smoke harness lives under `Sources/bilinectl/` because it automates macOS input-source, Accessibility, TextEdit, and telemetry flows that do not belong in `swift test`
- `bilinectl smoke-host dev --check` and `--prepare` are read-only / non-destructive helpers; `--prepare` only opens System Settings and prints remediation, it never clicks `Allow` or enables the source
- `./scripts/select-input-source.sh current` and `./scripts/select-input-source.sh readiness` are read-only and may be used only to report state
- if candidate UI may render on another monitor, ask the user for screenshots across displays instead of driving the host
- dev lifecycle install/repair/diagnose flows go through `bilinectl`; Make targets and shell scripts should remain thin wrappers

When diagnosing a failure interactively inside Codex, do not use `Computer Use` to operate the input method unless the user explicitly asks for that specific action in the moment.

Report verification in two layers:

- code/build verification
- real-host smoke-test results

Do not claim an IME behavior change is done if only the build or unit tests passed.
