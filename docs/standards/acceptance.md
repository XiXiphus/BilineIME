# Acceptance Checklist

## Core

- Composition snapshots are deterministic for the same input and config.
- Selection and paging never crash on empty candidates.
- Commit resets the active session state.

## Preview

- Cached previews return without re-requesting the provider.
- Late preview results never replace a newer selection.
- Failure to resolve preview never blocks text entry or commit.

## App shell

- The candidate window can render the current page of candidates.
- Annotation text follows the selected candidate.
- Committing a candidate inserts Chinese text and clears composition.

## Delivery

- `make test` passes.
- `make project` regenerates the project cleanly.
- `make build-ime` succeeds on a machine with Xcode installed.
