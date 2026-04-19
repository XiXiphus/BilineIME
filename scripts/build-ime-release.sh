#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -n "${DERIVED_DATA:-}" ]]; then
  TEMP_DERIVED_DATA="$DERIVED_DATA"
  CLEANUP_DERIVED_DATA=0
else
  TEMP_DERIVED_DATA="$(mktemp -d "$HOME/Library/Caches/BilineIME/release-build.XXXXXX")"
  CLEANUP_DERIVED_DATA=1
fi
PROJECT_NAME="${PROJECT_NAME:-BilineIME}"
SCHEME="${SCHEME:-BilineIME}"
CONFIGURATION="${CONFIGURATION:-Release}"

DERIVED_DATA="$TEMP_DERIVED_DATA"
source "$ROOT_DIR/scripts/ime-paths.sh"

cleanup() {
  "$LSREGISTER" -u "$RELEASE_BUILD_APP_PATH" >/dev/null 2>&1 || true
  "$LSREGISTER" -gc >/dev/null 2>&1 || true
  if [[ "$CLEANUP_DERIVED_DATA" == "1" ]]; then
    rm -rf "$DERIVED_DATA"
  fi
}
trap cleanup EXIT

cd "$ROOT_DIR"

./scripts/build-librime.sh
./scripts/scrub-macos-metadata.sh
xcodegen generate --quiet
xcodebuild \
  -project "$PROJECT_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

./scripts/embed-rime-runtime.sh "$RELEASE_BUILD_APP_PATH" "$RELEASE_XCENT_PATH"

if [[ ! -d "$RELEASE_BUILD_APP_PATH" ]]; then
  echo "Built release app not found at $RELEASE_BUILD_APP_PATH" >&2
  exit 1
fi

echo "Built release input method successfully."
