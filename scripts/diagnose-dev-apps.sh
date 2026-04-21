#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/ime-paths.sh"

echo "== Dev App Paths =="
echo "ime_install=$DEV_INSTALL_PATH"
echo "settings_install=$SETTINGS_DEV_INSTALL_PATH"
echo "settings_build=$SETTINGS_DEV_BUILD_APP_PATH"
echo

echo "== Installed Bundles =="
for path in "$DEV_INSTALL_PATH" "$SETTINGS_DEV_INSTALL_PATH"; do
  if [[ -d "$path" ]]; then
    echo "exists $path"
    /usr/bin/plutil -p "$path/Contents/Info.plist" | rg "CFBundleIdentifier|CFBundleName|CFBundleExecutable" || true
  else
    echo "missing $path"
  fi
done
echo

echo "== Running Processes =="
/usr/bin/pgrep -fl "$DEV_EXECUTABLE|$SETTINGS_DEV_EXECUTABLE" || true
echo

echo "== Current Input Source =="
"$ROOT_DIR/scripts/select-input-source.sh" current 2>/dev/null || true
echo

echo "== Credential Status =="
BILINE_DEFAULTS_DOMAIN="$DEV_BUNDLE_ID" "$ROOT_DIR/scripts/configure-aliyun-credentials.sh" status
echo

echo "== LaunchServices: Settings Dev =="
SETTINGS_LS="$("$LSREGISTER" -dump | rg -n "$SETTINGS_DEV_BUNDLE_ID|${SETTINGS_DEV_EXECUTABLE}\\.app|Biline Settings Dev" -C 2 || true)"
if [[ -n "$SETTINGS_LS" ]]; then
  echo "$SETTINGS_LS"
else
  echo "No Settings LaunchServices entries found."
fi
echo

echo "== LaunchServices: IME Dev =="
IME_LS="$("$LSREGISTER" -dump | rg -n "$DEV_BUNDLE_ID|${DEV_EXECUTABLE}\\.app|BilineIME Dev" -C 2 || true)"
if [[ -n "$IME_LS" ]]; then
  echo "$IME_LS"
else
  echo "No IME LaunchServices entries found."
fi
echo

echo "== Duplicate Settings Path Check =="
SETTINGS_PATH_COUNT="$(printf '%s\n' "$SETTINGS_LS" | rg -c 'path:.*BilineSettingsDev\.app' || true)"
echo "settings_launchservices_path_count=$SETTINGS_PATH_COUNT"
if [[ "$SETTINGS_PATH_COUNT" != "1" ]]; then
  echo "Expected exactly one Settings App LaunchServices path."
fi
