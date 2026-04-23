# ADR 0009: Keep Raw Pinyin Cursor Editing Inline

## Status

Accepted

## Context

BilineIME needs macOS-style editing inside the live pinyin composition:

- moving by pinyin block with `Option+Left/Right`
- jumping to composition edges with `Command+Left/Right`
- deleting by pinyin block with `Option+Backspace`
- deleting to the raw cursor start with `Command+Backspace`
- preserving candidate browsing semantics when the raw cursor is already at the
  end

An earlier implementation briefly rendered a dedicated raw pinyin row in the
candidate panel to make the raw cursor visible. That solved visibility in some
hosts, but it made the panel feel like a second input field and diverged from
mainstream macOS input method behavior.

## Decision

Raw pinyin and the raw cursor are rendered through host marked text by default.

The candidate panel remains a candidate panel:

- candidate mode renders only the bilingual candidate matrix
- raw-buffer-only mode may render a single raw buffer fallback because no
  candidate matrix exists

The session owns raw cursor state. Host routing keeps raw editing inside the IME
while composing:

- `Option+Left/Right` moves by pinyin block
- `Command+Left/Right` moves to start/end
- `Option+Backspace` deletes one pinyin block
- `Command+Backspace` deletes to raw cursor start
- plain `Left/Right` browse candidates only when the raw cursor is at the end
- plain `Left/Right` move the raw cursor by character when it is in the middle
- modified arrows/backspace do not pass through to host text while composing

## Consequences

- The user sees one input surface: marked text in the host.
- The candidate panel stays visually focused on candidates and bilingual
  preview.
- Host quirks around marked text caret rendering must be diagnosed explicitly
  with screenshots or telemetry; they should not be hidden by making the panel a
  permanent duplicate raw input field.
- CI-safe tests cover router/session behavior. Real-host smoke still needs
  broader coverage for raw cursor and modified editing keys.
