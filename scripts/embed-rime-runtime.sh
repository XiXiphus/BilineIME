#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-}"
ENTITLEMENTS_PATH="${2:-$ROOT_DIR/App/Support/BilineIME.entitlements}"
RIME_PREFIX="${RIME_PREFIX:-$HOME/Library/Caches/BilineIME/RimeVendor/1.16.1}"
RIME_LIB="$RIME_PREFIX/lib/librime.1.dylib"
RIME_SHARE="$RIME_PREFIX/share"
APP_FRAMEWORKS=""
APP_RUNTIME=""
APP_RIME_DATA=""

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "usage: $0 /abs/path/to/BilineIME.app [entitlements-path]" >&2
  exit 1
fi

if [[ ! -f "$RIME_LIB" ]]; then
  echo "Missing librime runtime at $RIME_LIB" >&2
  exit 1
fi

APP_FRAMEWORKS="$APP_PATH/Contents/Frameworks"
APP_RUNTIME="$APP_PATH/Contents/Resources/RimeRuntime"
APP_RIME_DATA="$APP_RUNTIME/rime-data"

mkdir -p "$APP_FRAMEWORKS" "$APP_RUNTIME"
rm -rf "$APP_RIME_DATA"
mkdir -p "$APP_RIME_DATA"

copy_runtime_dependency() {
  local dependency_path="$1"
  local dependency_name
  dependency_name="$(basename "$dependency_path")"

  if [[ -f "$dependency_path" ]]; then
    ditto "$dependency_path" "$APP_FRAMEWORKS/$dependency_name"
  fi
}

collect_non_system_dependencies() {
  local binary_path="$1"
  /usr/bin/otool -L "$binary_path" \
    | tail -n +2 \
    | awk '{print $1}' \
    | while IFS= read -r dependency; do
        case "$dependency" in
          /opt/homebrew/*/*.dylib|/opt/homebrew/*/*/*.dylib)
            printf '%s\n' "$dependency"
            ;;
        esac
      done
}

rewrite_framework_dependencies() {
  local dylib_path="$1"
  /usr/bin/install_name_tool -id "@loader_path/$(basename "$dylib_path")" "$dylib_path"
  collect_non_system_dependencies "$dylib_path" | while IFS= read -r dependency; do
    /usr/bin/install_name_tool -change "$dependency" "@loader_path/$(basename "$dependency")" "$dylib_path"
  done
}

copy_dependency_closure() {
  local seed_path="$1"
  local pending=("$seed_path")
  local processed=()

  while [[ "${#pending[@]}" -gt 0 ]]; do
    local current="${pending[0]}"
    pending=("${pending[@]:1}")

    local already_processed=0
    for item in "${processed[@]-}"; do
      if [[ "$item" == "$current" ]]; then
        already_processed=1
        break
      fi
    done
    [[ "$already_processed" == "1" ]] && continue
    processed+=("$current")

    while IFS= read -r dependency; do
      local dependency_name
      dependency_name="$(basename "$dependency")"
      if [[ ! -f "$APP_FRAMEWORKS/$dependency_name" ]]; then
        copy_runtime_dependency "$dependency"
      fi
      pending+=("$dependency")
    done < <(collect_non_system_dependencies "$current")
  done
}

detect_codesign_identity() {
  local authority
  authority="$(codesign -dvv "$APP_PATH" 2>&1 | sed -n 's/^Authority=//p' | head -n 1 || true)"
  if [[ -n "$authority" ]]; then
    printf '%s\n' "$authority"
  else
    printf '%s\n' "-"
  fi
}

sign_nested_dylib() {
  local identity="$1"
  local dylib_path="$2"
  /usr/bin/codesign --force --sign "$identity" --timestamp=none --generate-entitlement-der "$dylib_path"
}

sign_main_executable() {
  local identity="$1"
  local executable_name
  executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_PATH/Contents/Info.plist")"
  local executable_path="$APP_PATH/Contents/MacOS/$executable_name"

  /usr/bin/codesign \
    --force \
    --sign "$identity" \
    --entitlements "$ENTITLEMENTS_PATH" \
    --timestamp=none \
    --generate-entitlement-der \
    "$executable_path"
}

sign_app_bundle() {
  local identity="$1"
  /usr/bin/codesign \
    --force \
    --sign "$identity" \
    --preserve-metadata=entitlements \
    --timestamp=none \
    --generate-entitlement-der \
    "$APP_PATH"
}

ditto "$RIME_LIB" "$APP_FRAMEWORKS/librime.1.dylib"
copy_dependency_closure "$RIME_LIB"

find "$APP_FRAMEWORKS" -maxdepth 1 -name '*.dylib' -print0 | while IFS= read -r -d '' dylib; do
  rewrite_framework_dependencies "$dylib"
done

rm -rf "$APP_RUNTIME/share"
OPENCC_SHARE=""
if [[ -d "$RIME_SHARE/opencc" ]]; then
  OPENCC_SHARE="$RIME_SHARE/opencc"
elif command -v brew >/dev/null 2>&1; then
  OPENCC_PREFIX="$(brew --prefix opencc 2>/dev/null || true)"
  if [[ -n "$OPENCC_PREFIX" && -d "$OPENCC_PREFIX/share/opencc" ]]; then
    OPENCC_SHARE="$OPENCC_PREFIX/share/opencc"
  fi
fi

if [[ -n "$OPENCC_SHARE" ]]; then
  mkdir -p "$APP_RUNTIME/share/opencc"
  for file in s2t.json STCharacters.ocd2 STPhrases.ocd2; do
    if [[ -f "$OPENCC_SHARE/$file" ]]; then
      ditto "$OPENCC_SHARE/$file" "$APP_RUNTIME/share/opencc/$file"
    fi
  done
fi

for file in \
  "$ROOT_DIR/Vendor/rime-luna-pinyin/pinyin.yaml" \
  "$ROOT_DIR/Vendor/rime-ice/rime_ice.dict.yaml"; do
  if [[ -f "$file" ]]; then
    ditto "$file" "$APP_RIME_DATA/$(basename "$file")"
  fi
done

if [[ -d "$ROOT_DIR/Vendor/rime-ice/cn_dicts" ]]; then
  rm -rf "$APP_RIME_DATA/cn_dicts"
  mkdir -p "$APP_RIME_DATA/cn_dicts"
  for file in 8105 base ext tencent others; do
    if [[ -f "$ROOT_DIR/Vendor/rime-ice/cn_dicts/$file.dict.yaml" ]]; then
      ditto "$ROOT_DIR/Vendor/rime-ice/cn_dicts/$file.dict.yaml" "$APP_RIME_DATA/cn_dicts/$file.dict.yaml"
    fi
  done
fi

for file in \
  "$ROOT_DIR/Sources/BilineRime/Resources/RimeTemplates/default.yaml" \
  "$ROOT_DIR/Sources/BilineRime/Resources/RimeTemplates/biline_pinyin_simp.schema.yaml" \
  "$ROOT_DIR/Sources/BilineRime/Resources/RimeTemplates/biline_pinyin_trad.schema.yaml" \
  "$ROOT_DIR/Sources/BilineRime/Resources/RimeTemplates/biline_pinyin.dict.yaml" \
  "$ROOT_DIR/Sources/BilineRime/Resources/RimeTemplates/biline_phrases.dict.yaml" \
  "$ROOT_DIR/Sources/BilineRime/Resources/RimeTemplates/biline_modern_phrases.dict.yaml"; do
  if [[ -f "$file" ]]; then
    ditto "$file" "$APP_RIME_DATA/$(basename "$file")"
  fi
done

IDENTITY="$(detect_codesign_identity)"

find "$APP_FRAMEWORKS" -maxdepth 1 -name '*.dylib' -print0 | while IFS= read -r -d '' dylib; do
  sign_nested_dylib "$IDENTITY" "$dylib"
done

sign_main_executable "$IDENTITY"
sign_app_bundle "$IDENTITY"
