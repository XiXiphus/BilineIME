#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/ime-paths.sh"

cd "$ROOT_DIR"

./scripts/build-ime-dev.sh

if [[ ! -d "$DEV_BUILD_APP_PATH" ]]; then
  echo "Built app not found at $DEV_BUILD_APP_PATH" >&2
  exit 1
fi

QUIET=1 ./scripts/uninstall-ime.sh

mkdir -p "$DEV_INSTALL_ROOT"
rm -rf "$DEV_INSTALL_PATH"
ditto "$DEV_BUILD_APP_PATH" "$DEV_INSTALL_PATH"
xattr -cr "$DEV_INSTALL_PATH"

for path in "${STALE_DEV_PATHS[@]}"; do
  "$LSREGISTER" -u "$path" >/dev/null 2>&1 || true
done
"$LSREGISTER" -f -R -trusted "$DEV_INSTALL_PATH" >/dev/null 2>&1 || true
"$LSREGISTER" -gc >/dev/null 2>&1 || true

pkill -x "$DEV_EXECUTABLE" >/dev/null 2>&1 || true
killall TextInputMenuAgent >/dev/null 2>&1 || true
sleep 1

ATTEMPTS=0
until ./scripts/select-input-source.sh exists "$DEV_SOURCE_ID" >/dev/null 2>&1; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [[ $ATTEMPTS -ge 15 ]]; then
    echo "Timed out waiting for $DEV_SOURCE_ID to appear in TIS." >&2
    exit 1
  fi
  sleep 1
done

cat <<EOF
Installed BilineIME Dev to $DEV_INSTALL_PATH

Next steps:
- Open Keyboard > Input Sources and add or re-select BilineIME Dev manually.
- Treat first install and metadata changes as logout/login cases.
- If the input-source picker shows blank Biline rows or Keyboard settings still crashes, run make repair-ime before reinstalling again.
EOF
