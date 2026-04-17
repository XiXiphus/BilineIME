#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="BilineIME"
SCHEME="${SCHEME:-BilineIME}"
CONFIGURATION="${CONFIGURATION:-Release}"
if [[ -n "${DERIVED_DATA:-}" ]]; then
  TEMP_DERIVED_DATA="$DERIVED_DATA"
  CLEANUP_DERIVED_DATA=0
else
  TEMP_DERIVED_DATA="$(mktemp -d "$HOME/Library/Caches/BilineIME/release-package.XXXXXX")"
  CLEANUP_DERIVED_DATA=1
fi
PKG_ROOT="${PKG_ROOT:-$HOME/Library/Caches/BilineIME/pkgroot}"
PACKAGE_DIR="$ROOT_DIR/build/packages"
PACKAGE_PATH="$PACKAGE_DIR/$PROJECT_NAME.pkg"
PACKAGE_IDENTIFIER="io.github.xixiphus.inputmethod.BilineIME.pkg"
PKG_VERSION="${PKG_VERSION:-1.0.0}"
PKG_SIGNING_IDENTITY="${PKG_SIGNING_IDENTITY:-}"

DERIVED_DATA="$TEMP_DERIVED_DATA"
source "$ROOT_DIR/scripts/ime-paths.sh"

cleanup() {
  "$LSREGISTER" -u "$RELEASE_BUILD_APP_PATH" >/dev/null 2>&1 || true
  "$LSREGISTER" -u "$PKG_ROOT/Library/Input Methods/$RELEASE_PRODUCT_NAME.app" >/dev/null 2>&1 || true
  "$LSREGISTER" -gc >/dev/null 2>&1 || true
  rm -rf "$PKG_ROOT"
  if [[ "$CLEANUP_DERIVED_DATA" == "1" ]]; then
    rm -rf "$DERIVED_DATA"
  fi
}
trap cleanup EXIT

cd "$ROOT_DIR"

./scripts/scrub-macos-metadata.sh
xcodegen generate --quiet
xcodebuild \
  -project "$PROJECT_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

if [[ ! -d "$RELEASE_BUILD_APP_PATH" ]]; then
  echo "Built app not found at $RELEASE_BUILD_APP_PATH" >&2
  exit 1
fi

rm -rf "$PKG_ROOT"
mkdir -p "$PKG_ROOT/Library/Input Methods" "$PACKAGE_DIR"
ditto "$RELEASE_BUILD_APP_PATH" "$PKG_ROOT/Library/Input Methods/$RELEASE_PRODUCT_NAME.app"

for path in "${STALE_RELEASE_PATHS[@]}"; do
  "$LSREGISTER" -u "$path" >/dev/null 2>&1 || true
done

PKGBUILD_ARGS=(
  --root "$PKG_ROOT"
  --scripts "$ROOT_DIR/scripts/pkg"
  --identifier "$PACKAGE_IDENTIFIER"
  --version "$PKG_VERSION"
  --install-location "/"
)

if [[ -n "$PKG_SIGNING_IDENTITY" ]]; then
  PKGBUILD_ARGS+=(--sign "$PKG_SIGNING_IDENTITY")
fi

pkgbuild \
  "${PKGBUILD_ARGS[@]}" \
  "$PACKAGE_PATH"

cat <<EOF
Built release package at $PACKAGE_PATH

Installation notes:
- This package installs BilineIME to /Library/Input Methods.
- Release packaging now builds from a temporary derived-data directory and unregisters the release app after packaging, so local packaging does not leak a release source into the dev machine.
- First install and input-source metadata changes still require log out / log in before adding BilineIME in Keyboard > Input Sources.
- Set PKG_SIGNING_IDENTITY to produce a signed installer package.
EOF
