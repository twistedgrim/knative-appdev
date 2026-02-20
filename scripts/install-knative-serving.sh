#!/usr/bin/env bash
set -euo pipefail

KNATIVE_VERSION="${KNATIVE_VERSION:-knative-v1.14.0}"
NET_KOURIER_VERSION="${NET_KOURIER_VERSION:-knative-v1.14.0}"

SERVING_CRDS_URL="https://github.com/knative/serving/releases/download/${KNATIVE_VERSION}/serving-crds.yaml"
SERVING_CORE_URL="https://github.com/knative/serving/releases/download/${KNATIVE_VERSION}/serving-core.yaml"
KOURIER_URL="https://github.com/knative/net-kourier/releases/download/${NET_KOURIER_VERSION}/kourier.yaml"

echo "[install-knative] Installing Knative Serving CRDs from ${SERVING_CRDS_URL}"
kubectl apply -f "${SERVING_CRDS_URL}"

echo "[install-knative] Installing Knative Serving core from ${SERVING_CORE_URL}"
kubectl apply -f "${SERVING_CORE_URL}"

echo "[install-knative] Installing Kourier from ${KOURIER_URL}"
kubectl apply -f "${KOURIER_URL}"

echo "[install-knative] Configuring Kourier as ingress class"
kubectl patch configmap/config-network \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"ingress-class":"kourier.ingress.networking.knative.dev"}}'

echo "[install-knative] Waiting for Serving and Kourier rollouts"
kubectl rollout status deployment/activator -n knative-serving --timeout=180s
kubectl rollout status deployment/autoscaler -n knative-serving --timeout=180s
kubectl rollout status deployment/controller -n knative-serving --timeout=180s
kubectl rollout status deployment/webhook -n knative-serving --timeout=180s
kubectl rollout status deployment/net-kourier-controller -n knative-serving --timeout=180s
kubectl rollout status deployment/3scale-kourier-gateway -n kourier-system --timeout=180s

echo "[install-knative] Done"
