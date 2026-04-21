# IME Engine Bugs

## Open

### 1. Automated host probes can operate the wrong input source
- Severity: blocker
- Status: mitigated by policy
- Decision:
  - automated host probes and key-injection scripts have been removed
  - real-host validation is manual-only
  - Codex must stop before input-source selection, focus, typing, browsing, or commit operations
- Impact:
  - scripted host operation is no longer accepted as delivery evidence

## Notes
- Install/sign/launch blocker is already cleared.
- Current bottleneck has moved to manual real-host verification and candidate quality.
