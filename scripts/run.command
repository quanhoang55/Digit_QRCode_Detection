#!/bin/bash
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

if [ ! -x "./ScaleDetection" ]; then
  echo "ERROR: ScaleDetection was not found or is not executable."
  echo "Keep run.command beside ScaleDetection and the _internal folder."
  read -r -p "Press Enter to close..."
  exit 1
fi

./ScaleDetection &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' INT TERM EXIT

READY=0
for _ in $(seq 1 120); do
  if curl --silent --fail --output /dev/null "http://127.0.0.1:8000/health"; then
    READY=1
    break
  fi
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    break
  fi
  sleep 0.5
done

if [ "$READY" -eq 1 ]; then
  open "http://127.0.0.1:8000"
  echo "Scale Detection is running. Keep this window open."
else
  echo "The server did not become ready. Review the messages above."
fi

wait "$SERVER_PID"
EXIT_CODE=$?
trap - INT TERM EXIT
echo "Scale Detection stopped with exit code $EXIT_CODE."
read -r -p "Press Enter to close..."
exit "$EXIT_CODE"

