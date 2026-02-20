#!/usr/bin/env bash
set -euo pipefail

LOCAL_PORT="${LOCAL_PORT:-8081}"
KOURIER_NAMESPACE="${KOURIER_NAMESPACE:-kourier-system}"
KOURIER_SERVICE="${KOURIER_SERVICE:-kourier}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[expose-knative-localhost] kubectl is required"
  exit 1
fi

echo "[expose-knative-localhost] Applying localhost domain config"
kubectl apply -f manifests/networking/knative-localhost-domain.yaml

echo "[expose-knative-localhost] Waiting for domain config propagation"
sleep 2

echo "[expose-knative-localhost] Example service URL: http://<service>.<namespace>.localhost:${LOCAL_PORT}"
echo "[expose-knative-localhost] Starting port-forward to Kourier gateway"
echo "[expose-knative-localhost] Press Ctrl+C to stop"

kubectl -n "${KOURIER_NAMESPACE}" port-forward svc/"${KOURIER_SERVICE}" "${LOCAL_PORT}:80"
