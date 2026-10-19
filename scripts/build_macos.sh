#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "[1/6] Checking build prerequisites..."
if ! command -v uv >/dev/null 2>&1; then
  echo "ERROR: uv was not found. Install uv and open a new Terminal window."
  exit 1
fi
uv run --project backend --locked python scripts/check_build_prerequisites.py

if command -v bun >/dev/null 2>&1; then
  echo "[2/6] Installing locked frontend dependencies with Bun..."
  (cd frontend && bun install --frozen-lockfile)
  echo "[3/6] Building the React frontend..."
  (cd frontend && bun run build)
else
  echo "[2/6] Installing frontend dependencies with npm..."
  npm --prefix frontend install
  echo "[3/6] Building the React frontend..."
  npm --prefix frontend run build
fi

ARCHITECTURE="$(uname -m)"
export SCALE_BUNDLE_NAME="ScaleDetection-macOS-${ARCHITECTURE}"
RELEASE_DIR="$PROJECT_DIR/release/$SCALE_BUNDLE_NAME"
RELEASE_ZIP="$PROJECT_DIR/release/$SCALE_BUNDLE_NAME.zip"

echo "[4/6] Bundling Python, dependencies, frontend, and model..."
uv run --project backend --locked --with pyinstaller pyinstaller \
  --noconfirm \
  --clean \
  --distpath release \
  --workpath build/pyinstaller/macos \
  scripts/ScaleDetection.spec

echo "[5/6] Adding portable configuration and launcher..."
cp scripts/run.command "$RELEASE_DIR/run.command"
cp scripts/.env.portable "$RELEASE_DIR/.env"
mkdir -p "$RELEASE_DIR/data"
chmod +x "$RELEASE_DIR/run.command" "$RELEASE_DIR/ScaleDetection"
uv run --project backend --locked python scripts/verify_release.py "$RELEASE_DIR" --platform macos

echo "[6/6] Creating the client ZIP..."
if [ -e "$RELEASE_ZIP" ]; then
  rm -f "$RELEASE_ZIP"
fi
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$RELEASE_DIR" "$RELEASE_ZIP"

echo
echo "BUILD COMPLETE"
echo "Folder: $RELEASE_DIR"
echo "Send:   $RELEASE_ZIP"
echo "The recipient extracts the ZIP and double-clicks run.command."

