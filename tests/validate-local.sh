#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "[validate] shell script syntax"
bash -n \
  scripts/setup-minikube.sh \
  scripts/install-knative-serving.sh \
  scripts/verify-knative.sh \
  scripts/func-build-deploy.sh \
  scripts/build-deploy-local.sh \
  scripts/expose-knative-localhost.sh \
  scripts/expose-knative-localhost-bg.sh \
  scripts/expose-knative-localhost-stop.sh \
  scripts/upload-sample-webapp.sh \
  scripts/demo-flow.sh \
  scripts/demo-flow-real.sh \
  scripts/demo-flow-stop.sh \
  tests/test-upload-workflow.sh

echo "[validate] manifest dry-run"
kubectl apply --dry-run=client -f manifests/samples/hello-knative-service.yaml >/dev/null
kubectl apply --dry-run=client -f manifests/build/runtime-config-example.yaml >/dev/null
kubectl apply --dry-run=client -f manifests/build/registry-auth-secret.example.yaml >/dev/null

echo "[validate] go checks"
if command -v go >/dev/null 2>&1; then
  (cd src/upload-api && go test ./...)
else
  echo "[validate] WARNING: go is not installed; skipping go test"
fi

echo "[validate] complete"
