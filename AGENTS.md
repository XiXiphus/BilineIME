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
4. Real-host smoke test with the `Computer Use` plugin.

The smoke test baseline is:

- use `TextEdit` as the first host
- switch to `BilineIME Dev` with `./scripts/select-input-source.sh select io.github.xixiphus.inputmethod.BilineIME.dev.pinyin`
- confirm the current source with `./scripts/select-input-source.sh current`
- use `press_key`, not `type_text`, because `type_text` may bypass IME composition
- if candidate UI may render on another monitor, capture or inspect all displays instead of trusting a single app-local screenshot

Report verification in two layers:

- code/build verification
- real-host smoke-test results

Do not claim an IME behavior change is done if only the build or unit tests passed.
