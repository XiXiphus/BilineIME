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
4. Stop and ask the user to run the real-host typing step manually.

Real-host verification is manual-only:

- use `TextEdit` as the first host
- the user manually selects `BilineIME Dev`, focuses the host, types, browses, commits, and reports the result
- Codex must not switch input sources, focus the host, inject keys, or run scripts that do those actions
- `./scripts/select-input-source.sh current` is read-only and may be used only to report the current source
- if candidate UI may render on another monitor, ask the user for screenshots across displays instead of driving the host
- dev lifecycle install/repair/diagnose flows go through `bilinectl`; Make targets and shell scripts should remain thin wrappers

When diagnosing a failure interactively inside Codex, do not use `Computer Use` to operate the input method unless the user explicitly asks for that specific action in the moment.

Report verification in two layers:

- code/build verification
- real-host smoke-test results

Do not claim an IME behavior change is done if only the build or unit tests passed.
