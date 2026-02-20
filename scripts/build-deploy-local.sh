#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:?APP_DIR is required}"
SERVICE_NAME="${SERVICE_NAME:?SERVICE_NAME is required}"
NAMESPACE="${NAMESPACE:-default}"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-knative-dev}"
IMAGE_TAG="${IMAGE_TAG:-${DEPLOYMENT_ID:-$(date +%Y%m%d%H%M%S)}}"
IMAGE="${IMAGE:-dev.local/${SERVICE_NAME}:${IMAGE_TAG}}"

if ! command -v minikube >/dev/null 2>&1; then
  echo "[build-deploy-local] minikube is required"
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[build-deploy-local] kubectl is required"
  exit 1
fi

if [[ ! -f "${APP_DIR}/Dockerfile" ]]; then
  echo "[build-deploy-local] Dockerfile not found in APP_DIR=${APP_DIR}"
  exit 1
fi

echo "[build-deploy-local] Building image in minikube: ${IMAGE}"
minikube image build -p "${MINIKUBE_PROFILE}" -t "${IMAGE}" "${APP_DIR}"

CURRENT_SKIP="$(kubectl get configmap config-deployment -n knative-serving -o jsonpath='{.data.registriesSkippingTagResolving}' 2>/dev/null || true)"
if [[ "${CURRENT_SKIP}" == *"dev.local"* ]]; then
  echo "[build-deploy-local] Knative already configured to skip tag resolution for dev.local"
else
  NEW_SKIP="${CURRENT_SKIP}"
  if [[ -n "${NEW_SKIP}" ]]; then
    NEW_SKIP="${NEW_SKIP},dev.local"
  else
    NEW_SKIP="dev.local"
  fi
  echo "[build-deploy-local] Configuring Knative registriesSkippingTagResolving=${NEW_SKIP}"
  kubectl patch configmap/config-deployment \
    --namespace knative-serving \
    --type merge \
    --patch "{\"data\":{\"registriesSkippingTagResolving\":\"${NEW_SKIP}\"}}"
fi

echo "[build-deploy-local] Deploying Knative service ${SERVICE_NAME} in namespace ${NAMESPACE}"
cat <<MANIFEST | kubectl apply -f -
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${SERVICE_NAME}
  namespace: ${NAMESPACE}
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "0"
    spec:
      containers:
        - image: ${IMAGE}
          imagePullPolicy: IfNotPresent
MANIFEST

echo "[build-deploy-local] Waiting for service readiness"
kubectl wait ksvc/"${SERVICE_NAME}" -n "${NAMESPACE}" --for=condition=Ready --timeout=300s

echo "[build-deploy-local] Service summary"
kubectl get ksvc "${SERVICE_NAME}" -n "${NAMESPACE}"
kubectl get revision -n "${NAMESPACE}" -l serving.knative.dev/service="${SERVICE_NAME}"

echo "[build-deploy-local] Done"
