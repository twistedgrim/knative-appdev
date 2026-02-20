#!/usr/bin/env bash
set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-knative-dev}"
K8S_VERSION="${K8S_VERSION:-stable}"
CPUS="${MINIKUBE_CPUS:-4}"
MEMORY="${MINIKUBE_MEMORY:-8192}"
DISK_SIZE="${MINIKUBE_DISK_SIZE:-30g}"
DRIVER="${MINIKUBE_DRIVER:-docker}"

echo "[setup-minikube] Starting Minikube profile '${PROFILE}'"
minikube start \
  --profile "${PROFILE}" \
  --kubernetes-version "${K8S_VERSION}" \
  --cpus "${CPUS}" \
  --memory "${MEMORY}" \
  --disk-size "${DISK_SIZE}" \
  --driver "${DRIVER}"

echo "[setup-minikube] Enabling ingress addon"
minikube addons enable ingress --profile "${PROFILE}"

echo "[setup-minikube] Cluster info"
kubectl cluster-info

echo "[setup-minikube] Done"
