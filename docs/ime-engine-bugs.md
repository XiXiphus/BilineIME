# IME Engine Bugs

## Open

### 1. Entering a smoke case can revert TextEdit back to WeType
- Severity: blocker
- Repro:
  1. `./scripts/smoke-ime.sh prepare`
  2. `./scripts/smoke-ime.sh case case_browse_expand_equal`
- Expected:
  - `current_input_source == io.github.xixiphus.inputmethod.BilineIME.dev.pinyin`
- Actual:
  - case startup reports `Expected input source io.github.xixiphus.inputmethod.BilineIME.dev.pinyin, got com.tencent.inputmethod.wetype.pinyin`
- Impact:
  - all host smoke results after case start are unreliable because key events are delivered to WeType instead of Biline
- Evidence:
  - `/tmp/biline-ime-smoke/20260418-194938-79986`

## Notes
- Install/sign/launch blocker is already cleared.
- Current bottleneck has moved to real-host input-source stability and post-launch behavior.
