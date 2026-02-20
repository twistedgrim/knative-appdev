#!/usr/bin/env bash
set -euo pipefail

DEMO_NAMESPACE="${DEMO_NAMESPACE:-demo-apps}"
DELETE_NAMESPACE="${DELETE_NAMESPACE:-false}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[cleanup-demo-apps] kubectl is required"
  exit 1
fi

if ! kubectl get namespace "${DEMO_NAMESPACE}" >/dev/null 2>&1; then
  echo "[cleanup-demo-apps] namespace ${DEMO_NAMESPACE} does not exist; nothing to clean"
  exit 0
fi

echo "[cleanup-demo-apps] Current Knative services in ${DEMO_NAMESPACE}:"
kubectl get ksvc -n "${DEMO_NAMESPACE}" || true

echo "[cleanup-demo-apps] Deleting all Knative services in ${DEMO_NAMESPACE}"
kubectl delete ksvc --all -n "${DEMO_NAMESPACE}" --ignore-not-found

if [[ "${DELETE_NAMESPACE}" == "true" ]]; then
  echo "[cleanup-demo-apps] Deleting namespace ${DEMO_NAMESPACE}"
  kubectl delete namespace "${DEMO_NAMESPACE}" --ignore-not-found
else
  echo "[cleanup-demo-apps] Keeping namespace ${DEMO_NAMESPACE} for next demo run"
fi

echo "[cleanup-demo-apps] Remaining Knative services in ${DEMO_NAMESPACE}:"
kubectl get ksvc -n "${DEMO_NAMESPACE}" || true
