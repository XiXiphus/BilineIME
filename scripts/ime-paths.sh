#!/bin/bash

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJECT_NAME="${PROJECT_NAME:-BilineIME}"
DERIVED_DATA="${DERIVED_DATA:-$HOME/Library/Caches/BilineIME/DerivedData}"
LSREGISTER="${LSREGISTER:-/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister}"

ABC_SOURCE_ID="com.apple.keylayout.ABC"

DEV_BUNDLE_ID="io.github.xixiphus.inputmethod.BilineIME.dev"
DEV_SOURCE_ID="io.github.xixiphus.inputmethod.BilineIME.dev.pinyin"
DEV_PRODUCT_NAME="BilineIMEDev"
DEV_EXECUTABLE="BilineIMEDev"
DEV_ENTITLEMENTS_PATH="$ROOT_DIR/App/Support/BilineIMEDev.entitlements"
DEV_INSTALL_ROOT="${HOME}/Library/Input Methods"
DEV_INSTALL_PATH="$DEV_INSTALL_ROOT/$DEV_PRODUCT_NAME.app"
DEV_BUILD_APP_PATH="$DERIVED_DATA/Build/Products/Debug/$DEV_PRODUCT_NAME.app"
DEV_XCENT_PATH="$DERIVED_DATA/Build/Intermediates.noindex/$PROJECT_NAME.build/Debug/$DEV_PRODUCT_NAME.build/$DEV_PRODUCT_NAME.app.xcent"
LEGACY_DEV_APP_PATH="$ROOT_DIR/build/DerivedData/Build/Products/Debug/$DEV_PRODUCT_NAME.app"
LEGACY_DEV_PKGROOT_PATH="$ROOT_DIR/build/pkgroot/Library/Input Methods/$DEV_PRODUCT_NAME.app"

RELEASE_BUNDLE_ID="io.github.xixiphus.inputmethod.BilineIME"
RELEASE_SOURCE_ID="io.github.xixiphus.inputmethod.BilineIME.pinyin"
RELEASE_PRODUCT_NAME="BilineIME"
RELEASE_EXECUTABLE="BilineIME"
RELEASE_ENTITLEMENTS_PATH="$ROOT_DIR/App/Support/BilineIME.entitlements"
RELEASE_INSTALL_PATH="/Library/Input Methods/$RELEASE_PRODUCT_NAME.app"
RELEASE_BUILD_APP_PATH="$DERIVED_DATA/Build/Products/Release/$RELEASE_PRODUCT_NAME.app"
RELEASE_XCENT_PATH="$DERIVED_DATA/Build/Intermediates.noindex/$PROJECT_NAME.build/Release/$RELEASE_PRODUCT_NAME.build/$RELEASE_PRODUCT_NAME.app.xcent"

STALE_DEV_PATHS=(
  "$DEV_BUILD_APP_PATH"
  "$LEGACY_DEV_APP_PATH"
  "$LEGACY_DEV_PKGROOT_PATH"
)

STALE_RELEASE_PATHS=(
  "$RELEASE_BUILD_APP_PATH"
  "$ROOT_DIR/build/DerivedData/Build/Products/Debug/$RELEASE_PRODUCT_NAME.app"
  "$ROOT_DIR/build/DerivedData/Build/Products/Release/$RELEASE_PRODUCT_NAME.app"
  "$ROOT_DIR/build/DerivedData/Build/Products/Debug 2/$RELEASE_PRODUCT_NAME.app"
  "$ROOT_DIR/build/pkgroot/Library/Input Methods/$RELEASE_PRODUCT_NAME.app"
  "$HOME/Library/Caches/BilineIME/DerivedData/Build/Products/Release/$RELEASE_PRODUCT_NAME.app"
  "$RELEASE_INSTALL_PATH"
)
