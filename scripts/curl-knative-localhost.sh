#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-hello-knative}"
NAMESPACE="${NAMESPACE:-demo-apps}"
LOCAL_PORT="${LOCAL_PORT:-8081}"

URL="http://${SERVICE_NAME}.${NAMESPACE}.localhost:${LOCAL_PORT}"

echo "[curl-knative-localhost] Requesting ${URL}"
curl -fsS "${URL}"
echo
