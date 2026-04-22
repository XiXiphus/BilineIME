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
  - editing and confirmation keys (`Backspace`, `Space`, `Return`, `Esc`)
  - active-layer persistence (`Shift+Tab`, continued typing, continued browsing)
  - ambiguous / mixed-input cases (`xi'an`, `lv`, `pingguogs`, inline Latin)

## 3. Release lane remains intentionally paused

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
  - keeping broker-backed settings propagation boring and predictable
