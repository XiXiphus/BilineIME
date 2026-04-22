#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RIME_SRC="${RIME_SRC:-$ROOT_DIR/Vendor/librime}"
RIME_VERSION="${RIME_VERSION:-1.16.1}"
RIME_PREFIX="${RIME_PREFIX:-$HOME/Library/Caches/BilineIME/RimeVendor/$RIME_VERSION}"
RIME_BUILD="${RIME_BUILD:-$RIME_SRC/build-biline}"
RIME_LIB="$RIME_PREFIX/lib/librime.1.dylib"
RIME_STAMP="$RIME_PREFIX/.biline-rime-smart-build-stamp"
PREDICT_SOURCE="${PREDICT_SOURCE:-$ROOT_DIR/Vendor/rime-predict-data/sample.txt}"
PREDICT_DB="$RIME_PREFIX/share/predict.db"

use_homebrew_fallback() {
  if [[ "${BILINE_ALLOW_HOMEBREW_RIME:-0}" != "1" ]]; then
    return 1
  fi

  if ! command -v brew >/dev/null 2>&1; then
    return 1
  fi

  local brew_prefix
  brew_prefix="$(brew --prefix librime 2>/dev/null || true)"
  if [[ -z "$brew_prefix" || ! -f "$brew_prefix/lib/librime.1.dylib" ]]; then
    return 1
  fi

  mkdir -p "$RIME_PREFIX/lib" "$RIME_PREFIX/share"
  ditto "$brew_prefix/lib/librime.1.dylib" "$RIME_PREFIX/lib/librime.1.dylib"
  if [[ -d "$brew_prefix/share/opencc" ]]; then
    rm -rf "$RIME_PREFIX/share/opencc"
    ditto "$brew_prefix/share/opencc" "$RIME_PREFIX/share/opencc"
  fi
  touch "$RIME_STAMP"
  echo "Using Homebrew librime fallback from $brew_prefix" >&2
  return 0
}

if [[ ! -d "$RIME_SRC" ]]; then
  echo "Missing vendored librime source at $RIME_SRC" >&2
  use_homebrew_fallback && exit 0
  exit 1
fi

if [[ -f "$RIME_LIB" && -f "$RIME_STAMP" ]]; then
  exit 0
fi

mkdir -p "$RIME_PREFIX"

if [[ ! -d "$RIME_SRC/plugins/octagram" || ! -d "$RIME_SRC/plugins/predict" ]]; then
  echo "Missing vendored Rime smart plugins under $RIME_SRC/plugins" >&2
  exit 1
fi

if command -v brew >/dev/null 2>&1; then
  BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  if [[ -n "$BREW_PREFIX" ]]; then
    export CMAKE_PREFIX_PATH="$BREW_PREFIX${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
  fi
fi

pushd "$RIME_SRC" >/dev/null

if ! NOPARALLEL=1 make deps; then
  echo "Vendored Rime dependency build failed; continuing with system dependencies." >&2
fi

rm -rf "$RIME_BUILD"

if ! cmake . -B"$RIME_BUILD" \
  -DCMAKE_INSTALL_PREFIX="$RIME_PREFIX" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_STATIC=OFF \
  -DBUILD_TEST=OFF \
  -DBUILD_RIME_TOOLS=OFF \
  -DBUILD_SAMPLE=OFF \
  -DBUILD_MERGED_PLUGINS=ON \
  -DENABLE_EXTERNAL_PLUGINS=OFF; then
  popd >/dev/null || true
  use_homebrew_fallback && exit 0
  exit 1
fi

if ! cmake --build "$RIME_BUILD"; then
  popd >/dev/null || true
  use_homebrew_fallback && exit 0
  exit 1
fi

if ! cmake --build "$RIME_BUILD" --target install; then
  popd >/dev/null || true
  use_homebrew_fallback && exit 0
  exit 1
fi

popd >/dev/null

BUILD_PREDICT_TOOL="$RIME_BUILD/bin/build_predict"
if [[ ! -x "$BUILD_PREDICT_TOOL" ]]; then
  BUILD_PREDICT_TOOL="$(find "$RIME_BUILD" -path '*/bin/build_predict' -type f -perm -111 -print -quit)"
fi

if [[ -n "$BUILD_PREDICT_TOOL" && -x "$BUILD_PREDICT_TOOL" && -f "$PREDICT_SOURCE" ]]; then
  mkdir -p "$RIME_PREFIX/share"
  "$BUILD_PREDICT_TOOL" "$PREDICT_DB" < "$PREDICT_SOURCE"
else
  echo "Missing build_predict tool or predict source; predict.db was not generated." >&2
  exit 1
fi

touch "$RIME_STAMP"
