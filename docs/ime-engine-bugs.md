# IME Risks And Gaps

## 1. Automated host probes operating on the wrong input source

- Severity: high
- Status: mitigated; current local host smoke baseline is green
- Current position:
  - ad hoc automated host probes and key-injection scripts are out of bounds
  - the only automated host path is `bilinectl smoke-host dev --confirm`
  - install, source enrollment, and source-ready host smoke are separate phases
  - the harness fails fast on readiness and restores the original input source
    when possible
  - the harness is local-only and never a CI gate
- What is already verified:
  - `candidate-popup`
  - `browse`
  - `commit`
  - `settings-refresh`
  - `full`

## 2. Host smoke coverage is still baseline-only

- Severity: medium
- Status: open
- Gap:
  - the current baseline covers the main happy-path host flows, but not the
    harder stress set
- Next high-value cases:
  - punctuation and raw-buffer behavior (`shi_`, `shi%`, `shi()`, `shi,`,
    `ni----====+`)
  - editing and confirmation keys (`Backspace`, `Option+Backspace`,
    `Command+Backspace`, `Space`, `Return`, `Esc`)
  - raw pinyin cursor behavior (`Option+Left/Right`, `Command+Left/Right`,
    plain `Left/Right` at the end vs. middle of composition)
  - active-layer persistence (`Shift+Tab`, continued typing, continued browsing)
  - ambiguous / mixed-input cases (`xi'an`, `lv`, `pingguogs`, inline Latin)

## 3. Raw-cursor host behavior is unit-covered but host-smoke-light

- Severity: medium
- Status: mitigated in core; open in real-host coverage
- Current position:
  - raw pinyin cursor state lives in `BilingualInputSession`
  - pinyin block navigation uses shared `PinyinInputSegmenter`
  - marked text receives the insertion point through `setMarkedText`
  - candidate mode does not add a duplicate raw pinyin row to the panel
  - raw-buffer-only mode keeps a panel fallback because no candidate matrix
    exists
- Remaining gap:
  - TextEdit and other hosts still need manual or harness-backed confirmation
    that they render the insertion caret as expected
  - host-specific quirks should be handled as explicit fallbacks, not by
    making the candidate panel a permanent second input field

## 4. Release lane remains intentionally paused

- Severity: medium
- Status: open by design
- Boundary:
  - the dev lane and tester pkg flow are active
  - the reserved release target remains in project configuration
  - there is still no supported notarized release packaging workflow

## Notes

- The immediate risk profile is no longer “can the dev IME install and appear at
  all?”.
- The current focus has moved to:
  - expanding hard-case host smoke coverage
  - stabilizing candidate quality and consumed-span behavior
  - keeping raw cursor editing host-safe
  - keeping broker-backed settings propagation boring and predictable
