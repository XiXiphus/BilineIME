#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="BilineIME"
SCHEME="BilineIME"
CONFIGURATION="Release"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/$PROJECT_NAME.app"
PKG_ROOT="$ROOT_DIR/build/pkgroot"
PACKAGE_DIR="$ROOT_DIR/build/packages"
PACKAGE_PATH="$PACKAGE_DIR/$PROJECT_NAME-internal.pkg"

cd "$ROOT_DIR"

xcodegen generate --quiet
xcodebuild \
  -project "$PROJECT_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found at $APP_PATH" >&2
  exit 1
fi

rm -rf "$PKG_ROOT"
mkdir -p "$PKG_ROOT/Library/Input Methods" "$PACKAGE_DIR"
ditto "$APP_PATH" "$PKG_ROOT/Library/Input Methods/$PROJECT_NAME.app"

pkgbuild \
  --root "$PKG_ROOT" \
  --identifier "io.github.xixiphus.inputmethod.BilineIME.internal" \
  --install-location "/" \
  "$PACKAGE_PATH"

echo "Built internal package at $PACKAGE_PATH"
