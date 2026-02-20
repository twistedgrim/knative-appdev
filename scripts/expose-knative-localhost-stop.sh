#!/usr/bin/env bash
set -euo pipefail

PID_FILE="${PID_FILE:-/tmp/knative-localhost-portforward.pid}"
LOCAL_PORT="${LOCAL_PORT:-8081}"

if [[ ! -f "${PID_FILE}" ]]; then
  echo "[expose-knative-localhost-stop] not running (no pid file)"
  exit 0
fi

PID="$(cat "${PID_FILE}")"
if ps -p "${PID}" >/dev/null 2>&1; then
  kill "${PID}" >/dev/null 2>&1 || true
  sleep 1
fi

rm -f "${PID_FILE}"

# Cleanup orphaned listeners (for shells that lost process tracking).
PORT_PIDS="$(lsof -ti tcp:${LOCAL_PORT} -sTCP:LISTEN 2>/dev/null || true)"
if [[ -n "${PORT_PIDS}" ]]; then
  for orphan_pid in ${PORT_PIDS}; do
    kill "${orphan_pid}" >/dev/null 2>&1 || true
  done
fi

echo "[expose-knative-localhost-stop] stopped"
