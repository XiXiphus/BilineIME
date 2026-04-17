#!/bin/bash
set -euo pipefail

TARGET="${1:-release}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/ime-paths.sh"

case "$TARGET" in
  dev)
    BUNDLE_ID="$DEV_BUNDLE_ID"
    SOURCE_ID="$DEV_SOURCE_ID"
    APP_PATH="$DEV_INSTALL_PATH"
    EXECUTABLE="$DEV_EXECUTABLE"
    ;;
  release)
    BUNDLE_ID="$RELEASE_BUNDLE_ID"
    SOURCE_ID="$RELEASE_SOURCE_ID"
    APP_PATH="$RELEASE_INSTALL_PATH"
    EXECUTABLE="$RELEASE_EXECUTABLE"
    ;;
  *)
    echo "usage: $0 [dev|release]" >&2
    exit 1
    ;;
esac

echo "Target: $TARGET"
echo "Bundle ID: $BUNDLE_ID"
echo "Source ID: $SOURCE_ID"
echo "App path: $APP_PATH"
echo

if [[ -d "$APP_PATH" ]]; then
  echo "== Bundle =="
  /bin/ls -ld "$APP_PATH"
  /usr/bin/plutil -p "$APP_PATH/Contents/Info.plist" | sed -n '1,200p'
  echo
  echo "== Code Sign =="
  /usr/bin/codesign -dv "$APP_PATH" 2>&1 | sed -n '1,120p'
  echo
  echo "== Entitlements =="
  /usr/bin/codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | sed -n '1,200p'
  echo
  echo "== Gatekeeper =="
  /usr/sbin/spctl --assess --type execute --verbose=4 "$APP_PATH" 2>&1 | sed -n '1,80p' || true
else
  echo "Bundle does not exist."
fi

echo
echo "== LaunchServices Entries =="
LS_OUTPUT="$("$LSREGISTER" -dump | rg -n "$BUNDLE_ID|${EXECUTABLE}\\.app|io\\.github\\.xixiphus\\.inputmethod\\.BilineIME|BilineIME\\.app" -C 2 || true)"
if [[ -n "$LS_OUTPUT" ]]; then
  echo "$LS_OUTPUT"
else
  echo "No LaunchServices entries found."
fi

echo
echo "== LaunchServices Status =="
STALE_BUNDLE_NODE=0
if grep -q "Bundle node not found on disk" <<<"$LS_OUTPUT"; then
  STALE_BUNDLE_NODE=1
  echo "STALE_BUNDLE_NODE=1"
  echo "Launch Services still tracks a missing Biline bundle."
  echo "Last resort recovery: sudo $LSREGISTER -delete, then reboot."
else
  echo "STALE_BUNDLE_NODE=0"
fi

echo
echo "== HIToolbox Enabled Sources =="
defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null | sed -n '1,240p' || true

echo
echo "== HIToolbox Selected Sources =="
defaults read com.apple.HIToolbox AppleSelectedInputSources 2>/dev/null | sed -n '1,160p' || true

echo
echo "== TIS Sources =="
TIS_OUTPUT="$("$ROOT_DIR/scripts/select-input-source.sh" dump-bundle "$BUNDLE_ID" 2>/dev/null || true)"
if [[ -n "$TIS_OUTPUT" ]]; then
  echo "$TIS_OUTPUT" | sed -n '1,200p'
else
  echo "No TIS sources found for $BUNDLE_ID."
fi

echo
echo "== TIS Status =="
BLANK_TIS_NAME=0
if grep -q "name=$" <<<"$TIS_OUTPUT" || grep -q "name=(null)" <<<"$TIS_OUTPUT"; then
  BLANK_TIS_NAME=1
  echo "BLANK_TIS_NAME=1"
  echo "At least one Biline source has an empty localized name."
else
  echo "BLANK_TIS_NAME=0"
fi

CURRENT_SOURCE="$("$ROOT_DIR/scripts/select-input-source.sh" current 2>/dev/null || true)"
echo "CURRENT_SOURCE=$CURRENT_SOURCE"

echo
echo "== Running Processes =="
/usr/bin/pgrep -fl "$EXECUTABLE|$BUNDLE_ID" || true

echo
echo "== Recent Logs =="
/usr/bin/log show --last 10m --info --predicate "process == \"$EXECUTABLE\" OR subsystem == \"$BUNDLE_ID\" OR eventMessage CONTAINS[c] \"IMKServer\" OR eventMessage CONTAINS[c] \"$BUNDLE_ID\"" --style compact | tail -n 200 || true

echo
echo "== KeyboardSettings Crashes =="
ls -1t "$HOME/Library/Logs/DiagnosticReports"/KeyboardSettings-*.ips 2>/dev/null | head -n 5 || true

echo
echo "== Repair Hint =="
if [[ "$STALE_BUNDLE_NODE" == "1" ]]; then
  echo "Launch Services still has stale Biline state. Run make repair-ime."
elif [[ "$BLANK_TIS_NAME" == "1" ]]; then
  echo "At least one Biline source still has a blank localized name. Run make repair-ime."
else
  echo "If Keyboard settings still shows blank Biline rows or crashes, run make repair-ime."
fi
