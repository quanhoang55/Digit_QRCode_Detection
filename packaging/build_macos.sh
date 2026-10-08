#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

if [ ! -f "backend/model/best.pt" ]; then
  echo "Missing backend/model/best.pt"
  exit 1
fi

npm --prefix frontend install
npm --prefix frontend run build
uv run --project backend --with pyinstaller pyinstaller --noconfirm --clean packaging/ScaleDetection.spec

cp packaging/run.command dist/ScaleDetection/run.command
cp packaging/.env.portable dist/ScaleDetection/.env
chmod +x dist/ScaleDetection/run.command dist/ScaleDetection/ScaleDetection

echo
echo "Portable macOS folder created at dist/ScaleDetection"
echo "Send the entire ScaleDetection folder. The recipient runs run.command."
