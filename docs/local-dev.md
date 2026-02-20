# Local Development (Minikube MVP)

## Purpose
This guide defines the local baseline for running the Knative app platform MVP.

## Prerequisites
- `kubectl`
- `minikube`
- `docker` (or compatible container runtime)
- `func` CLI for source-to-image deployment path
- `go` (for the upload API prototype)
- Internet access to pull Knative release manifests and container images

## Repository Layout
- `docs/`: architecture and workflow docs.
- `manifests/`: Kubernetes and Knative YAML manifests.
- `scripts/`: local setup and verification scripts.
- `src/`: platform services (upload/build/deploy API).
- `tests/`: local test scripts and integration checks.

## Setup Commands
Run from repository root.

### 1) Start Minikube
```bash
./scripts/setup-minikube.sh
```
Expected output includes:
- `[setup-minikube] Starting Minikube profile 'knative-dev'`
- `Done! kubectl is now configured to use "knative-dev" cluster`
- `[setup-minikube] Enabling ingress addon`
- `[setup-minikube] Done`

### 2) Install Knative Serving + Kourier
```bash
./scripts/install-knative-serving.sh
```
Expected output includes:
- `[install-knative] Installing Knative Serving CRDs ...`
- `deployment.apps/controller condition met`
- `deployment.apps/webhook condition met`
- `deployment.apps/3scale-kourier-gateway condition met`
- `[install-knative] Done`

### 3) Verify by deploying sample service
```bash
./scripts/verify-knative.sh
```
Expected output includes:
- `[verify-knative] Applying sample service: manifests/samples/hello-knative-service.yaml`
- `service.serving.knative.dev/hello-knative created` (or `configured`)
- `condition met`
- `hello-knative   ...   True`
- `[verify-knative] Done`

### 4) Build and deploy from source with `func`
```bash
kubectl apply -f manifests/build/runtime-config-example.yaml
APP_DIR=src/functions/hello-func ./scripts/func-build-deploy.sh
```
Expected output includes:
- `[func-build-deploy] Building source into image`
- `[func-build-deploy] Deploying to Knative`
- `NAME         URL   LATESTCREATED   LATESTREADY   READY`
- `[func-build-deploy] Done`

### 5) Run upload API prototype
```bash
cd src/upload-api
MOCK_DEPLOY=true go run .
```
Expected output includes:
- `upload-api listening on :8080`

In another terminal:
```bash
./tests/test-upload-workflow.sh
```
Expected output includes:
- `[test-upload-workflow] Uploading bundle`
- `status=READY` (mock mode)

## Manual Validation Commands
```bash
kubectl get pods -n knative-serving
kubectl get pods -n kourier-system
kubectl get ksvc -A
kubectl get revision -A
```

Healthy state expectation:
- Knative Serving and Kourier pods are `Running`/`Completed`.
- `hello-knative` service shows `READY=True`.
- At least one revision exists for `hello-knative`.

### 6) Upload sample frontend/backend webapp
Start API first (example in mock mode):
```bash
cd src/upload-api
MOCK_DEPLOY=true go run .
```

From repo root, upload sample app:
```bash
./scripts/upload-sample-webapp.sh
```

Expected output includes:
- `[upload-sample-webapp] Deployment id: dep-...`
- `[upload-sample-webapp] status=BUILD_IN_PROGRESS`
- `[upload-sample-webapp] status=READY` (or `FAILED`)

### 7) Expose Knative services on localhost
Set Knative domain to `.localhost` and forward Kourier to a local port:
```bash
./scripts/expose-knative-localhost.sh
```

In another terminal, test a service:
```bash
./scripts/curl-knative-localhost.sh
```

Default URL pattern:
- `http://<service>.<namespace>.localhost:8081`

### 8) Real upload-to-deploy demo
```bash
task flow:demo:real
```

Then confirm real service exists:
```bash
kubectl get ksvc sample-webapp -n default
curl http://sample-webapp.default.localhost:8081
```
