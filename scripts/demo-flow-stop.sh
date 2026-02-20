#!/usr/bin/env bash
set -euo pipefail

UPLOAD_API_PID_FILE="${UPLOAD_API_PID_FILE:-/tmp/knative-upload-api.pid}"
UPLOAD_API_PORT="${UPLOAD_API_PORT:-8080}"

if [[ -f "${UPLOAD_API_PID_FILE}" ]]; then
  PID="$(cat "${UPLOAD_API_PID_FILE}")"
  if ps -p "${PID}" >/dev/null 2>&1; then
    kill "${PID}" >/dev/null 2>&1 || true
  fi
  rm -f "${UPLOAD_API_PID_FILE}"
fi

# Cleanup orphaned API listeners on port 8080.
API_PORT_PIDS="$(lsof -ti tcp:${UPLOAD_API_PORT} -sTCP:LISTEN 2>/dev/null || true)"
if [[ -n "${API_PORT_PIDS}" ]]; then
  for api_pid in ${API_PORT_PIDS}; do
    kill "${api_pid}" >/dev/null 2>&1 || true
  done
fi

echo "[demo-flow-stop] upload API stopped"

./scripts/expose-knative.sh --mode auto --stop
