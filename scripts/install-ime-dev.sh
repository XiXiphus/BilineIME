#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="BilineIME"
SCHEME="BilineIME"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/$CONFIGURATION/$PROJECT_NAME.app"
INSTALL_PATH="/Library/Input Methods/$PROJECT_NAME.app"

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

sudo mkdir -p "/Library/Input Methods"
sudo rm -rf "$INSTALL_PATH"
sudo ditto "$APP_PATH" "$INSTALL_PATH"

echo "Installed $PROJECT_NAME to $INSTALL_PATH"
