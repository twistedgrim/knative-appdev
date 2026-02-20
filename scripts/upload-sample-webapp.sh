#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-http://localhost:8080}"
SERVICE_NAME="${SERVICE_NAME:-sample-webapp}"
NAMESPACE="${NAMESPACE:-default}"
SAMPLE_DIR="${SAMPLE_DIR:-samples/webapp}"
POLL_SECONDS="${POLL_SECONDS:-2}"
MAX_POLLS="${MAX_POLLS:-180}"

if [[ ! -d "${SAMPLE_DIR}" ]]; then
  echo "[upload-sample-webapp] sample directory not found: ${SAMPLE_DIR}"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
BUNDLE_PATH="${TMP_DIR}/sample-webapp.tar.gz"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

tar -czf "${BUNDLE_PATH}" -C "${SAMPLE_DIR}" .

echo "[upload-sample-webapp] Uploading bundle to ${API_URL}/deploy"
RESPONSE="$(curl -sf -X POST "${API_URL}/deploy" \
  -F "bundle=@${BUNDLE_PATH}" \
  -F "service=${SERVICE_NAME}" \
  -F "namespace=${NAMESPACE}")"

echo "${RESPONSE}"
DEPLOY_ID="$(echo "${RESPONSE}" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')"
if [[ -z "${DEPLOY_ID}" ]]; then
  echo "[upload-sample-webapp] failed to parse deployment id"
  exit 1
fi

echo "[upload-sample-webapp] Deployment id: ${DEPLOY_ID}"

for _ in $(seq 1 "${MAX_POLLS}"); do
  if ! STATUS_JSON="$(curl -s "${API_URL}/status/${DEPLOY_ID}")"; then
    echo "[upload-sample-webapp] status endpoint not reachable yet; retrying"
    sleep "${POLL_SECONDS}"
    continue
  fi
  STATUS="$(echo "${STATUS_JSON}" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')"
  if [[ -z "${STATUS}" ]]; then
    echo "[upload-sample-webapp] status payload not ready yet; retrying"
    sleep "${POLL_SECONDS}"
    continue
  fi
  echo "[upload-sample-webapp] status=${STATUS}"
  if [[ "${STATUS}" == "READY" || "${STATUS}" == "FAILED" ]]; then
    echo "${STATUS_JSON}"
    exit 0
  fi
  sleep "${POLL_SECONDS}"
done

echo "[upload-sample-webapp] timed out waiting for terminal deployment state after $((MAX_POLLS * POLL_SECONDS))s"
exit 1
