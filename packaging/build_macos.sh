#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
echo "NOTE: packaging/build_macos.sh moved to scripts/build_macos.sh."
exec "$PROJECT_DIR/scripts/build_macos.sh"
