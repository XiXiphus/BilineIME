#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LEVEL="${1:-${REPAIR_LEVEL:-2}}"

if [[ "${2:-}" == "--confirm" || "${BILINE_REPAIR_CONFIRM:-0}" == "1" ]]; then
  exec swift run bilinectl reinstall dev --level "$LEVEL" --confirm
fi

swift run bilinectl plan reinstall dev --level "$LEVEL"
cat <<EOF
Dry run only.
Re-run with one of:
  BILINE_REPAIR_CONFIRM=1 ./scripts/repair-ime.sh $LEVEL
  ./scripts/repair-ime.sh $LEVEL --confirm
EOF
