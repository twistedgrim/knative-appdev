#!/usr/bin/env bash
set -euo pipefail

MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-knative-dev}"
NAMESPACE="${NAMESPACE:-platform-system}"
SERVICE_NAME="${SERVICE_NAME:-app-dashboard}"
IMAGE_TAG="${IMAGE_TAG:-$(date +%Y%m%d%H%M%S)}"
IMAGE="${IMAGE:-dev.local/${SERVICE_NAME}:${IMAGE_TAG}}"

if ! command -v minikube >/dev/null 2>&1; then
  echo "[deploy-app-dashboard] minikube is required"
  exit 1
fi
if ! command -v kubectl >/dev/null 2>&1; then
  echo "[deploy-app-dashboard] kubectl is required"
  exit 1
fi

if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  echo "[deploy-app-dashboard] Creating namespace ${NAMESPACE}"
  kubectl create namespace "${NAMESPACE}" >/dev/null
fi

echo "[deploy-app-dashboard] Building image ${IMAGE}"
minikube image build -p "${MINIKUBE_PROFILE}" -t "${IMAGE}" "src/app-dashboard"

CURRENT_SKIP="$(kubectl get configmap config-deployment -n knative-serving -o jsonpath='{.data.registriesSkippingTagResolving}' 2>/dev/null || true)"
if [[ "${CURRENT_SKIP}" == *"dev.local"* ]]; then
  echo "[deploy-app-dashboard] Knative skip-tag config already includes dev.local"
else
  NEW_SKIP="${CURRENT_SKIP}"
  if [[ -n "${NEW_SKIP}" ]]; then
    NEW_SKIP="${NEW_SKIP},dev.local"
  else
    NEW_SKIP="dev.local"
  fi
  kubectl patch configmap/config-deployment \
    --namespace knative-serving \
    --type merge \
    --patch "{\"data\":{\"registriesSkippingTagResolving\":\"${NEW_SKIP}\"}}"
fi

cat <<MANIFEST | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-dashboard
  namespace: ${NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: app-dashboard-knative-reader
rules:
  - apiGroups: ["serving.knative.dev"]
    resources: ["services"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: app-dashboard-knative-reader
subjects:
  - kind: ServiceAccount
    name: app-dashboard
    namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: app-dashboard-knative-reader
---
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ${SERVICE_NAME}
  namespace: ${NAMESPACE}
spec:
  template:
    spec:
      serviceAccountName: app-dashboard
      containers:
        - image: ${IMAGE}
          imagePullPolicy: IfNotPresent
MANIFEST

echo "[deploy-app-dashboard] Waiting for ${SERVICE_NAME} readiness"
kubectl wait ksvc/"${SERVICE_NAME}" -n "${NAMESPACE}" --for=condition=Ready --timeout=300s

kubectl get ksvc "${SERVICE_NAME}" -n "${NAMESPACE}"
echo "[deploy-app-dashboard] URL: http://${SERVICE_NAME}.${NAMESPACE}.localhost:8081"
