#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

UPLOAD_API_LOG="${UPLOAD_API_LOG:-/tmp/knative-upload-api.log}"
UPLOAD_API_PID_FILE="${UPLOAD_API_PID_FILE:-/tmp/knative-upload-api.pid}"
UPLOAD_API_URL="${UPLOAD_API_URL:-http://localhost:8080}"
MOCK_DEPLOY="${MOCK_DEPLOY:-true}"
BUILD_DEPLOY_SCRIPT="${BUILD_DEPLOY_SCRIPT:-}"

if ! command -v go >/dev/null 2>&1; then
  echo "[demo-flow] go is required. Install with: brew install go"
  exit 1
fi

if [[ -f "${UPLOAD_API_PID_FILE}" ]]; then
  OLD_PID="$(cat "${UPLOAD_API_PID_FILE}")"
  if ps -p "${OLD_PID}" >/dev/null 2>&1; then
    echo "[demo-flow] upload API already running (pid=${OLD_PID})"
  else
    rm -f "${UPLOAD_API_PID_FILE}"
  fi
fi

echo "[demo-flow] Starting localhost exposure"
./scripts/expose-knative-localhost-bg.sh

echo "[demo-flow] Starting upload API"
if [[ ! -f "${UPLOAD_API_PID_FILE}" ]]; then
  (
    cd src/upload-api
    nohup env MOCK_DEPLOY="${MOCK_DEPLOY}" BUILD_DEPLOY_SCRIPT="${BUILD_DEPLOY_SCRIPT}" PORT=8080 go run . >"${UPLOAD_API_LOG}" 2>&1 < /dev/null &
    echo $! > "${UPLOAD_API_PID_FILE}"
  )
fi

API_PID="$(cat "${UPLOAD_API_PID_FILE}")"
if ! ps -p "${API_PID}" >/dev/null 2>&1; then
  echo "[demo-flow] upload API failed to start; tail log:"
  tail -n 60 "${UPLOAD_API_LOG}" || true
  exit 1
fi

for _ in $(seq 1 20); do
  if curl -fsS "${UPLOAD_API_URL}/healthz" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -fsS "${UPLOAD_API_URL}/healthz" >/dev/null 2>&1; then
  echo "[demo-flow] upload API is not healthy; tail log:"
  tail -n 60 "${UPLOAD_API_LOG}" || true
  exit 1
fi

echo "[demo-flow] Uploading sample webapp"
./scripts/upload-sample-webapp.sh

echo "[demo-flow] Demo is running"
echo "[demo-flow] Browser URL (baseline): http://hello-knative.default.localhost:8081"
echo "[demo-flow] Browser URL (uploaded app): http://sample-webapp.default.localhost:8081"
echo "[demo-flow] API status: ${UPLOAD_API_URL}/status/latest"
echo "[demo-flow] Upload API log: ${UPLOAD_API_LOG}"
echo "[demo-flow] Stop with: task flow:demo:stop"
