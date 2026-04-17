#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUIET="${QUIET:-0}"
REMOVE_RELEASE="${REMOVE_RELEASE:-0}"
source "$ROOT_DIR/scripts/ime-paths.sh"

log() {
  if [[ "$QUIET" != "1" ]]; then
    echo "$@"
  fi
}

run_ls_unregister() {
  "$LSREGISTER" -u "$1" >/dev/null 2>&1 || true
}

current_source_id() {
  "$ROOT_DIR/scripts/select-input-source.sh" current 2>/dev/null || true
}

cleanup_release_install() {
  if [[ "$REMOVE_RELEASE" == "1" && -e "$RELEASE_INSTALL_PATH" ]]; then
    log "Cleaning release bundle at $RELEASE_INSTALL_PATH"
    sudo "$LSREGISTER" -u "$RELEASE_INSTALL_PATH" >/dev/null 2>&1 || true
    sudo rm -rf "$RELEASE_INSTALL_PATH"
  fi
}

current_id="$(current_source_id)"
if [[ "$current_id" == "$DEV_SOURCE_ID" || "$current_id" == "$RELEASE_SOURCE_ID" ]]; then
  log "Switching current input source back to ABC"
  "$ROOT_DIR/scripts/select-input-source.sh" select "$ABC_SOURCE_ID" >/dev/null 2>&1 || true
fi

log "Disabling Biline input sources"
"$ROOT_DIR/scripts/select-input-source.sh" disable "$DEV_SOURCE_ID" >/dev/null 2>&1 || true
if [[ "$REMOVE_RELEASE" == "1" ]]; then
  "$ROOT_DIR/scripts/select-input-source.sh" disable "$RELEASE_SOURCE_ID" >/dev/null 2>&1 || true
fi

log "Unregistering Biline bundles before removal"
run_ls_unregister "$DEV_INSTALL_PATH"
for path in "${STALE_DEV_PATHS[@]}"; do
  run_ls_unregister "$path"
done
if [[ "$REMOVE_RELEASE" == "1" ]]; then
  run_ls_unregister "$RELEASE_INSTALL_PATH"
  for path in "${STALE_RELEASE_PATHS[@]}"; do
    run_ls_unregister "$path"
  done
fi

if [[ -d "$DEV_INSTALL_PATH" ]]; then
  log "Removing dev bundle at $DEV_INSTALL_PATH"
  rm -rf "$DEV_INSTALL_PATH"
fi

cleanup_release_install

log "Garbage collecting Launch Services and restarting text input agents"
"$LSREGISTER" -gc >/dev/null 2>&1 || true
pkill -x "$DEV_EXECUTABLE" >/dev/null 2>&1 || true
if [[ "$REMOVE_RELEASE" == "1" ]]; then
  pkill -x "$RELEASE_EXECUTABLE" >/dev/null 2>&1 || true
fi
killall TextInputMenuAgent >/dev/null 2>&1 || true
sleep 1

log "BilineIME dev lane removed."
