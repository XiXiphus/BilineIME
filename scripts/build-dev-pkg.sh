#!/bin/bash
# Build unsigned tester packages for BilineIME Dev:
# - one install pkg that drops BilineIMEDev.app into /Library/Input Methods and
#   BilineSettingsDev.app into /Applications
# - one safe uninstall pkg that removes the packaged dev apps but preserves user data
# - one deep-clean uninstall pkg that also clears Biline-local data to prepare for
#   future release installs
#
# All packages remain unsigned and are intended for prerelease distribution to
# trusted testers. Gatekeeper will block them on first open.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="${DERIVED_DATA:-$HOME/Library/Caches/BilineIME/DerivedData}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/build/dist}"
PKGROOT_DIR="${PKGROOT_DIR:-$ROOT_DIR/build/pkgroot}"
PKG_SCRIPTS_ROOT="${PKG_SCRIPTS_ROOT:-$ROOT_DIR/build/pkg-scripts}"
PKG_COMPONENT_PLIST="${PKG_COMPONENT_PLIST:-$ROOT_DIR/build/pkg-components.plist}"
DEV_PRODUCT_NAME="BilineIMEDev"
SETTINGS_PRODUCT_NAME="BilineSettingsDev"
BROKER_PRODUCT_NAME="BilineBrokerDev"
DEV_BUILD_APP_PATH="$DERIVED_DATA/Build/Products/Debug/$DEV_PRODUCT_NAME.app"
SETTINGS_BUILD_APP_PATH="$DERIVED_DATA/Build/Products/Debug/$SETTINGS_PRODUCT_NAME.app"
BROKER_BUILD_PATH="$DERIVED_DATA/Build/Products/Debug/$BROKER_PRODUCT_NAME"
INSTALL_PKG_IDENTIFIER="${INSTALL_PKG_IDENTIFIER:-io.github.xixiphus.inputmethod.BilineIME.dev.pkg}"
SAFE_UNINSTALL_PKG_IDENTIFIER="${SAFE_UNINSTALL_PKG_IDENTIFIER:-io.github.xixiphus.inputmethod.BilineIME.dev.uninstall.safe.pkg}"
DEEP_UNINSTALL_PKG_IDENTIFIER="${DEEP_UNINSTALL_PKG_IDENTIFIER:-io.github.xixiphus.inputmethod.BilineIME.dev.uninstall.deep-clean.pkg}"
BROKER_LAUNCH_AGENT_LABEL="io.github.xixiphus.BilineIME.dev.broker"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
BILINECTL_BUILD_CONFIGURATION="${BILINECTL_BUILD_CONFIGURATION:-release}"
KEEP_STAGING="${KEEP_STAGING:-0}"

cleanup_staging() {
  if [[ "$KEEP_STAGING" == "1" ]]; then
    return
  fi
  rm -rf "$PKGROOT_DIR" "$PKG_SCRIPTS_ROOT"
  rm -f "$PKG_COMPONENT_PLIST"
}

trap cleanup_staging EXIT

build_products() {
  if [[ "${SKIP_BUILD:-0}" == "1" ]]; then
    return
  fi

  BILINE_AD_HOC_SIGN="${BILINE_AD_HOC_SIGN:-1}" "$ROOT_DIR/scripts/build-ime-dev.sh"
  (
    cd "$ROOT_DIR"
    BILINE_AD_HOC_SIGN="${BILINE_AD_HOC_SIGN:-1}" \
      DERIVED_DATA="$DERIVED_DATA" \
      CONFIGURATION=Debug \
      make build-broker build-settings
  )
}

build_bilinectl() {
  (
    cd "$ROOT_DIR"
    swift build -c "$BILINECTL_BUILD_CONFIGURATION" --product bilinectl >/dev/null
    swift build -c "$BILINECTL_BUILD_CONFIGURATION" --show-bin-path
  )
}

require_bundle() {
  local app_path="$1"
  local description="$2"
  if [[ ! -d "$app_path" ]]; then
    echo "Missing $description at $app_path" >&2
    echo "Unset SKIP_BUILD or build the app first." >&2
    exit 1
  fi
}

require_binary() {
  local binary_path="$1"
  local description="$2"
  if [[ ! -f "$binary_path" ]]; then
    echo "Missing $description at $binary_path" >&2
    echo "Unset SKIP_BUILD or build the binary first." >&2
    exit 1
  fi
}

write_broker_launch_agent() {
  local plist_path="$1"
  cat >"$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$BROKER_LAUNCH_AGENT_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Library/Application Support/BilineIME/Broker/$BROKER_PRODUCT_NAME</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>MachServices</key>
  <dict>
    <key>$BROKER_LAUNCH_AGENT_LABEL</key>
    <true/>
  </dict>
</dict>
</plist>
EOF
}

prepare_pkgroot() {
  rm -rf "$PKGROOT_DIR"
  mkdir -p \
    "$PKGROOT_DIR/Library/Input Methods" \
    "$PKGROOT_DIR/Applications" \
    "$PKGROOT_DIR/Library/Application Support/BilineIME/Broker" \
    "$PKGROOT_DIR/Library/LaunchAgents"
  /usr/bin/ditto "$DEV_BUILD_APP_PATH" "$PKGROOT_DIR/Library/Input Methods/$DEV_PRODUCT_NAME.app"
  /usr/bin/ditto "$SETTINGS_BUILD_APP_PATH" "$PKGROOT_DIR/Applications/$SETTINGS_PRODUCT_NAME.app"
  /usr/bin/ditto "$BROKER_BUILD_PATH" "$PKGROOT_DIR/Library/Application Support/BilineIME/Broker/$BROKER_PRODUCT_NAME"
  chmod 755 "$PKGROOT_DIR/Library/Application Support/BilineIME/Broker/$BROKER_PRODUCT_NAME"
  write_broker_launch_agent "$PKGROOT_DIR/Library/LaunchAgents/$BROKER_LAUNCH_AGENT_LABEL.plist"
  /usr/bin/xattr -cr "$PKGROOT_DIR" 2>/dev/null || true
}

write_install_postinstall() {
  local scripts_dir="$1"
  mkdir -p "$scripts_dir"
  cat >"$scripts_dir/postinstall" <<EOF
#!/bin/bash
set -euo pipefail

"$LSREGISTER" -f -R -trusted "/Library/Input Methods/$DEV_PRODUCT_NAME.app" >/dev/null 2>&1 || true
"$LSREGISTER" -f -R -trusted "/Applications/$SETTINGS_PRODUCT_NAME.app" >/dev/null 2>&1 || true
/usr/bin/killall TextInputMenuAgent >/dev/null 2>&1 || true
/usr/bin/killall imklaunchagent >/dev/null 2>&1 || true
/usr/bin/killall cfprefsd >/dev/null 2>&1 || true

CONSOLE_USER="\$(
  /usr/bin/stat -f%Su /dev/console 2>/dev/null || true
)"
if [[ -n "\$CONSOLE_USER" && "\$CONSOLE_USER" != "root" ]]; then
  CONSOLE_UID="\$(
    /usr/bin/id -u "\$CONSOLE_USER" 2>/dev/null || true
  )"
  if [[ -n "\$CONSOLE_UID" ]]; then
    /bin/launchctl bootout "gui/\$CONSOLE_UID/$BROKER_LAUNCH_AGENT_LABEL" >/dev/null 2>&1 || true
    /bin/launchctl bootstrap "gui/\$CONSOLE_UID" "/Library/LaunchAgents/$BROKER_LAUNCH_AGENT_LABEL.plist" >/dev/null 2>&1 || true
    /bin/launchctl kickstart -k "gui/\$CONSOLE_UID/$BROKER_LAUNCH_AGENT_LABEL" >/dev/null 2>&1 || true
  fi
fi
EOF
  chmod 755 "$scripts_dir/postinstall"
}

write_uninstall_postinstall() {
  local scripts_dir="$1"
  mkdir -p "$scripts_dir"
  cat >"$scripts_dir/postinstall" <<EOF
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
CONSOLE_USER="\$(/usr/bin/stat -f%Su /dev/console)"
if [[ -z "\$CONSOLE_USER" || "\$CONSOLE_USER" == "root" ]]; then
  echo "Unable to determine the active console user." >&2
  exit 1
fi

HOME_DIR="\$(/usr/bin/dscl . -read "/Users/\$CONSOLE_USER" NFSHomeDirectory | /usr/bin/awk '/NFSHomeDirectory/ { print \$2 }')"
if [[ -z "\$HOME_DIR" || ! -d "\$HOME_DIR" ]]; then
  echo "Unable to resolve the active console user's home directory." >&2
  exit 1
fi

"\$SCRIPT_DIR/bilinectl"
EOF
  chmod 755 "$scripts_dir/postinstall"
}

build_install_pkg() {
  local install_scripts_dir="$1"
  local install_pkg_path="$2"

  build_component_plist

  pkgbuild \
    --root "$PKGROOT_DIR" \
    --component-plist "$PKG_COMPONENT_PLIST" \
    --scripts "$install_scripts_dir" \
    --install-location "/" \
    --identifier "$INSTALL_PKG_IDENTIFIER" \
    --version "$PKG_VERSION" \
    "$install_pkg_path"
}

build_uninstall_pkg() {
  local scripts_dir="$1"
  local identifier="$2"
  local pkg_path="$3"

  pkgbuild \
    --nopayload \
    --scripts "$scripts_dir" \
    --identifier "$identifier" \
    --version "$PKG_VERSION" \
    "$pkg_path"
}

build_component_plist() {
  pkgbuild --analyze --root "$PKGROOT_DIR" "$PKG_COMPONENT_PLIST" >/dev/null
  /usr/bin/python3 - "$PKG_COMPONENT_PLIST" <<'PY'
import plistlib
import sys
from pathlib import Path

path = Path(sys.argv[1])
with path.open('rb') as f:
    data = plistlib.load(f)

target_paths = {
    "Library/Input Methods/BilineIMEDev.app",
    "Applications/BilineSettingsDev.app",
}

for entry in data:
    if entry.get("RootRelativeBundlePath") in target_paths:
        entry["BundleIsRelocatable"] = False

with path.open('wb') as f:
    plistlib.dump(data, f)
PY
}

build_products
require_bundle "$DEV_BUILD_APP_PATH" "input method app"
require_bundle "$SETTINGS_BUILD_APP_PATH" "Settings app"
require_binary "$BROKER_BUILD_PATH" "broker binary"

INFO_PLIST="$DEV_BUILD_APP_PATH/Contents/Info.plist"
if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Missing Info.plist inside $DEV_BUILD_APP_PATH" >&2
  exit 1
fi

MARKETING_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST" 2>/dev/null || echo "1")"
GIT_SHORT="$(cd "$ROOT_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "nogit")"
PKG_VERSION="${MARKETING_VERSION}-dev.${BUILD_VERSION}+${GIT_SHORT}"

INSTALL_PKG_NAME="${DEV_PRODUCT_NAME}-${PKG_VERSION}.pkg"
SAFE_UNINSTALL_PKG_NAME="${DEV_PRODUCT_NAME}-Uninstall-${PKG_VERSION}.pkg"
DEEP_UNINSTALL_PKG_NAME="${DEV_PRODUCT_NAME}-DeepClean-${PKG_VERSION}.pkg"
INSTALL_PKG_PATH="$DIST_DIR/$INSTALL_PKG_NAME"
SAFE_UNINSTALL_PKG_PATH="$DIST_DIR/$SAFE_UNINSTALL_PKG_NAME"
DEEP_UNINSTALL_PKG_PATH="$DIST_DIR/$DEEP_UNINSTALL_PKG_NAME"

mkdir -p "$DIST_DIR"
prepare_pkgroot

BILINECTL_BIN_DIR="$(build_bilinectl)"
BILINECTL_BINARY_PATH="$BILINECTL_BIN_DIR/bilinectl"
if [[ ! -x "$BILINECTL_BINARY_PATH" ]]; then
  echo "Missing bilinectl binary at $BILINECTL_BINARY_PATH" >&2
  exit 1
fi

INSTALL_SCRIPTS_DIR="$PKG_SCRIPTS_ROOT/install"
SAFE_UNINSTALL_SCRIPTS_DIR="$PKG_SCRIPTS_ROOT/uninstall-safe"
DEEP_UNINSTALL_SCRIPTS_DIR="$PKG_SCRIPTS_ROOT/uninstall-deep-clean"
rm -rf "$PKG_SCRIPTS_ROOT"
mkdir -p "$INSTALL_SCRIPTS_DIR" "$SAFE_UNINSTALL_SCRIPTS_DIR" "$DEEP_UNINSTALL_SCRIPTS_DIR"

write_install_postinstall "$INSTALL_SCRIPTS_DIR"
cp "$BILINECTL_BINARY_PATH" "$SAFE_UNINSTALL_SCRIPTS_DIR/bilinectl.bin"
cp "$BILINECTL_BINARY_PATH" "$DEEP_UNINSTALL_SCRIPTS_DIR/bilinectl.bin"
chmod 755 "$SAFE_UNINSTALL_SCRIPTS_DIR/bilinectl.bin" "$DEEP_UNINSTALL_SCRIPTS_DIR/bilinectl.bin"
cat >"$SAFE_UNINSTALL_SCRIPTS_DIR/bilinectl" <<'EOF'
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/bilinectl.bin" remove dev --scope system --data preserve --confirm --home "$HOME_DIR"
EOF
cat >"$DEEP_UNINSTALL_SCRIPTS_DIR/bilinectl" <<'EOF'
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/bilinectl.bin" prepare-release dev --scope system --confirm --home "$HOME_DIR"
EOF
chmod 755 "$SAFE_UNINSTALL_SCRIPTS_DIR/bilinectl" "$DEEP_UNINSTALL_SCRIPTS_DIR/bilinectl"
write_uninstall_postinstall "$SAFE_UNINSTALL_SCRIPTS_DIR"
write_uninstall_postinstall "$DEEP_UNINSTALL_SCRIPTS_DIR"
/usr/bin/xattr -cr "$PKG_SCRIPTS_ROOT" 2>/dev/null || true

echo "Building tester packages:"
echo "  ime app:         $DEV_BUILD_APP_PATH"
echo "  settings app:    $SETTINGS_BUILD_APP_PATH"
echo "  broker binary:   $BROKER_BUILD_PATH"
echo "  bilinectl:       $BILINECTL_BINARY_PATH"
echo "  version:         $PKG_VERSION"
echo "  install pkg id:  $INSTALL_PKG_IDENTIFIER"
echo "  safe uninstall:  $SAFE_UNINSTALL_PKG_IDENTIFIER"
echo "  deep uninstall:  $DEEP_UNINSTALL_PKG_IDENTIFIER"

build_install_pkg "$INSTALL_SCRIPTS_DIR" "$INSTALL_PKG_PATH"
build_uninstall_pkg "$SAFE_UNINSTALL_SCRIPTS_DIR" "$SAFE_UNINSTALL_PKG_IDENTIFIER" "$SAFE_UNINSTALL_PKG_PATH"
build_uninstall_pkg "$DEEP_UNINSTALL_SCRIPTS_DIR" "$DEEP_UNINSTALL_PKG_IDENTIFIER" "$DEEP_UNINSTALL_PKG_PATH"

echo
echo "Wrote packages:"
ls -lh "$INSTALL_PKG_PATH" "$SAFE_UNINSTALL_PKG_PATH" "$DEEP_UNINSTALL_PKG_PATH"
