# Acceptance Checklist

## Core

- Composition snapshots are deterministic for the same input and config.
- Selection and paging never crash on empty candidates.
- Commit resets the active session state.

## Preview

- Cached previews return without re-requesting the provider.
- Late preview results never replace a newer visible-page state.
- Failure to resolve preview never blocks text entry or commit.

## App shell

- The custom candidate panel renders the current page as vertically stacked Chinese and English rows.
- `Shift` toggles the active layer without changing the selected candidate index.
- Committing a candidate inserts the active layer text and clears composition.
- English preview state never changes Chinese candidate order or paging.

## Delivery

- `make test` passes.
- `make project` regenerates the project cleanly.
- `make build-ime` succeeds on a machine with Xcode installed.
