# Repo Instructions

## Working defaults

- Keep the Chinese IME core as the primary system. Treat bilingual preview and English-layer commit as an add-on, never the source of truth for base IME behavior.
- Prefer the smallest correct change. Preserve the current state-machine structure unless a broader refactor is required to remove repeated special cases.

## Verification for IME changes

If a change affects composition, punctuation, candidate browsing, active layer, marked text, candidate panel rendering, install flow, or any host-facing IME behavior, do not stop at unit tests or build success.

Always run this sequence:

1. Narrow package tests for the behavior you changed.
2. `make build-ime`
3. `make install-ime`
4. `make smoke-ime`

The smoke test baseline is:

- use `TextEdit` as the first host
- switch to `BilineIME Dev` with `./scripts/select-input-source.sh select io.github.xixiphus.inputmethod.BilineIME.dev.pinyin`
- confirm the current source with `./scripts/select-input-source.sh current`
- use `./scripts/smoke-ime.sh prepare` to confirm the system is actually ready before any scripted key injection
- for browse keys whose semantic names may map incorrectly on macOS, prefer `./scripts/press-macos-key.swift`
- if candidate UI may render on another monitor, capture or inspect all displays instead of trusting a single app-local screenshot

When diagnosing a failure interactively inside Codex, use the `Computer Use` plugin as a follow-up tool rather than the primary smoke-test entrypoint.

Report verification in two layers:

- code/build verification
- real-host smoke-test results

Do not claim an IME behavior change is done if only the build or unit tests passed.
