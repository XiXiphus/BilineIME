#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

xattr -cr \
  "$ROOT_DIR/App" \
  "$ROOT_DIR/Sources" \
  "$ROOT_DIR/Tests" \
  "$ROOT_DIR/scripts" \
  "$ROOT_DIR/docs" \
  "$ROOT_DIR/README.md" \
  "$ROOT_DIR/project.yml" \
  2>/dev/null || true
