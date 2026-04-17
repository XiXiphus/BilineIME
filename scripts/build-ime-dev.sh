#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="${PROJECT_NAME:-BilineIME}"
SCHEME="${SCHEME:-BilineIMEDev}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA="${DERIVED_DATA:-$HOME/Library/Caches/BilineIME/DerivedData}"
TEAM_ID="$("$ROOT_DIR/scripts/detect-dev-team.sh" || true)"

cd "$ROOT_DIR"

./scripts/scrub-macos-metadata.sh
xcodegen generate --quiet

BUILD_ARGS=(
  -project "$PROJECT_NAME.xcodeproj"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -derivedDataPath "$DERIVED_DATA"
  -destination "platform=macOS"
)

if [[ -n "$TEAM_ID" ]]; then
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
