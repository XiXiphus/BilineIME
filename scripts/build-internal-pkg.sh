#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "scripts/build-internal-pkg.sh is deprecated; using release packaging flow." >&2
exec "$ROOT_DIR/scripts/build-release-pkg.sh"
