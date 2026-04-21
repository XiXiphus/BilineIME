#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/ime-paths.sh"

cd "$ROOT_DIR"

wait_for_exit() {
  local executable="$1"
  local attempts=0
  while pgrep -x "$executable" >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [[ $attempts -ge 20 ]]; then
      echo "Timed out waiting for $executable to exit." >&2
      return 1
    fi
    sleep 0.25
  done
}

xcodegen generate
xcodebuild \
  -project "$PROJECT_NAME.xcodeproj" \
  -scheme "$SETTINGS_DEV_PRODUCT_NAME" \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA" \
  build

if [[ ! -d "$SETTINGS_DEV_BUILD_APP_PATH" ]]; then
  echo "Built settings app not found at $SETTINGS_DEV_BUILD_APP_PATH" >&2
  exit 1
fi

pkill -x "$SETTINGS_DEV_EXECUTABLE" >/dev/null 2>&1 || true
wait_for_exit "$SETTINGS_DEV_EXECUTABLE" || true

for path in "${STALE_SETTINGS_DEV_PATHS[@]}" "$SETTINGS_DEV_INSTALL_PATH"; do
  "$LSREGISTER" -u "$path" >/dev/null 2>&1 || true
done

mkdir -p "$SETTINGS_DEV_INSTALL_ROOT"
rm -rf "$SETTINGS_DEV_INSTALL_PATH"
ditto "$SETTINGS_DEV_BUILD_APP_PATH" "$SETTINGS_DEV_INSTALL_PATH"
chmod -R u+w "$SETTINGS_DEV_INSTALL_PATH" >/dev/null 2>&1 || true
xattr -cr "$SETTINGS_DEV_INSTALL_PATH" || true

"$LSREGISTER" -f -R -trusted "$SETTINGS_DEV_INSTALL_PATH" >/dev/null 2>&1 || true
"$LSREGISTER" -gc >/dev/null 2>&1 || true

cat <<EOF
Installed Biline Settings Dev to $SETTINGS_DEV_INSTALL_PATH

Next steps:
- Open $SETTINGS_DEV_INSTALL_PATH for dev settings.
- Do not launch BilineSettingsDev from DerivedData paths.
EOF
