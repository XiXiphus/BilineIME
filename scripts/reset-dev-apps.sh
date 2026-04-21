#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/scripts/install-settings-dev.sh"
"$ROOT_DIR/scripts/install-ime-dev.sh"

echo "Reset dev apps complete."
