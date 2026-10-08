#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

if [ ! -x "./ScaleDetection" ]; then
  echo "ScaleDetection was not found or is not executable in this folder."
  read -r -p "Press Enter to close..."
  exit 1
fi

./ScaleDetection &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null' INT TERM EXIT

READY=0
for _ in $(seq 1 60); do
  if curl --silent --fail --output /dev/null "http://127.0.0.1:8000"; then
    READY=1
    break
  fi
  sleep 0.5
done

if [ "$READY" -eq 1 ]; then
  open "http://127.0.0.1:8000"
else
  echo "The server did not become ready. Review the messages above."
fi

wait "$SERVER_PID"
