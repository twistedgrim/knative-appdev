#!/usr/bin/env bash
set -euo pipefail

LOCAL_PORT="${LOCAL_PORT:-8081}"
PID_FILE="${PID_FILE:-/tmp/knative-localhost-portforward.pid}"
LOG_FILE="${LOG_FILE:-/tmp/knative-localhost-portforward.log}"

if [[ -f "${PID_FILE}" ]]; then
  OLD_PID="$(cat "${PID_FILE}")"
  if ps -p "${OLD_PID}" >/dev/null 2>&1; then
    echo "[expose-knative-localhost-bg] already running (pid=${OLD_PID})"
    echo "[expose-knative-localhost-bg] log: ${LOG_FILE}"
    exit 0
  fi
fi

./scripts/expose-knative-localhost.sh >"${LOG_FILE}" 2>&1 &
NEW_PID=$!
echo "${NEW_PID}" > "${PID_FILE}"

for _ in $(seq 1 20); do
  if ! ps -p "${NEW_PID}" >/dev/null 2>&1; then
    echo "[expose-knative-localhost-bg] failed to start; tail log:"
    tail -n 40 "${LOG_FILE}" || true
    exit 1
  fi
  if lsof -nP -iTCP:"${LOCAL_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! lsof -nP -iTCP:"${LOCAL_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "[expose-knative-localhost-bg] process started but port ${LOCAL_PORT} is not listening yet"
  echo "[expose-knative-localhost-bg] tail log:"
  tail -n 40 "${LOG_FILE}" || true
  exit 1
fi

echo "[expose-knative-localhost-bg] running on localhost:${LOCAL_PORT} (pid=${NEW_PID})"
echo "[expose-knative-localhost-bg] stop with: ./scripts/expose-knative-localhost-stop.sh"
