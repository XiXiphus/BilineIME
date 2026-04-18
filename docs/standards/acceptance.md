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

- The custom candidate panel renders up to `5` columns per row and up to `5` rows per page for the current candidate page.
- Compact mode shows only the first visible row; expanded mode shows all real visible rows on the current page, without padding empty cells or rows.
- The panel keeps all visible Chinese rows together in the top block and all visible English rows together in the bottom block, with strict left alignment inside the same column.
- The custom candidate panel anchors to the host-provided line-height rectangle.
- When the host does not provide a fresh valid caret rect, the candidate panel may reuse the current session's last valid rect, but never falls back to mouse position.
- `Shift+Tab` switches the active layer for the current highlighted candidate cell without changing the selected row or column.
- After switching into the English or Chinese layer with `Shift+Tab`, continued typing and candidate browsing keep that active layer until commit, cancel, or session end.
- `=` or `]` expand from compact mode and jump to the next candidate row; in expanded mode they continue browsing downward by row, but in raw-buffer-only composition they append literal input.
- `-` or `[` browse upward by row; when already on the first expanded row, they collapse to compact mode and reset the selection to the first item; before any expansion, they may enter raw-buffer-only composition.
- `+` is treated as an ordinary input character and has no IME-specific behavior.
- Chinese-mode punctuation follows a fixed default punctuation policy: common sentence punctuation commits as Chinese punctuation, raw preedit displays rendered Chinese/full-width punctuation, and literal symbol handling no longer depends on one-off router special cases.
- Committing a candidate inserts the active layer text and clears composition.
- English preview state never changes Chinese candidate order or paging.
- `Backspace`, arrows, paging keys, and digits pass through to the host when Biline is not composing.
- While Biline is composing, `Backspace` deletes raw input until empty; once empty, the next `Backspace` returns to the host.

## Delivery

- `make test` passes.
- `make project` regenerates the project cleanly.
- `make build-ime` succeeds on a machine with Xcode installed.
- `make build-ime-release` succeeds on a machine with Xcode installed.
- `make install-ime` installs the dev input method into `~/Library/Input Methods` without requiring manual bundle copying.
- `make install-ime` does not depend on automatic source activation to count as a successful install.
- IME-facing behavior changes are verified in a real host after install, with `TextEdit` as the baseline smoke-test host.
- Computer Use-based IME smoke tests use real key presses rather than literal text injection, and candidate-panel checks inspect all displays when necessary.
- `make repair-ime` provides a staged recovery path for ghost Biline sources and broken Keyboard settings state.
- `make package-release` produces an installer package that installs the release input method into `/Library/Input Methods`.
