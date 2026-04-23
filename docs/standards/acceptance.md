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
- In candidate mode, the panel shows candidates only. It must not add a second
  raw pinyin input row above the matrix.
- In raw-buffer-only composition, the panel may show the rendered raw buffer
  with a visible cursor because no candidate matrix is available.
- The custom candidate panel anchors to the host-provided line-height rectangle.
- When the host does not provide a fresh valid caret rect, the candidate panel may reuse the current session's last valid rect, but never falls back to mouse position.
- `Shift+Tab` switches the active layer for the current highlighted candidate cell without changing the selected row or column.
- After switching into the English or Chinese layer with `Shift+Tab`, continued typing and candidate browsing keep that active layer until commit, cancel, or session end.
- `=` or `]` expand from compact mode and jump to the next candidate row; in expanded mode they continue browsing downward by row, but in raw-buffer-only composition they append literal input.
- `-` or `[` browse upward by row; when already on the first expanded row, they collapse to compact mode and reset the selection to the first item; before any expansion, they may enter raw-buffer-only composition.
- `+` is treated as an ordinary input character and has no IME-specific behavior.
- Chinese-mode punctuation follows a fixed default punctuation policy: common sentence punctuation commits as Chinese punctuation, raw preedit displays rendered Chinese/full-width punctuation, and literal symbol handling no longer depends on one-off router special cases.
- Raw pinyin composition is edited through marked text, not by moving or
  deleting host document text. `Option+Left/Right` moves by pinyin block,
  `Command+Left/Right` moves to the composition edges, `Option+Backspace`
  deletes one pinyin block, and `Command+Backspace` deletes to the raw cursor
  start.
- Plain `Left/Right` browses candidates only when the raw pinyin cursor is at
  the end of the composition. If the cursor is in the middle, it moves the raw
  cursor by character. In raw-buffer-only composition, `Left/Right` stays inside
  the IME.
- Modified arrows and modified backspace must not pass through to the host while
  Biline is composing.
- Raw cursor edits reset explicit candidate selection and return presentation to
  compact mode before refreshing candidates.
- Committing a candidate inserts the active layer text and clears composition.
- English preview state never changes Chinese candidate order or paging.
- `Backspace`, arrows, paging keys, and digits pass through to the host when Biline is not composing.
- While Biline is composing, `Backspace` deletes raw input until empty; once empty, the next `Backspace` returns to the host.

## Delivery

- `make test` passes.
- `make project` regenerates the project cleanly.
- `make build-ime` succeeds on a machine with Xcode installed.
- `make install-ime` installs the dev input method into `~/Library/Input Methods` without requiring manual bundle copying.
- `make install-ime` does not depend on automatic source activation to count as a successful install.
- `make remove-ime` removes the dev app bundles while preserving user data.
- `make reset-ime` provides a dry-run/apply reset path for Launch Services and text-input cache damage.
- `make dev-pkg` emits an unsigned tester installer pkg plus safe and deep-clean uninstall pkgs.
- IME-facing behavior changes are verified in a real host after install, with `TextEdit` as the baseline host.
- Install bundle, manual source enrollment, and source-ready host smoke are three distinct phases. The first two are not part of automated host smoke and are not CI responsibilities.
- Real-host validation has two approved modes: user-driven manual smoke, and the explicit local harness `bilinectl smoke-host dev --confirm` / `make smoke-ime-host`.
- Codex must not switch input sources, focus TextEdit, inject keys, or drive candidate browsing unless the user explicitly asks for that exact automated host-smoke action in the moment.
- The local host harness must classify pre-run state as one of `bundle-missing`, `source-missing`, `source-disabled`, `source-not-selectable`, `source-not-selected`, or `ready`, and fail fast with explicit remediation when the source is not ready.
- The local host harness is never a CI gate. It must perform preflight checks, drive exactly one TextEdit session, restore the original input source where possible, and export telemetry/artifacts.
- If the harness needs a clean state, it must restart that one TextEdit session rather than opening multiple TextEdit windows/documents.
- `bilinectl smoke-host dev --prepare` may open System Settings → Keyboard → Input Sources, but must not click `Allow`, enable the source, or otherwise script the manual enrollment step.
- Candidate-panel checks use telemetry plus user-provided screenshots across displays when necessary.
- The local host smoke baseline supports `candidate-popup`, `browse`, `commit`, `settings-refresh`, and `full`.
- Repository docs (`README`, architecture, handoff, standards, bug notes) describe the current broker-mediated coordination model, phased source enrollment model, and paused release lane without contradicting the implementation.
- Formal release packaging is intentionally paused; the release target may remain in project configuration, but it has no supported notarized Make/script workflow. The unsigned tester pkg flow stays on the dev lane.
