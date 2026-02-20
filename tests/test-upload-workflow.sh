#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-http://localhost:8080}"
TMP_DIR="$(mktemp -d)"
BUNDLE_PATH="${TMP_DIR}/sample-bundle.tar.gz"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${TMP_DIR}/app"
cat > "${TMP_DIR}/app/README.md" <<'DOC'
# sample app
DOC

tar -czf "${BUNDLE_PATH}" -C "${TMP_DIR}/app" .

echo "[test-upload-workflow] Checking health endpoint"
curl -sf "${API_URL}/healthz" >/dev/null

echo "[test-upload-workflow] Uploading bundle"
DEPLOY_RESPONSE="$(curl -sf -X POST "${API_URL}/deploy" \
  -F "bundle=@${BUNDLE_PATH}" \
  -F "service=sample-uploaded-app" \
  -F "namespace=default")"

echo "${DEPLOY_RESPONSE}"
DEPLOY_ID="$(echo "${DEPLOY_RESPONSE}" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')"
if [[ -z "${DEPLOY_ID}" ]]; then
  echo "[test-upload-workflow] failed to parse deployment id"
  exit 1
fi

echo "[test-upload-workflow] Polling status for ${DEPLOY_ID}"
for _ in $(seq 1 10); do
  STATUS_RESPONSE="$(curl -sf "${API_URL}/status/${DEPLOY_ID}")"
  STATUS="$(echo "${STATUS_RESPONSE}" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')"
  echo "status=${STATUS}"
  if [[ "${STATUS}" == "READY" || "${STATUS}" == "FAILED" ]]; then
    echo "${STATUS_RESPONSE}"
    exit 0
  fi
  sleep 1
done

echo "[test-upload-workflow] deployment did not reach terminal state"
exit 1
