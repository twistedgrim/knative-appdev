# Knative Application Developer Platform

A Knative-based Application Developer Platform prototype that provides a developer workflow:
`upload code -> build image -> deploy service`.

## Goals
- Deliver a local Minikube MVP first.
- Provide repeatable setup scripts and manifests for Knative Serving.
- Implement source-to-image and upload-driven deployment flow incrementally.
- Keep docs aligned with implementation checkpoints.

## Project Structure
- `docs/` - architecture, local development, and deployment workflow docs.
- `manifests/` - Kubernetes/Knative manifests.
- `scripts/` - setup and verification scripts.
- `src/` - platform service code.
- `tests/` - local test helpers and integration checks.

## Quickstart
```bash
./scripts/setup-minikube.sh
./scripts/install-knative-serving.sh
./scripts/verify-knative.sh
APP_DIR=samples/webapp SERVICE_NAME=sample-webapp ./scripts/build-deploy-local.sh

cd src/upload-api
MOCK_DEPLOY=true go run .
```

In another terminal:
```bash
./tests/test-upload-workflow.sh
```

For expected output details and troubleshooting, see `docs/local-dev.md`.

## Roadmap
See `PLAN.md` for the current demo roadmap and next implementation steps.

## Validation
```bash
./tests/validate-local.sh
```


## Sample Upload Demo
```bash
./scripts/upload-sample-webapp.sh
```

Sample app source lives in `samples/webapp`.

## Localhost Access (Knative)
```bash
./scripts/expose-knative.sh --mode port8081 --start
# new terminal:
./scripts/curl-knative-localhost.sh
```

## Task Runner
Use `go-task` shortcuts:
```bash
task cluster:up
task knative:install
task verify
```

Expose Knative on localhost (keep this running):
```bash
task expose:localhost
```

In a second terminal:
```bash
task curl:localhost
```

Background localhost exposure:
```bash
task expose:localhost:bg
task curl:localhost
task expose:localhost:stop
```

## One-Command Demo Flow
Run full local demo orchestration:
```bash
task flow:demo
```

This will:
- expose Knative service routing on localhost:8081
- start upload API in mock mode on localhost:8080
- upload `samples/webapp` bundle and poll deployment status

Stop background demo services:
```bash
task flow:demo:stop
```

## Demo Complete
Primary end-to-end demo entry point:
```bash
task flow:demo:real
```

This runs a real upload -> build -> deploy workflow and creates/updates:
- `sample-webapp` Knative Service in `demo-apps` namespace

Verify:
```bash
kubectl get ksvc sample-webapp -n demo-apps
```

Open in browser (with localhost exposure running):
- `http://sample-webapp.demo-apps.localhost:8081`

Real build/deploy demo (creates an actual Knative service for uploaded sample app):
```bash
task flow:demo:real
kubectl get ksvc sample-webapp -n demo-apps
```

Uploaded app URL after localhost exposure:
- `http://sample-webapp.demo-apps.localhost:8081`

## Demo Prep (One Command)
Prepare the full local demo stack in one command:
```bash
task demo:prep
```

This ensures:
- Minikube profile `knative-dev` is running.
- Knative control plane is installed/ready (installs if missing).
- Sample Knative verification service is healthy (with retry handling during startup races).
- `task flow:demo:real`
- `task demo:dashboard`

## Second Sample App
Go sample app location:
- `samples/go-webapp`

Upload and deploy:
```bash
SAMPLE_DIR=samples/go-webapp SERVICE_NAME=go-webapp ./scripts/upload-sample-webapp.sh
```

Or with task:
```bash
task demo:upload:go
```

Verify:
```bash
kubectl get ksvc go-webapp -n demo-apps
```

URL:
- `http://go-webapp.demo-apps.localhost:8081`

## App Dashboard (Knative)
Deploy a simple web page that lists Knative apps running in the cluster:

```bash
task demo:dashboard
```

Open:
- `http://app-dashboard.platform-system.localhost:8081`

## Cleanup Demo Apps
Remove all demo services while keeping platform services (dashboard/upload tooling) untouched:

```bash
task demo:clean
```

## Clean URLs On Port 80
To remove `:8081` from demo URLs, run Knative exposure through `minikube tunnel`:

```bash
task expose:localhost:80:bg
```

Then open URLs without a port:
- `http://sample-webapp.demo-apps.localhost`
- `http://go-webapp.demo-apps.localhost`
- `http://app-dashboard.platform-system.localhost`

Recommended mode:
- `task expose:localhost:80:bg` for day-to-day local use
- `task expose:localhost:80` if you want to watch tunnel logs interactively

Stop tunnel:
```bash
task expose:localhost:80:stop
```

## Auto Localhost Exposure
Try clean URLs on port 80 first (asks for sudo), then fall back to `:8081` automatically if not ready in time:

```bash
task expose:localhost:auto
```

Stop:
```bash
task expose:localhost:auto:stop
```

Background port-80 tunnel:
```bash
task expose:localhost:80:bg
```
