#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/ime-paths.sh"

MAX_LEVEL="${1:-${REPAIR_LEVEL:-2}}"
REBOOT_REQUIRED=0

if [[ ! "$MAX_LEVEL" =~ ^[123]$ ]]; then
  echo "usage: $0 [1|2|3]" >&2
  exit 1
fi

has_biline_tis() {
  "$ROOT_DIR/scripts/select-input-source.sh" dump-bundle "$DEV_BUNDLE_ID" | rg -q .
}

has_release_tis() {
  "$ROOT_DIR/scripts/select-input-source.sh" dump-bundle "$RELEASE_BUNDLE_ID" | rg -q .
}

has_biline_hitoolbox() {
  {
    defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null || true
    defaults read com.apple.HIToolbox AppleSelectedInputSources 2>/dev/null || true
    defaults read com.apple.HIToolbox AppleInputSourceHistory 2>/dev/null || true
  } | rg -q "io\\.github\\.xixiphus\\.inputmethod\\.BilineIME"
}

has_biline_ls() {
  "$LSREGISTER" -dump | rg -q "io\\.github\\.xixiphus\\.inputmethod\\.BilineIME(\\.dev)?|BilineIMEDev\\.app|/Library/Input Methods/BilineIME\\.app"
}

has_stale_biline_ls() {
  "$LSREGISTER" -dump | rg -n "io\\.github\\.xixiphus\\.inputmethod\\.BilineIME(\\.dev)?|BilineIMEDev\\.app|/Library/Input Methods/BilineIME\\.app" -C 2 | grep -q "Bundle node not found on disk"
}

restart_text_input_ui() {
  killall TextInputMenuAgent >/dev/null 2>&1 || true
  killall "System Settings" >/dev/null 2>&1 || true
  killall cfprefsd >/dev/null 2>&1 || true
  sleep 1
}

print_state() {
  local label="$1"
  local biline_tis=0
  local release_tis=0
  local biline_hitoolbox=0
  local biline_ls=0
  local stale_ls=0

  has_biline_tis && biline_tis=1
  has_release_tis && release_tis=1
  has_biline_hitoolbox && biline_hitoolbox=1
  has_biline_ls && biline_ls=1
  has_stale_biline_ls && stale_ls=1

  cat <<EOF
[$label]
- DEV_TIS=$biline_tis
- RELEASE_TIS=$release_tis
- HITOOLBOX_BILINE=$biline_hitoolbox
- LS_BILINE=$biline_ls
- STALE_LS_BILINE=$stale_ls
EOF
}

run_level_1() {
  REMOVE_RELEASE=1 QUIET=1 "$ROOT_DIR/scripts/uninstall-ime.sh" || true
  "$ROOT_DIR/scripts/prune-hitoolbox-sources.sh" >/dev/null 2>&1 || true
  "$LSREGISTER" -gc >/dev/null 2>&1 || true
  restart_text_input_ui
}

run_level_2() {
  sudo rm -f /System/Library/Caches/com.apple.IntlDataCache*
  sudo rm -f /var/folders/*/*/*/com.apple.IntlDataCache*
  REBOOT_REQUIRED=1
  restart_text_input_ui
}

run_level_3() {
  sudo "$LSREGISTER" -delete
  REBOOT_REQUIRED=1
}

echo "Running BilineIME repair flow through level $MAX_LEVEL"

run_level_1
print_state "level-1"

if [[ "$MAX_LEVEL" -ge 2 ]]; then
  run_level_2
  print_state "level-2"
fi

if [[ "$MAX_LEVEL" -ge 3 ]]; then
  run_level_3
  print_state "level-3"
fi

cat <<EOF
Repair flow finished.

Next steps:
- Re-open Keyboard > Input Sources to verify the blank Biline rows are gone.
- If you ran level 2 or 3, reboot before judging the result.
- If level 2 still leaves Keyboard settings broken, re-run with: make repair-ime REPAIR_LEVEL=3
EOF

if [[ "$REBOOT_REQUIRED" == "1" ]]; then
  echo "A reboot is required for the full repair result."
fi
