#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-src/functions/hello-func}"
SERVICE_NAME="${SERVICE_NAME:-hello-func}"
NAMESPACE="${NAMESPACE:-default}"
IMAGE_REGISTRY="${IMAGE_REGISTRY:-ghcr.io/${USER}}"
IMAGE_REPO="${IMAGE_REPO:-knative-appdev}"
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo dev-$(date +%Y%m%d%H%M%S))}"
IMAGE="${IMAGE:-${IMAGE_REGISTRY}/${IMAGE_REPO}/${SERVICE_NAME}:${IMAGE_TAG}}"
RUNTIME_CONFIG_MAP="${RUNTIME_CONFIG_MAP:-runtime-config-example}"

if ! command -v func >/dev/null 2>&1; then
  echo "[func-build-deploy] func CLI is required"
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[func-build-deploy] kubectl is required"
  exit 1
fi

echo "[func-build-deploy] Using app directory: ${APP_DIR}"
echo "[func-build-deploy] Using image: ${IMAGE}"

echo "[func-build-deploy] Building source into image"
func build --path "${APP_DIR}" --image "${IMAGE}"

echo "[func-build-deploy] Deploying to Knative"
func deploy \
  --path "${APP_DIR}" \
  --name "${SERVICE_NAME}" \
  --namespace "${NAMESPACE}" \
  --image "${IMAGE}" \
  --env "RUNTIME_CONFIG_MAP=${RUNTIME_CONFIG_MAP}"

echo "[func-build-deploy] Fetching deployment status"
kubectl get ksvc "${SERVICE_NAME}" -n "${NAMESPACE}"
kubectl get revision -n "${NAMESPACE}" -l serving.knative.dev/service="${SERVICE_NAME}"

echo "[func-build-deploy] Done"
