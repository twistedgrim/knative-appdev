#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "${SCRIPT_DIR}/upload-app.sh" \
  --api-url "${API_URL:-http://localhost:8080}" \
  --service "${SERVICE_NAME:-sample-webapp}" \
  --namespace "${NAMESPACE:-demo-apps}" \
  --app-dir "${SAMPLE_DIR:-samples/webapp}" \
  --poll-seconds "${POLL_SECONDS:-2}" \
  --max-polls "${MAX_POLLS:-180}" \
  "$@"
