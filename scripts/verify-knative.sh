#!/usr/bin/env bash
set -euo pipefail

SERVICE_MANIFEST="${SERVICE_MANIFEST:-manifests/samples/hello-knative-service.yaml}"
SERVICE_NAME="${SERVICE_NAME:-hello-knative}"
SERVICE_NAMESPACE="${SERVICE_NAMESPACE:-demo-apps}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[verify-knative] kubectl is required"
  exit 1
fi

echo "[verify-knative] Checking Knative Serving pods"
kubectl get pods -n knative-serving

echo "[verify-knative] Checking Kourier pods"
kubectl get pods -n kourier-system

echo "[verify-knative] Applying sample service: ${SERVICE_MANIFEST}"
kubectl get namespace "${SERVICE_NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${SERVICE_NAMESPACE}" >/dev/null
kubectl apply -f "${SERVICE_MANIFEST}"

echo "[verify-knative] Waiting for service readiness"
kubectl wait ksvc/"${SERVICE_NAME}" -n "${SERVICE_NAMESPACE}" --for=condition=Ready --timeout=180s

echo "[verify-knative] Service summary"
kubectl get ksvc "${SERVICE_NAME}" -n "${SERVICE_NAMESPACE}"
kubectl get revision -n "${SERVICE_NAMESPACE}" -l serving.knative.dev/service="${SERVICE_NAME}"

echo "[verify-knative] Done"
