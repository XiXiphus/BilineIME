#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="${PROJECT_NAME:-BilineIME}"
SCHEME="${SCHEME:-BilineIMEDev}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA="${DERIVED_DATA:-$HOME/Library/Caches/BilineIME/DerivedData}"
DEV_PRODUCT_NAME="BilineIMEDev"
DEV_BUILD_APP_PATH="$DERIVED_DATA/Build/Products/Debug/$DEV_PRODUCT_NAME.app"
DEV_XCENT_PATH="$DERIVED_DATA/Build/Intermediates.noindex/$PROJECT_NAME.build/Debug/$DEV_PRODUCT_NAME.build/$DEV_PRODUCT_NAME.app.xcent"

detect_dev_team() {
  if [[ -n "${BILINE_DEV_TEAM_ID:-}" ]]; then
    printf '%s\n' "$BILINE_DEV_TEAM_ID"
    return
  fi

  local xcode_prefs="${HOME}/Library/Preferences/com.apple.dt.Xcode.plist"
  if [[ ! -f "$xcode_prefs" ]]; then
    return
  fi

  /usr/bin/plutil -p "$xcode_prefs" 2>/dev/null \
    | /usr/bin/sed -n 's/.*"teamID" => "\(.*\)"/\1/p' \
    | /usr/bin/head -n 1
}

scrub_macos_metadata() {
  xattr -cr \
    "$ROOT_DIR/App" \
    "$ROOT_DIR/Sources" \
    "$ROOT_DIR/Tests" \
    "$ROOT_DIR/scripts" \
    "$ROOT_DIR/docs" \
    "$ROOT_DIR/README.md" \
    "$ROOT_DIR/project.yml" \
    2>/dev/null || true
}

TEAM_ID="$(detect_dev_team || true)"

cd "$ROOT_DIR"

./scripts/build-librime.sh
scrub_macos_metadata
xcodegen generate --quiet

BUILD_ARGS=(
  -project "$PROJECT_NAME.xcodeproj"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -derivedDataPath "$DERIVED_DATA"
  -destination "platform=macOS"
)

if [[ "${BILINE_AD_HOC_SIGN:-0}" == "1" ]]; then
  echo "BILINE_AD_HOC_SIGN=1 -> building with ad-hoc signing (no provisioning)."
  BUILD_ARGS+=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY=-
    CODE_SIGNING_REQUIRED=NO
    CODE_SIGNING_ALLOWED=YES
    DEVELOPMENT_TEAM=
  )
elif [[ -n "$TEAM_ID" ]]; then
  echo "Using Xcode development team: $TEAM_ID"
  BUILD_ARGS+=(
    -allowProvisioningUpdates
    DEVELOPMENT_TEAM="$TEAM_ID"
    CODE_SIGN_STYLE=Automatic
  )
else
  echo "No Xcode development team detected; building with default signing."
fi

xcodebuild "${BUILD_ARGS[@]}" build

./scripts/embed-rime-runtime.sh "$DEV_BUILD_APP_PATH" "$DEV_XCENT_PATH"
