# Local Development (Minikube MVP)

## Purpose
This guide defines the local baseline for running the Knative app platform MVP.

## Prerequisites
- `kubectl`
- `minikube`
- `docker` (or compatible container runtime)
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

### 0) One-command demo prep (recommended)
```bash
task demo:prep
```
Expected output includes:
- `[demo:prep] Minikube profile knative-dev already running` (or `task cluster:up` when absent)
- `[demo:prep] Existing Knative detected; waiting for control-plane readiness` (or install path)
- `[demo:prep] Running verify (attempt .../5)`
- `[demo-flow] Demo is running`

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

### 4) Build and deploy from source (local image path)
```bash
APP_DIR=samples/webapp SERVICE_NAME=sample-webapp ./scripts/build-deploy-local.sh
```
Expected output includes:
- `[build-deploy-local] Building image in minikube`
- `[build-deploy-local] Deploying Knative service sample-webapp`
- `NAME         URL   LATESTCREATED   LATESTREADY   READY`
- `[build-deploy-local] Done`

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
./scripts/expose-knative.sh --mode port8081 --start
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
kubectl get ksvc sample-webapp -n demo-apps
curl http://sample-webapp.demo-apps.localhost:8081
```

### 9) Deploy the Go sample app
```bash
task demo:upload:go
kubectl get ksvc go-webapp -n demo-apps
```

Open:
- `http://go-webapp.demo-apps.localhost:8081`

### 10) Deploy application dashboard
```bash
task demo:dashboard
kubectl get ksvc app-dashboard -n platform-system
```

Open:
- `http://app-dashboard.platform-system.localhost:8081`

### 11) Cleanup only demo applications
```bash
task demo:clean
kubectl get ksvc -n demo-apps
```

This removes demo workloads from `demo-apps` while keeping platform workloads in `platform-system`.

### 12) Expose clean localhost URLs on port 80
```bash
task expose:localhost:80:bg
```

This uses `minikube tunnel` and will prompt for sudo on macOS to bind ports `80/443`.

Example URLs (no port suffix):
- `http://sample-webapp.demo-apps.localhost`
- `http://go-webapp.demo-apps.localhost`
- `http://app-dashboard.platform-system.localhost`

Stop:
```bash
task expose:localhost:80:stop
```

Foreground mode (optional, with live tunnel logs):
```bash
task expose:localhost:80
```

### 13) Auto exposure (port 80 with fallback)
```bash
task expose:localhost:auto
```

Behavior:
- First attempts privileged port-80 exposure via `minikube tunnel`.
- If not ready within timeout, falls back to localhost `:8081` exposure.

Stop:
```bash
task expose:localhost:auto:stop
```

Background mode:
```bash
task expose:localhost:80:bg
```
