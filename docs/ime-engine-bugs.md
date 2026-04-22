# IME Engine Bugs

## Open

### 1. Automated host probes can operate the wrong input source
- Severity: blocker
- Status: mitigated by scoped harness policy and explicit source-readiness gate
- Decision:
  - ad hoc automated host probes and key-injection scripts have been removed
  - real-host validation defaults to manual TextEdit smoke
  - the only automated host path is the explicit local harness `bilinectl smoke-host dev --confirm`
  - install, manual source enrollment, and source-ready host smoke are three separate phases; `smoke-host` only runs the third phase and refuses to start if the source is not `enabled + selectable`
  - readiness can be inspected with `bilinectl smoke-host dev --check`; `--prepare` opens System Settings → Keyboard → Input Sources but never clicks `Allow` or enables the source for the user
  - the harness drives exactly one TextEdit session and restarts it instead of opening multiple windows/documents
  - Codex must stop before input-source selection, focus, typing, browsing, or commit operations unless the user asks for that exact harness run in the moment
- Impact:
  - scripted host operation is accepted only when it comes from the supported harness, has confirmed source readiness, and exports telemetry/artifacts

## Notes
- Install/sign/launch blocker is already cleared.
- Current bottleneck has moved to layered real-host smoke and candidate quality.
